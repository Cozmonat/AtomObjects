// Copyright (c) 2023 Natan Zalkin — MIT License

import AppKit
import SwiftUI
import Testing

@testable import AtomObjects

private struct IOCounterKey: AtomObjectKey {
    static var defaultValue: Int = 0
}

extension AtomObjects {
    fileprivate var ioCounter: GenericAtom<Int> {
        get { self[IOCounterKey.self] }
        set { self[IOCounterKey.self] = newValue }
    }
}

private enum IOActionError: Error {
    case boom
}

/// Existing Void/Void shape: implements only `perform(with:)`.
/// Stored-property-free, so its implicit `init()` witnesses `DefaultInitializableAction`.
private struct VoidBumpAction: AtomObjectsAction, DefaultInitializableAction {
    func perform(with root: AtomObjects) async throws {
        @AtomValue(\.ioCounter, in: root) var counter
        counter += 1
        VoidBumpAction.lastRoute = "void"
    }

    static var lastRoute = ""
}

/// Parameterized shape: implements only `perform(with:input:)`.
/// Stored-property-free, so its implicit `init()` witnesses `DefaultInitializableAction`.
private struct EchoAction: ParameterizedAtomObjectsAction, DefaultInitializableAction {
    typealias Input = String
    typealias Output = String

    func perform(with root: AtomObjects, input: String) async throws -> String {
        EchoAction.lastRoute = "input"
        @AtomValue(\.ioCounter, in: root) var counter
        counter += input.count
        return "echo:\(input)"
    }

    static var lastRoute = ""
}

private struct ThrowOnInputAction: ParameterizedAtomObjectsAction {
    typealias Input = Int
    typealias Output = Int

    func perform(with root: AtomObjects, input: Int) async throws -> Int {
        throw IOActionError.boom
    }
}

private struct CancelOnInputAction: ParameterizedAtomObjectsAction {
    typealias Input = Bool
    typealias Output = Void

    func perform(with root: AtomObjects, input: Bool) async throws {
        throw CancellationError()
    }
}

@MainActor
private final class IOPerformFlag {
    var performed = false
}

private struct FlagOnInputAction: ParameterizedAtomObjectsAction {
    typealias Input = String
    typealias Output = Void

    let flag: IOPerformFlag

    func perform(with root: AtomObjects, input: String) async throws {
        flag.performed = true
    }
}

private struct EchoFlagAction: ParameterizedAtomObjectsAction {
    typealias Input = String
    typealias Output = String

    let flag: IOPerformFlag

    func perform(with root: AtomObjects, input: String) async throws -> String {
        flag.performed = true
        return "echo:\(input)"
    }
}

@MainActor
private final class ParameterizedClosureBox {
    var fire: ((String) -> Void)?
    var fireAsync: ((String) async throws -> String)?
}

private struct ParameterizedProbeView: View {
    @AtomInputAction(EchoAction())
    var echo

    let box: ParameterizedClosureBox

    var body: some View {
        box.fire = echo
        box.fireAsync = $echo
        return Color.clear
    }
}

private struct MetatypeInputProbeView: View {
    @AtomInputAction(EchoAction.self)
    var echo

    let box: ParameterizedClosureBox

    var body: some View {
        box.fire = echo
        box.fireAsync = $echo
        return Color.clear
    }
}

@MainActor
private final class VoidClosureBox {
    var fire: (() -> Void)?
    var fireAsync: (() async throws -> Void)?
}

private struct MetatypeVoidProbeView: View {
    @AtomAction(VoidBumpAction.self)
    var bump

    let box: VoidClosureBox

    var body: some View {
        box.fire = bump
        box.fireAsync = $bump
        return Color.clear
    }
}

private struct ThrowProbeView: View {
    @AtomInputAction(ThrowOnInputAction())
    var boom

    let onReady: (@escaping (Int) async throws -> Int) -> Void

    var body: some View {
        onReady($boom)
        return Color.clear
    }
}

@MainActor
private func renderIOWindow<Content: View>(_ view: Content) -> NSWindow {
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
        styleMask: [.titled],
        backing: .buffered,
        defer: false)
    window.contentView = NSHostingView(rootView: view)
    window.makeKeyAndOrderFront(nil)
    window.layoutIfNeeded()
    return window
}

private func waitUntilIO(
    timeout: Duration = .seconds(2),
    _ condition: () -> Bool
) async throws {
    let start = ContinuousClock.now
    while !condition() {
        if ContinuousClock.now - start > timeout {
            Issue.record("timed out waiting for condition")
            return
        }
        await Task.yield()
        try await Task.sleep(for: .milliseconds(10))
    }
}

@MainActor
@Suite("AtomObjectsAction input/output")
struct AtomObjectsActionIOTests {

    @Test("existing Void conformance still compiles and routes through perform(with:)")
    func voidConformanceRoutesThroughPerformWith() async throws {
        VoidBumpAction.lastRoute = ""
        let root = AtomObjects()
        let action = VoidBumpAction()
        try await action.perform(with: root)
        #expect(root.ioCounter.value == 1)
        #expect(VoidBumpAction.lastRoute == "void")
    }

    @Test("parameterized conformance routes through perform(with:input:)")
    func parameterizedRoutesThroughPerformWithInput() async throws {
        EchoAction.lastRoute = ""
        let root = AtomObjects()
        let output = try await EchoAction().perform(with: root, input: "hi")
        #expect(output == "echo:hi")
        #expect(root.ioCounter.value == 2)
        #expect(EchoAction.lastRoute == "input")
    }

    @Test("errors propagate through perform(with:input:)")
    func errorPropagation() async throws {
        let root = AtomObjects()
        await #expect(throws: IOActionError.self) {
            try await ThrowOnInputAction().perform(with: root, input: 1)
        }
    }

    @Test("cancellation errors propagate through perform(with:input:)")
    func cancellationPropagation() async throws {
        let root = AtomObjects()
        do {
            try await CancelOnInputAction().perform(with: root, input: true)
            Issue.record("expected CancellationError")
        } catch is CancellationError {
            // expected
        }
    }
}

@MainActor
@Suite("AtomInputAction parameterized wrapper")
struct AtomInputActionWrapperTests {

    @Test("$action carries input and returns output")
    func projectedValueInputOutput() async throws {
        EchoAction.lastRoute = ""
        let root = AtomObjects()
        let box = ParameterizedClosureBox()
        let window = renderIOWindow(
            AtomScope(root: root) {
                ParameterizedProbeView(box: box)
            })
        defer { window.close() }

        let fireAsync = try #require(box.fireAsync)
        let output = try await fireAsync("ab")
        #expect(output == "echo:ab")
        #expect(root.ioCounter.value == 2)
        #expect(EchoAction.lastRoute == "input")
    }

    @Test("wrappedValue fire-and-forget accepts input")
    func wrappedValueAcceptsInput() async throws {
        let root = AtomObjects()
        let box = ParameterizedClosureBox()
        let window = renderIOWindow(
            AtomScope(root: root) {
                ParameterizedProbeView(box: box)
            })
        defer { window.close() }

        let fire = try #require(box.fire)
        fire("xyz")
        try await waitUntilIO { root.ioCounter.value == 3 }
        #expect(root.ioCounter.value == 3)
    }

    @Test("projectedValue without root is a no-op for Void output")
    func missingRootProjectedVoidNoOp() async throws {
        let flag = IOPerformFlag()
        let wrapper = AtomInputAction(FlagOnInputAction(flag: flag))
        try await wrapper.projectedValue("x")
        #expect(!flag.performed)
    }

    @Test("projectedValue without root throws missingRoot for non-Void output")
    func missingRootProjectedNonVoidThrows() async throws {
        let flag = IOPerformFlag()
        let wrapper = AtomInputAction(EchoFlagAction(flag: flag))
        await #expect(throws: AtomObjectsActionError.missingRoot) {
            try await wrapper.projectedValue("x")
        }
        #expect(!flag.performed)
    }

    @Test("wrappedValue without root does not run the action")
    func missingRootWrappedNoOp() async throws {
        let flag = IOPerformFlag()
        let wrapper = AtomInputAction(FlagOnInputAction(flag: flag))
        wrapper.wrappedValue("x")
        try await Task.sleep(for: .milliseconds(50))
        #expect(!flag.performed)
    }

    @Test("$action propagates errors for parameterized actions")
    func projectedParameterizedError() async throws {
        let root = AtomObjects()
        nonisolated(unsafe) var captured: ((Int) async throws -> Int)?
        let window = renderIOWindow(
            AtomScope(root: root) {
                ThrowProbeView { captured = $0 }
            })
        defer { window.close() }
        let fire = try #require(captured)
        await #expect(throws: IOActionError.self) {
            try await fire(0)
        }
    }
}

@MainActor
@Suite("metatype shorthand for parameterless actions")
struct MetatypeShorthandTests {

    @Test("@AtomInputAction(EchoAction.self) routes input and output through perform")
    func metatypeInputRoutesThroughPerform() async throws {
        EchoAction.lastRoute = ""
        let root = AtomObjects()
        let box = ParameterizedClosureBox()
        let window = renderIOWindow(
            AtomScope(root: root) {
                MetatypeInputProbeView(box: box)
            })
        defer { window.close() }

        let fireAsync = try #require(box.fireAsync)
        let output = try await fireAsync("ab")
        #expect(output == "echo:ab")
        #expect(root.ioCounter.value == 2)
        #expect(EchoAction.lastRoute == "input")
    }

    @Test("@AtomAction(VoidBumpAction.self) performs against the root")
    func metatypeVoidPerformsAgainstRoot() async throws {
        VoidBumpAction.lastRoute = ""
        let root = AtomObjects()
        let box = VoidClosureBox()
        let window = renderIOWindow(
            AtomScope(root: root) {
                MetatypeVoidProbeView(box: box)
            })
        defer { window.close() }

        let fire = try #require(box.fire)
        fire()
        try await waitUntilIO { root.ioCounter.value == 1 }
        #expect(root.ioCounter.value == 1)
        #expect(VoidBumpAction.lastRoute == "void")
    }

    @Test("metatype-constructed input action without root throws for non-Void output")
    func metatypeMissingRootNonVoidThrows() async throws {
        let wrapper = AtomInputAction(EchoAction.self)
        await #expect(throws: AtomObjectsActionError.missingRoot) {
            try await wrapper.projectedValue("x")
        }
    }
}
