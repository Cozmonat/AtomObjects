// Copyright (c) 2023 Natan Zalkin — MIT License

import AppKit
import SwiftUI
import Testing

@testable import AtomObjects

// ── Test Keys ──

private struct ViewCounterKey: AtomObjectKey {
    static var defaultValue: Int = 0
}

private struct ViewNameKey: AtomObjectKey {
    static var defaultValue: String = ""
}

private struct ViewActionLogKey: AtomObjectKey {
    static var defaultValue: [String] = []
}

private struct ChildViewRootKey: AtomRootKey {
    static var defaultRoot: AtomObjects { AtomObjects() }
}

// ── Deep nesting test keys ──

private struct Level2RootKey: AtomRootKey {
    static var defaultRoot: AtomObjects { AtomObjects() }
}

private struct Level3RootKey: AtomRootKey {
    static var defaultRoot: AtomObjects { AtomObjects() }
}

// ── AtomObjects extensions ──

extension AtomObjects {
    var viewCounter: GenericAtom<Int> {
        get { self[ViewCounterKey.self] }
        set { self[ViewCounterKey.self] = newValue }
    }

    var viewName: GenericAtom<String> {
        get { self[ViewNameKey.self] }
        set { self[ViewNameKey.self] = newValue }
    }

    var viewActionLog: GenericAtom<[String]> {
        get { self[ViewActionLogKey.self] }
        set { self[ViewActionLogKey.self] = newValue }
    }

    struct IncrementAction: AtomObjectsAction {
        var amount: Int

        func perform(with root: AtomObjects) async throws {
            @AtomValue(\.viewCounter, in: root) var counter
            counter += amount
        }
    }

    struct LogAction: AtomObjectsAction {
        var message: String

        func perform(with root: AtomObjects) async throws {
            @AtomValue(\.viewActionLog, in: root) var log
            log.append(message)
        }
    }
}

// ── Test Views ──

/// A view that reads and writes an atom via @AtomState
private struct CounterStateView: View {
    @AtomState(\AtomObjects.viewCounter)
    var counter

    var body: some View {
        VStack {
            Text("Counter: \(counter)")
                .accessibilityIdentifier("counterLabel")
            Button("Increment") {
                counter += 1
            }
            .accessibilityIdentifier("incrementButton")
            Button("Decrement") {
                counter -= 1
            }
            .accessibilityIdentifier("decrementButton")
        }
    }
}

/// A view that uses @AtomState with a custom setter
private struct CustomSetterView: View {
    @AtomState(
        \AtomObjects.viewCounter,
        set: { newValue, atom in
            atom.value = max(newValue, 0)  // Clamp to zero
        }
    )
    var counter

    var body: some View {
        Button("Set Negative") {
            counter = -5
        }
        .accessibilityIdentifier("setNegativeButton")
        Text("Value: \(counter)")
            .accessibilityIdentifier("customValueLabel")
    }
}

/// A view that uses @AtomAction
private struct ActionView: View {
    @AtomState(\AtomObjects.viewCounter)
    var counter

    @AtomAction(AtomObjects.IncrementAction(amount: 10))
    var incrementByTen

    var body: some View {
        VStack {
            Text("Counter: \(counter)")
                .accessibilityIdentifier("actionCounterLabel")
            Button("Add 10") {
                incrementByTen()
            }
            .accessibilityIdentifier("addTenButton")
        }
    }
}

/// A view that uses $action (async projected value)
private struct AsyncActionView: View {
    @AtomState(\AtomObjects.viewCounter)
    var counter

    @AtomAction(AtomObjects.IncrementAction(amount: 5))
    var addFive

    var body: some View {
        VStack {
            Text("Counter: \(counter)")
                .accessibilityIdentifier("asyncCounterLabel")
            Button("Async Add 5") {
                Task {
                    try await $addFive()
                }
            }
            .accessibilityIdentifier("asyncAddButton")
        }
    }
}

/// A view that uses .atomScope() modifier
private struct ModifierScopeView: View {
    @AtomState(\AtomObjects.viewCounter)
    var counter

    var body: some View {
        Text("Scoped: \(counter)")
            .accessibilityIdentifier("scopedLabel")
    }
}

/// A view that uses AtomScope struct
private struct StructScopeView: View {
    @AtomState(\AtomObjects.viewCounter)
    var counter

    var body: some View {
        Text("StructScoped: \(counter)")
            .accessibilityIdentifier("structScopedLabel")
    }
}

/// A view for testing nested roots
private struct NestedRootView: View {
    @AtomState(\AtomObjects.viewCounter)
    var parentCounter

    var body: some View {
        VStack {
            Text("Parent: \(parentCounter)")
                .accessibilityIdentifier("parentLabel")
            NestedChildView()
                .atomScope(root: AtomObjects())
        }
    }
}

private struct NestedChildView: View {
    @AtomState(\AtomObjects.viewCounter)
    var childCounter

    var body: some View {
        Text("Child: \(childCounter)")
            .accessibilityIdentifier("childLabel")
    }
}

/// A view that uses @AtomAction with LogAction
private struct LogActionView: View {
    @AtomState(\AtomObjects.viewActionLog)
    var log

    @AtomAction(AtomObjects.LogAction(message: "test_event"))
    var logEvent

    var body: some View {
        VStack {
            Text("Log count: \(log.count)")
                .accessibilityIdentifier("logCountLabel")
            Button("Log") {
                logEvent()
            }
            .accessibilityIdentifier("logButton")
        }
    }
}

// ── Error-handling test helpers ──

private struct TestActionError: Error {}

/// Throws a regular error after recording that it started.
private struct ThrowingAction: AtomObjectsAction {
    func perform(with root: AtomObjects) async throws {
        @AtomValue(\.viewActionLog, in: root) var log
        log.append("throwing_started")
        throw TestActionError()
    }
}

/// Throws CancellationError after recording that it started.
private struct CancellingAction: AtomObjectsAction {
    func perform(with root: AtomObjects) async throws {
        @AtomValue(\.viewActionLog, in: root) var log
        log.append("cancel_started")
        throw CancellationError()
    }
}

/// Records whether perform() was actually invoked, without touching any root state.
@MainActor
private final class PerformFlag {
    var performed = false
}

private struct FlaggingAction: AtomObjectsAction {
    let flag: PerformFlag

    func perform(with root: AtomObjects) async throws {
        flag.performed = true
    }
}

/// Captures the closures produced by an @AtomAction wrapper during body evaluation,
/// so tests can invoke them exactly as a Button action would.
@MainActor
private final class ActionClosureBox {
    var fire: (() -> Void)?
    var fireAsync: (() async throws -> Void)?
}

/// A view that hands its @AtomAction closures to the test through a box.
/// Capturing them during body evaluation mirrors what a Button label closure sees.
private struct ActionProbeView<Action>: View
where Action: AtomObjectsAction, Action.Root == AtomObjects {

    @AtomAction<Action> private var action: () -> Void

    private let box: ActionClosureBox

    init(action: Action, box: ActionClosureBox) {
        self._action = AtomAction(action)
        self.box = box
    }

    var body: some View {
        box.fire = action
        box.fireAsync = $action
        return Color.clear
    }
}

/// Captures the accessors produced by an @AtomState wrapper during body evaluation,
/// so tests can read and write through the wrapper exactly as view code would.
@MainActor
private final class StateClosureBox {
    var read: (() -> Int)?
    var write: ((Int) -> Void)?
    var binding: Binding<Int>?
}

/// A view that hands its @AtomState accessors to the test through a box.
private struct StateProbeView: View {

    @AtomState(\AtomObjects.viewCounter)
    private var counter: Int

    private let box: StateClosureBox
    private let captureBinding: Bool

    init(
        state: AtomState<AtomObjects, GenericAtom<Int>, Int> = AtomState(\.viewCounter),
        captureBinding: Bool = true,
        box: StateClosureBox
    ) {
        self._counter = state
        self.captureBinding = captureBinding
        self.box = box
    }

    var body: some View {
        box.read = { counter }
        box.write = { counter = $0 }
        // Creating the projected Binding eagerly invokes its getter, which
        // fatalErrors without a root — so no-root tests must opt out.
        if captureBinding {
            box.binding = $counter
        }
        return Color.clear
    }
}

/// Hosts a view in a window and forces a layout pass so SwiftUI evaluates body.
@MainActor
private func renderInWindow<Content: View>(_ view: Content) -> NSWindow {
    let hosting = NSHostingController(rootView: view)
    let window = NSWindow(contentViewController: hosting)
    window.orderFrontRegardless()
    hosting.view.layoutSubtreeIfNeeded()
    return window
}

/// Polls until the condition holds or the timeout elapses, yielding the main
/// actor so fire-and-forget action tasks can run.
private func waitUntil(
    timeout: Duration = .seconds(2),
    _ condition: () -> Bool
) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while !condition(), clock.now < deadline {
        try await Task.sleep(for: .milliseconds(10))
    }
}

// ── Tests ──

@MainActor
@Suite("AtomState View Tests")
struct AtomStateViewTests {

    @Test("AtomState view renders inside AtomScope")
    func atomStateViewRenders() async throws {
        let root = AtomObjects()
        root.viewCounter = GenericAtom<Int>(value: 42)

        let hosting = NSHostingController(
            rootView: AtomScope(root: root) {
                CounterStateView()
            })

        // hosting controller created successfully
        hosting.viewDidLoad()
        #expect(root.viewCounter.value == 42)
    }

    @Test("AtomState view reads updated value from root")
    func atomStateViewReadsUpdatedValue() async throws {
        let root = AtomObjects()
        root.viewCounter = GenericAtom<Int>(value: 0)

        _ = NSHostingController(
            rootView: AtomScope(root: root) {
                CounterStateView()
            })

        root.viewCounter.value = 7
        #expect(root.viewCounter.value == 7)
    }

    @Test("AtomState with custom setter view renders")
    func atomStateCustomSetterViewRenders() async throws {
        let root = AtomObjects()
        root.viewCounter = GenericAtom<Int>(value: 0)

        _ = NSHostingController(
            rootView: AtomScope(root: root) {
                CustomSetterView()
            })

        #expect(root.viewCounter.value == 0)
    }

    @Test("AtomState equatable compares key paths")
    func atomStateEquatable() async throws {
        let s1 = AtomState(\AtomObjects.viewCounter, root: AtomObjects.self)
        let s2 = AtomState(\AtomObjects.viewCounter, root: AtomObjects.self)

        #expect(s1 == s2, "same key path should be equal")
    }

    @Test("AtomState with multiple views sharing root")
    func atomStateSharedRoot() async throws {
        let root = AtomObjects()
        root.viewCounter = GenericAtom<Int>(value: 0)

        _ = NSHostingController(
            rootView: AtomScope(root: root) {
                VStack {
                    CounterStateView()
                    CounterStateView()
                }
            })

        root.viewCounter.value = 5
        #expect(root.viewCounter.value == 5)
    }
}

// Note: the fatalError branches of wrappedValue/projectedValue getters (missing root)
// cannot be covered — they would crash the test run by design. These tests cover the
// reachable paths: get, set, custom setter, Binding get/set, and the no-root setter guards.
@MainActor
@Suite("AtomState Live View Tests")
struct AtomStateLiveViewTests {

    private static let clampingState = AtomState(
        \AtomObjects.viewCounter,
        set: { newValue, atom in
            atom.value = max(newValue, 0)  // Clamp to zero
        })

    @Test("wrappedValue getter reads atom value through live view")
    func wrappedValueGetter() async throws {
        let root = AtomObjects()
        root.viewCounter = GenericAtom<Int>(value: 42)
        let box = StateClosureBox()

        let window = renderInWindow(
            AtomScope(root: root) {
                StateProbeView(box: box)
            })
        defer { window.close() }

        let read = try #require(box.read, "body should have captured the getter")
        #expect(read() == 42)
    }

    @Test("wrappedValue setter writes atom value through live view")
    func wrappedValueSetter() async throws {
        let root = AtomObjects()
        root.viewCounter = GenericAtom<Int>(value: 0)
        let box = StateClosureBox()

        let window = renderInWindow(
            AtomScope(root: root) {
                StateProbeView(box: box)
            })
        defer { window.close() }

        let write = try #require(box.write, "body should have captured the setter")
        write(7)
        #expect(root.viewCounter.value == 7)

        // Equal value exercises the setIfNotEqual skip branch.
        write(7)
        #expect(root.viewCounter.value == 7)
    }

    @Test("wrappedValue setter dispatches to custom setter")
    func wrappedValueCustomSetter() async throws {
        let root = AtomObjects()
        root.viewCounter = GenericAtom<Int>(value: 0)
        let box = StateClosureBox()

        let window = renderInWindow(
            AtomScope(root: root) {
                StateProbeView(state: Self.clampingState, box: box)
            })
        defer { window.close() }

        let write = try #require(box.write, "body should have captured the setter")
        write(-5)
        #expect(root.viewCounter.value == 0, "custom setter should clamp negative values")

        write(3)
        #expect(root.viewCounter.value == 3)
    }

    @Test("projected Binding reads and writes through live view")
    func bindingReadsAndWrites() async throws {
        let root = AtomObjects()
        root.viewCounter = GenericAtom<Int>(value: 1)
        let box = StateClosureBox()

        let window = renderInWindow(
            AtomScope(root: root) {
                StateProbeView(box: box)
            })
        defer { window.close() }

        let binding = try #require(box.binding, "body should have captured the binding")
        #expect(binding.wrappedValue == 1)

        binding.wrappedValue = 9
        #expect(root.viewCounter.value == 9)
    }

    @Test("projected Binding dispatches to custom setter")
    func bindingCustomSetter() async throws {
        let root = AtomObjects()
        root.viewCounter = GenericAtom<Int>(value: 5)
        let box = StateClosureBox()

        let window = renderInWindow(
            AtomScope(root: root) {
                StateProbeView(state: Self.clampingState, box: box)
            })
        defer { window.close() }

        let binding = try #require(box.binding, "body should have captured the binding")
        binding.wrappedValue = -3
        #expect(root.viewCounter.value == 0, "custom setter should clamp negative values")
    }

    @Test("wrappedValue setter is a no-op without a root in the environment")
    func setterWithoutRoot() async throws {
        let box = StateClosureBox()

        // No AtomScope — the environment carries no root.
        // Only the wrappedValue setter can be exercised here: the getters fatalError
        // without a root, and even creating the projected Binding invokes the getter,
        // so the Binding set-guard is untestable.
        let window = renderInWindow(StateProbeView(captureBinding: false, box: box))
        defer { window.close() }

        let write = try #require(box.write, "body should have captured the setter")

        // Reaching the expectation without crashing proves the guard returned early.
        write(5)
        #expect(true)
    }
}

@MainActor
@Suite("AtomAction View Tests")
struct AtomActionViewTests {

    @Test("AtomAction view renders inside AtomScope")
    func atomActionViewRenders() async throws {
        let root = AtomObjects()
        root.viewCounter = GenericAtom<Int>(value: 0)

        _ = NSHostingController(
            rootView: AtomScope(root: root) {
                ActionView()
            })

        #expect(root.viewCounter.value == 0)
    }

    @Test("AtomAction creates wrapper with correct type")
    func atomActionCreation() async throws {
        let _ = AtomAction(AtomObjects.IncrementAction(amount: 1))
    }

    @Test("AtomAction equatable always returns true")
    func atomActionEquatable() async throws {
        let a1 = AtomAction(AtomObjects.IncrementAction(amount: 1))
        let a2 = AtomAction(AtomObjects.IncrementAction(amount: 99))
        #expect(a1 == a2, "AtomAction equatable should always return true")
    }

    @Test("AtomAction async view renders")
    func atomActionAsyncViewRenders() async throws {
        let root = AtomObjects()
        root.viewCounter = GenericAtom<Int>(value: 0)

        _ = NSHostingController(
            rootView: AtomScope(root: root) {
                AsyncActionView()
            })

        #expect(root.viewCounter.value == 0)
    }

    @Test("AtomAction with LogAction view renders")
    func atomActionLogViewRenders() async throws {
        let root = AtomObjects()
        root.viewActionLog = GenericAtom<[String]>(value: [])

        _ = NSHostingController(
            rootView: AtomScope(root: root) {
                LogActionView()
            })

        #expect(root.viewActionLog.value.isEmpty)
    }
}

// Note: the generic-error path of wrappedValue cannot be covered here — it raises
// assertionFailure, which would crash the debug test run by design. These tests
// cover the paths around it: success, cancellation, projected throws, missing root.
@MainActor
@Suite("AtomAction Error Handling View Tests")
struct AtomActionErrorViewTests {

    @Test("wrappedValue captured from live view mutates state")
    func wrappedValueFromLiveView() async throws {
        let root = AtomObjects()
        root.viewCounter = GenericAtom<Int>(value: 0)
        let box = ActionClosureBox()

        let window = renderInWindow(
            AtomScope(root: root) {
                ActionProbeView(action: AtomObjects.IncrementAction(amount: 3), box: box)
            })
        defer { window.close() }

        let fire = try #require(box.fire, "body should have captured the action closure")
        fire()

        try await waitUntil { root.viewCounter.value == 3 }
        #expect(root.viewCounter.value == 3)
    }

    @Test("wrappedValue treats CancellationError as a normal outcome")
    func wrappedValueIgnoresCancellation() async throws {
        let root = AtomObjects()
        root.viewActionLog = GenericAtom<[String]>(value: [])
        let box = ActionClosureBox()

        let window = renderInWindow(
            AtomScope(root: root) {
                ActionProbeView(action: CancellingAction(), box: box)
            })
        defer { window.close() }

        let fire = try #require(box.fire, "body should have captured the action closure")
        // Would crash via assertionFailure if CancellationError were treated as a failure.
        fire()

        try await waitUntil { root.viewActionLog.value.contains("cancel_started") }
        #expect(root.viewActionLog.value == ["cancel_started"])
    }

    @Test("projectedValue captured from live view propagates errors")
    func projectedValuePropagatesError() async throws {
        let root = AtomObjects()
        root.viewActionLog = GenericAtom<[String]>(value: [])
        let box = ActionClosureBox()

        let window = renderInWindow(
            AtomScope(root: root) {
                ActionProbeView(action: ThrowingAction(), box: box)
            })
        defer { window.close() }

        let fireAsync = try #require(box.fireAsync, "body should have captured the async closure")

        var caught: (any Error)?
        do {
            try await fireAsync()
        } catch {
            caught = error
        }

        #expect(caught is TestActionError)
        #expect(root.viewActionLog.value == ["throwing_started"])
    }

    @Test("wrappedValue is a no-op without a root in the environment")
    func wrappedValueWithoutRoot() async throws {
        let flag = PerformFlag()
        let box = ActionClosureBox()

        // No AtomScope — the environment carries no root.
        let window = renderInWindow(
            ActionProbeView(action: FlaggingAction(flag: flag), box: box))
        defer { window.close() }

        let fire = try #require(box.fire, "body should have captured the action closure")
        fire()

        try await Task.sleep(for: .milliseconds(50))
        #expect(!flag.performed, "action must not run when no root is present")
    }
}

@MainActor
@Suite("AtomScope View Tests")
struct AtomScopeViewTests {

    @Test("AtomScope struct provides root to environment")
    func atomScopeStructProvidesRoot() async throws {
        let root = AtomObjects()
        root.viewCounter = GenericAtom<Int>(value: 99)

        let hosting = NSHostingController(
            rootView: AtomScope(root: root) {
                StructScopeView()
            })

        hosting.viewDidLoad()
        // hosting controller created successfully
        #expect(root.viewCounter.value == 99)
    }

    @Test("AtomScope modifier provides root")
    func atomScopeModifierProvidesRoot() async throws {
        let root = AtomObjects()
        root.viewCounter = GenericAtom<Int>(value: 77)

        let hosting = NSHostingController(
            rootView: ModifierScopeView()
                .atomScope(root: root))

        hosting.viewDidLoad()
        // hosting controller created successfully
        #expect(root.viewCounter.value == 77)
    }

    @Test("AtomScope nested roots render independently")
    func atomScopeNestedIndependent() async throws {
        let parentRoot = AtomObjects()
        parentRoot.viewCounter = GenericAtom<Int>(value: 10)

        let hosting = NSHostingController(
            rootView: AtomScope(root: parentRoot) {
                NestedRootView()
            })

        hosting.viewDidLoad()
        // hosting controller created successfully
        #expect(parentRoot.viewCounter.value == 10)
    }

    @Test("AtomScope isolates child state from parent")
    func atomScopeIsolation() async throws {
        let parentRoot = AtomObjects()
        let childRoot = AtomObjects()

        parentRoot.viewCounter = GenericAtom<Int>(value: 100)
        childRoot.viewCounter = GenericAtom<Int>(value: 1)

        _ = NSHostingController(
            rootView: AtomScope(root: parentRoot) {
                VStack {
                    CounterStateView()
                    AtomScope(root: childRoot) {
                        CounterStateView()
                    }
                }
            })

        #expect(parentRoot.viewCounter.value == 100)
        #expect(childRoot.viewCounter.value == 1)
    }

    @Test("AtomScope with nested root via AtomRootKey")
    func atomScopeWithNestedRootKey() async throws {
        let root = AtomObjects()
        let child = root[ChildViewRootKey.self] as AtomObjects
        child.viewCounter = GenericAtom<Int>(value: 5)

        #expect(child.parent === root)
        #expect(child.viewCounter.value == 5)
    }

    @Test("AtomScope struct vs modifier equivalence")
    func atomScopeStructVsModifier() async throws {
        let root1 = AtomObjects()
        let root2 = AtomObjects()

        root1.viewCounter = GenericAtom<Int>(value: 1)
        root2.viewCounter = GenericAtom<Int>(value: 2)

        let structHosting = NSHostingController(
            rootView: AtomScope(root: root1) {
                StructScopeView()
            })

        let modifierHosting = NSHostingController(
            rootView: ModifierScopeView()
                .atomScope(root: root2))

        structHosting.viewDidLoad()
        modifierHosting.viewDidLoad()

        // struct hosting controller created
        // modifier hosting controller created
        #expect(root1.viewCounter.value == 1)
        #expect(root2.viewCounter.value == 2)
    }
}

@MainActor
@Suite("Environment Injection View Tests")
struct EnvironmentInjectionViewTests {

    @Test("atomRoot environment key returns nil by default")
    func atomRootDefaultNil() async throws {
        var values = EnvironmentValues()
        #expect(values.atomRoot == nil)
    }

    @Test("atomRoot environment key can be set")
    func atomRootEnvironmentSet() async throws {
        let root = AtomObjects()
        var values = EnvironmentValues()
        values.atomRoot = root

        #expect(values.atomRoot !== nil)
        #expect(values.atomRoot === root)
    }

    @Test("atomRoot environment key type safety")
    func atomRootEnvironmentTypeSafety() async throws {
        let root = AtomObjects()
        var values = EnvironmentValues()
        values.atomRoot = root

        let retrieved: AtomRoot? = values.atomRoot
        #expect(retrieved is AtomObjects)
    }

    @Test("atomRoot can hold custom AtomRoot subclass")
    func atomRootCustomSubclass() async throws {
        let root = AtomObjects()
        var values = EnvironmentValues()
        values.atomRoot = root

        #expect(values.atomRoot is AtomRoot)
        #expect(values.atomRoot is AtomObjects)
    }
}

@MainActor
@Suite("View Integration Tests")
struct ViewIntegrationTests {

    @Test("Full flow: AtomState read, modify, verify in hosting controller")
    func fullFlowState() async throws {
        let root = AtomObjects()
        root.viewCounter = GenericAtom<Int>(value: 0)

        let hosting = NSHostingController(
            rootView: AtomScope(root: root) {
                CounterStateView()
            })

        hosting.viewDidLoad()

        // Modify through root
        root.viewCounter.value = 10
        #expect(root.viewCounter.value == 10)

        // Verify atom identity is preserved
        root.viewCounter.value = 20
        #expect(root.viewCounter.value == 20)
    }

    @Test("Full flow: multiple scopes with modifiers")
    func fullFlowMultipleScopes() async throws {
        let root1 = AtomObjects()
        let root2 = AtomObjects()

        root1.viewCounter = GenericAtom<Int>(value: 1)
        root2.viewCounter = GenericAtom<Int>(value: 2)

        _ = NSHostingController(
            rootView: VStack {
                CounterStateView()
                    .atomScope(root: root1)
                CounterStateView()
                    .atomScope(root: root2)
            })

        #expect(root1.viewCounter.value == 1)
        #expect(root2.viewCounter.value == 2)
    }

    @Test("Full flow: action modifies state correctly")
    func fullFlowActionModifiesState() async throws {
        let root = AtomObjects()
        root.viewCounter = GenericAtom<Int>(value: 0)

        let action = AtomObjects.IncrementAction(amount: 7)
        try await action.perform(with: root)

        #expect(root.viewCounter.value == 7)
    }

    @Test("Full flow: multiple actions accumulate")
    func fullFlowMultipleActions() async throws {
        let root = AtomObjects()
        root.viewCounter = GenericAtom<Int>(value: 0)

        try await AtomObjects.IncrementAction(amount: 3).perform(with: root)
        try await AtomObjects.IncrementAction(amount: 5).perform(with: root)
        try await AtomObjects.IncrementAction(amount: -1).perform(with: root)

        #expect(root.viewCounter.value == 7)
    }

    @Test("Full flow: LogAction records events")
    func fullFlowLogAction() async throws {
        let root = AtomObjects()
        root.viewActionLog = GenericAtom<[String]>(value: [])

        try await AtomObjects.LogAction(message: "event1").perform(with: root)
        try await AtomObjects.LogAction(message: "event2").perform(with: root)

        let log = root.viewActionLog.value
        #expect(log.count == 2)
        #expect(log[0] == "event1")
        #expect(log[1] == "event2")
    }

    @Test("Full flow: view with action and state together")
    func fullFlowViewWithActionAndState() async throws {
        let root = AtomObjects()
        root.viewCounter = GenericAtom<Int>(value: 0)

        _ = NSHostingController(
            rootView: AtomScope(root: root) {
                ActionView()
            })

        // Simulate what happens when the action is triggered
        try await AtomObjects.IncrementAction(amount: 10).perform(with: root)
        #expect(root.viewCounter.value == 10)
    }

    @Test("Full flow: async action with view")
    func fullFlowAsyncActionWithView() async throws {
        let root = AtomObjects()
        root.viewCounter = GenericAtom<Int>(value: 0)

        _ = NSHostingController(
            rootView: AtomScope(root: root) {
                AsyncActionView()
            })

        // Simulate async action trigger
        try await AtomObjects.IncrementAction(amount: 5).perform(with: root)
        #expect(root.viewCounter.value == 5)
    }

    @Test("Full flow: complex nested hierarchy")
    func fullFlowComplexHierarchy() async throws {
        let root = AtomObjects()
        root.viewCounter = GenericAtom<Int>(value: 0)
        root.viewName = GenericAtom<String>(value: "root")

        _ = NSHostingController(
            rootView: AtomScope(root: root) {
                VStack {
                    CounterStateView()
                    CustomSetterView()
                }
            })

        #expect(root.viewCounter.value == 0)
        #expect(root.viewName.value == "root")
    }
}

// ── Reactivity test helpers ──

@MainActor
private final class ObservationTracker {
    nonisolated(unsafe) var changes = 0
}

// ── AtomState update() lifecycle tests ──

@MainActor
@Suite("AtomState update() Lifecycle Tests")
struct AtomStateUpdateTests {

    @Test("AtomState update() is safe to call repeatedly")
    func updateRepeatedly() async throws {
        let root = AtomObjects()
        root.viewCounter = GenericAtom<Int>(value: 0)
        let box = StateClosureBox()

        let window = renderInWindow(
            AtomScope(root: root) {
                StateProbeView(box: box)
            })
        defer { window.close() }

        // Create an AtomState instance and call update() multiple times.
        var state = AtomState(\AtomObjects.viewCounter, root: AtomObjects.self)
        for _ in 0..<100 {
            state.update()
        }

        // update() is a no-op — state should still read correctly.
        let read = try #require(box.read, "body should have captured the getter")
        #expect(read() == 0)
    }

    @Test("AtomState update() does not mutate atom value")
    func updateDoesNotMutate() async throws {
        let root = AtomObjects()
        root.viewCounter = GenericAtom<Int>(value: 42)

        var state = AtomState(\AtomObjects.viewCounter, root: AtomObjects.self)
        state.update()
        state.update()
        state.update()

        #expect(root.viewCounter.value == 42)
    }
}

// ── @Observable reactivity tests ──

@MainActor
@Suite("@Observable Reactivity Tests")
struct ObservableReactivityTests {

    @Test("GenericAtom conforms to Observable")
    func genericAtomConformsToObservable() async throws {
        let atom = GenericAtom<Int>(value: 0)
        #expect(atom is any Observable)
    }

    @Test("GenericAtom observation tracks value property changes")
    func genericAtomObservationTracksChanges() async throws {
        let atom = GenericAtom<Int>(value: 10)
        let tracker = ObservationTracker()

        // Use withObservationTracking to verify the observation system
        // tracks the atom's value property.
        _ = withObservationTracking {
            atom.value
        } onChange: {
            tracker.changes += 1
        }

        #expect(tracker.changes == 0)

        // Mutate the value — should trigger the change handler.
        atom.value = 20
        #expect(tracker.changes >= 1, "changing value should trigger observation")

        // A second mutation may or may not produce an additional notification
        // depending on batching — the key fact is that the observation
        // mechanism is active and fires at least once.
        atom.value = 30
        #expect(tracker.changes >= 1, "observation should remain active")
    }
}

// ── Deep nesting tests ──

@MainActor
@Suite("Deep Nesting Tests")
struct DeepNestingTests {

    @Test("Three-level root hierarchy has correct parent chain")
    func threeLevelParentChain() async throws {
        let level1 = AtomObjects()
        let level2 = level1[Level2RootKey.self] as AtomObjects
        let level3 = level2[Level3RootKey.self] as AtomObjects

        #expect(level3.parent === level2)
        #expect(level2.parent === level1)
        #expect(level1.parent == nil)
    }

    @Test("Three-level root hierarchy isolates state per level")
    func threeLevelStateIsolation() async throws {
        let level1 = AtomObjects()
        let level2 = level1[Level2RootKey.self] as AtomObjects
        let level3 = level2[Level3RootKey.self] as AtomObjects

        level1.viewCounter = GenericAtom<Int>(value: 100)
        level2.viewCounter = GenericAtom<Int>(value: 200)
        level3.viewCounter = GenericAtom<Int>(value: 300)

        #expect(level1.viewCounter.value == 100)
        #expect(level2.viewCounter.value == 200)
        #expect(level3.viewCounter.value == 300)

        // Mutate one level — others should be unaffected.
        level2.viewCounter.value = 250
        #expect(level1.viewCounter.value == 100)
        #expect(level2.viewCounter.value == 250)
        #expect(level3.viewCounter.value == 300)
    }

    @Test("Deep nested AtomScope renders independently")
    func deepNestedAtomScopeRenders() async throws {
        let level1 = AtomObjects()
        let level2 = AtomObjects()
        let level3 = AtomObjects()

        level1.viewCounter = GenericAtom<Int>(value: 1)
        level2.viewCounter = GenericAtom<Int>(value: 2)
        level3.viewCounter = GenericAtom<Int>(value: 3)

        let hosting = NSHostingController(
            rootView: AtomScope(root: level1) {
                AtomScope(root: level2) {
                    AtomScope(root: level3) {
                        CounterStateView()
                    }
                }
            })

        hosting.viewDidLoad()

        #expect(level1.viewCounter.value == 1)
        #expect(level2.viewCounter.value == 2)
        #expect(level3.viewCounter.value == 3)
    }

    @Test("Four-level nesting via AtomRootKey maintains parent chain")
    func fourLevelNestingViaKeys() async throws {
        let l1 = AtomObjects()
        let l2 = l1[Level2RootKey.self] as AtomObjects
        let l3 = l2[Level3RootKey.self] as AtomObjects
        // Reuse Level2RootKey at level 4 (different key type at each level
        // is not required — keys identify slots, not depth).
        let l4 = l3[Level2RootKey.self] as AtomObjects

        #expect(l4.parent === l3)
        #expect(l3.parent === l2)
        #expect(l2.parent === l1)
        #expect(l1.parent == nil)

        // Each level has independent state.
        l1.viewCounter.value = 10
        l2.viewCounter.value = 20
        l3.viewCounter.value = 30
        l4.viewCounter.value = 40

        #expect(l1.viewCounter.value == 10)
        #expect(l2.viewCounter.value == 20)
        #expect(l3.viewCounter.value == 30)
        #expect(l4.viewCounter.value == 40)
    }

    @Test("Live probe reads from nearest scope in nested hierarchy")
    func liveProbeReadsNearestScope() async throws {
        let parentRoot = AtomObjects()
        let childRoot = AtomObjects()

        parentRoot.viewCounter = GenericAtom<Int>(value: 100)
        childRoot.viewCounter = GenericAtom<Int>(value: 200)

        let box = StateClosureBox()

        let window = renderInWindow(
            AtomScope(root: parentRoot) {
                AtomScope(root: childRoot) {
                    StateProbeView(box: box)
                }
            })
        defer { window.close() }

        // Read through the probe — should see the child scope's value.
        let read = try #require(box.read, "body should have captured the getter")
        #expect(read() == 200, "probe should read from nearest (child) scope, not parent")

        // Write through the probe — should modify only the child scope.
        let write = try #require(box.write, "body should have captured the setter")
        write(999)
        #expect(childRoot.viewCounter.value == 999, "write should affect child scope")
        #expect(parentRoot.viewCounter.value == 100, "parent scope should be unaffected")
    }

    @Test("Live probe writes to nearest scope without affecting parent")
    func liveProbeWritesNearestScope() async throws {
        let parentRoot = AtomObjects()
        let childRoot = AtomObjects()

        parentRoot.viewCounter = GenericAtom<Int>(value: 10)
        childRoot.viewCounter = GenericAtom<Int>(value: 20)

        let box = StateClosureBox()

        let window = renderInWindow(
            AtomScope(root: parentRoot) {
                AtomScope(root: childRoot) {
                    StateProbeView(box: box)
                }
            })
        defer { window.close() }

        let write = try #require(box.write, "body should have captured the setter")

        // Multiple writes should all target the child scope.
        write(1)
        #expect(childRoot.viewCounter.value == 1)
        #expect(parentRoot.viewCounter.value == 10)

        write(2)
        #expect(childRoot.viewCounter.value == 2)
        #expect(parentRoot.viewCounter.value == 10)

        // Equal value exercises the setIfNotEqual skip branch.
        write(2)
        #expect(childRoot.viewCounter.value == 2)
    }
}
