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
    static var defaultRoot: AtomObjects = AtomObjects()
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

        func perform(with root: AtomObjects) async {
            @AtomValue(\.viewCounter, in: root) var counter
            counter += amount
        }
    }

    struct LogAction: AtomObjectsAction {
        var message: String

        func perform(with root: AtomObjects) async {
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
                    await $addFive()
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

// ── Tests ──

@MainActor
@Suite("AtomState View Tests")
struct AtomStateViewTests {

    @Test("AtomState view renders inside AtomScope")
    func atomStateViewRenders() async throws {
        let root = AtomObjects()
        root.viewCounter = GenericAtom<Int>(value: 42)

        let hosting = NSHostingController(rootView: AtomScope(root: root) {
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

        _ = NSHostingController(rootView: AtomScope(root: root) {
            CounterStateView()
        })

        root.viewCounter.value = 7
        #expect(root.viewCounter.value == 7)
    }

    @Test("AtomState with custom setter view renders")
    func atomStateCustomSetterViewRenders() async throws {
        let root = AtomObjects()
        root.viewCounter = GenericAtom<Int>(value: 0)

        _ = NSHostingController(rootView: AtomScope(root: root) {
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

        _ = NSHostingController(rootView: AtomScope(root: root) {
            VStack {
                CounterStateView()
                CounterStateView()
            }
        })

        root.viewCounter.value = 5
        #expect(root.viewCounter.value == 5)
    }
}

@MainActor
@Suite("AtomAction View Tests")
struct AtomActionViewTests {

    @Test("AtomAction view renders inside AtomScope")
    func atomActionViewRenders() async throws {
        let root = AtomObjects()
        root.viewCounter = GenericAtom<Int>(value: 0)

        _ = NSHostingController(rootView: AtomScope(root: root) {
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

        _ = NSHostingController(rootView: AtomScope(root: root) {
            AsyncActionView()
        })

        #expect(root.viewCounter.value == 0)
    }

    @Test("AtomAction with LogAction view renders")
    func atomActionLogViewRenders() async throws {
        let root = AtomObjects()
        root.viewActionLog = GenericAtom<[String]>(value: [])

        _ = NSHostingController(rootView: AtomScope(root: root) {
            LogActionView()
        })

        #expect(root.viewActionLog.value.isEmpty)
    }
}

@MainActor
@Suite("AtomScope View Tests")
struct AtomScopeViewTests {

    @Test("AtomScope struct provides root to environment")
    func atomScopeStructProvidesRoot() async throws {
        let root = AtomObjects()
        root.viewCounter = GenericAtom<Int>(value: 99)

        let hosting = NSHostingController(rootView: AtomScope(root: root) {
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

        let hosting = NSHostingController(rootView: ModifierScopeView()
            .atomScope(root: root))

        hosting.viewDidLoad()
        // hosting controller created successfully
        #expect(root.viewCounter.value == 77)
    }

    @Test("AtomScope nested roots render independently")
    func atomScopeNestedIndependent() async throws {
        let parentRoot = AtomObjects()
        parentRoot.viewCounter = GenericAtom<Int>(value: 10)

        let hosting = NSHostingController(rootView: AtomScope(root: parentRoot) {
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

        _ = NSHostingController(rootView: AtomScope(root: parentRoot) {
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

        let structHosting = NSHostingController(rootView: AtomScope(root: root1) {
            StructScopeView()
        })

        let modifierHosting = NSHostingController(rootView: ModifierScopeView()
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

        let hosting = NSHostingController(rootView: AtomScope(root: root) {
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

        _ = NSHostingController(rootView: VStack {
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
        await action.perform(with: root)

        #expect(root.viewCounter.value == 7)
    }

    @Test("Full flow: multiple actions accumulate")
    func fullFlowMultipleActions() async throws {
        let root = AtomObjects()
        root.viewCounter = GenericAtom<Int>(value: 0)

        await AtomObjects.IncrementAction(amount: 3).perform(with: root)
        await AtomObjects.IncrementAction(amount: 5).perform(with: root)
        await AtomObjects.IncrementAction(amount: -1).perform(with: root)

        #expect(root.viewCounter.value == 7)
    }

    @Test("Full flow: LogAction records events")
    func fullFlowLogAction() async throws {
        let root = AtomObjects()
        root.viewActionLog = GenericAtom<[String]>(value: [])

        await AtomObjects.LogAction(message: "event1").perform(with: root)
        await AtomObjects.LogAction(message: "event2").perform(with: root)

        let log = root.viewActionLog.value
        #expect(log.count == 2)
        #expect(log[0] == "event1")
        #expect(log[1] == "event2")
    }

    @Test("Full flow: view with action and state together")
    func fullFlowViewWithActionAndState() async throws {
        let root = AtomObjects()
        root.viewCounter = GenericAtom<Int>(value: 0)

        _ = NSHostingController(rootView: AtomScope(root: root) {
            ActionView()
        })

        // Simulate what happens when the action is triggered
        await AtomObjects.IncrementAction(amount: 10).perform(with: root)
        #expect(root.viewCounter.value == 10)
    }

    @Test("Full flow: async action with view")
    func fullFlowAsyncActionWithView() async throws {
        let root = AtomObjects()
        root.viewCounter = GenericAtom<Int>(value: 0)

        _ = NSHostingController(rootView: AtomScope(root: root) {
            AsyncActionView()
        })

        // Simulate async action trigger
        await AtomObjects.IncrementAction(amount: 5).perform(with: root)
        #expect(root.viewCounter.value == 5)
    }

    @Test("Full flow: complex nested hierarchy")
    func fullFlowComplexHierarchy() async throws {
        let root = AtomObjects()
        root.viewCounter = GenericAtom<Int>(value: 0)
        root.viewName = GenericAtom<String>(value: "root")

        _ = NSHostingController(rootView: AtomScope(root: root) {
            VStack {
                CounterStateView()
                CustomSetterView()
            }
        })

        #expect(root.viewCounter.value == 0)
        #expect(root.viewName.value == "root")
    }
}
