// Copyright (c) 2023 Natan Zalkin — MIT License

import SwiftUI
import Testing

@testable import AtomObjects

// ── Test Keys (file-level so extensions can reference them) ──

private struct CounterKey: AtomObjectKey {
    static var defaultValue: Int = 0
}

private struct NameKey: AtomObjectKey {
    static var defaultValue: String = ""
}

private struct FlagKey: AtomObjectKey {
    static var defaultValue: Bool = false
}

private struct ScoreKey: AtomObjectKey {
    static var defaultValue: Double = 0.0
}

private struct ChildRootKey: AtomRootKey {
    static var defaultRoot: AtomObjects { AtomObjects() }
}

// ── AtomObjects extensions for AtomValue key paths ──

extension AtomObjects {
    var counter: GenericAtom<Int> {
        get { self[CounterKey.self] }
        set { self[CounterKey.self] = newValue }
    }

    var score: GenericAtom<Double> {
        get { self[ScoreKey.self] }
        set { self[ScoreKey.self] = newValue }
    }
}

@MainActor
@Suite("AtomObject Tests")
struct AtomObjectTests {

    // ── GenericAtom ──

    @Test("GenericAtom initialization with String")
    func genericAtomStringInit() async throws {
        let atom = GenericAtom<String>(value: "hello")
        #expect(atom.value == "hello")
    }

    @Test("GenericAtom initialization with Int")
    func genericAtomIntInit() async throws {
        let atom = GenericAtom<Int>(value: 42)
        #expect(atom.value == 42)
    }

    @Test("GenericAtom initialization with Bool")
    func genericAtomBoolInit() async throws {
        let atom = GenericAtom<Bool>(value: true)
        #expect(atom.value == true)
    }

    @Test("GenericAtom value mutation")
    func genericAtomMutation() async throws {
        let atom = GenericAtom<Int>(value: 0)
        atom.value = 10
        #expect(atom.value == 10)
        atom.value = 0
        #expect(atom.value == 0)
    }

    // ── AtomObject.setIfNotEqual ──

    @Test("setIfNotEqual prevents duplicate assignment")
    func setIfNotEqualSameValue() async throws {
        let atom = GenericAtom<Int>(value: 10)
        atom.setIfNotEqual(10)
        #expect(atom.value == 10)
    }

    @Test("setIfNotEqual applies different value")
    func setIfNotEqualDifferentValue() async throws {
        let atom = GenericAtom<Int>(value: 10)
        atom.setIfNotEqual(20)
        #expect(atom.value == 20)
    }

    @Test("setIfNotEqual with String")
    func setIfNotEqualString() async throws {
        let atom = GenericAtom<String>(value: "a")
        atom.setIfNotEqual("a")
        #expect(atom.value == "a")
        atom.setIfNotEqual("b")
        #expect(atom.value == "b")
    }

    @Test("setIfNotEqual with Bool")
    func setIfNotEqualBool() async throws {
        let atom = GenericAtom<Bool>(value: true)
        atom.setIfNotEqual(true)
        #expect(atom.value == true)
        atom.setIfNotEqual(false)
        #expect(atom.value == false)
    }

    // ── AtomRoot ──

    @Test("AtomRoot default value from key")
    func atomRootDefaultValue() async throws {
        let root = AtomObjects()
        let atom = root[CounterKey.self] as GenericAtom<Int>
        #expect(atom.value == 0)
    }

    @Test("AtomRoot atom value mutation via subscript")
    func atomRootAtomMutation() async throws {
        let root = AtomObjects()
        let atom = root[CounterKey.self] as GenericAtom<Int>
        atom.value = 5
        #expect(atom.value == 5)
    }

    @Test("AtomRoot subscript get returns same atom instance")
    func atomRootSubscriptGetSameInstance() async throws {
        let root = AtomObjects()
        let atom1 = root[CounterKey.self] as GenericAtom<Int>
        let atom2 = root[CounterKey.self] as GenericAtom<Int>
        #expect(atom1 === atom2, "repeated gets return the same atom instance")
    }

    @Test("AtomRoot subscript set replaces atom")
    func atomRootSubscriptSet() async throws {
        let root = AtomObjects()
        root[CounterKey.self] = GenericAtom<Int>(value: 99)
        let atom = root[CounterKey.self] as GenericAtom<Int>
        #expect(atom.value == 99)
    }

    @Test("AtomRoot lazy atom creation")
    func atomRootLazyCreation() async throws {
        let root = AtomObjects()
        _ = root[CounterKey.self] as GenericAtom<Int>
        let nameAtom: GenericAtom<String>? = root.atoms[NameKey.self]
        #expect(nameAtom == nil, "unaccessed key should not exist in atoms")
    }

    @Test("AtomRoot multiple atom types")
    func atomRootMultipleTypes() async throws {
        let root = AtomObjects()
        let counter = root[CounterKey.self] as GenericAtom<Int>
        let name = root[NameKey.self] as GenericAtom<String>
        let flag = root[FlagKey.self] as GenericAtom<Bool>

        counter.value = 42
        name.value = "test"
        flag.value = true

        #expect((root[CounterKey.self] as GenericAtom<Int>).value == 42)
        #expect((root[NameKey.self] as GenericAtom<String>).value == "test")
        #expect((root[FlagKey.self] as GenericAtom<Bool>).value == true)
    }

    // ── AtomRoot nested roots ──

    @Test("AtomRoot nested root lazy creation")
    func atomRootNestedLazyCreation() async throws {
        let root = AtomObjects()
        let child = root[ChildRootKey.self] as AtomObjects
        #expect(child.parent === root, "child root parent should be the parent")
    }

    @Test("AtomRoot nested root get returns same instance")
    func atomRootNestedGetSameInstance() async throws {
        let root = AtomObjects()
        let child1 = root[ChildRootKey.self] as AtomObjects
        let child2 = root[ChildRootKey.self] as AtomObjects
        #expect(child1 === child2, "repeated gets return the same root instance")
    }

    @Test("AtomRoot nested root set")
    func atomRootNestedSet() async throws {
        let root = AtomObjects()
        let customChild = AtomObjects()
        root[ChildRootKey.self] = customChild
        let retrieved = root[ChildRootKey.self] as AtomObjects
        #expect(retrieved === customChild, "set root should be returned on get")
        #expect(retrieved.parent === root)
    }

    @Test("AtomRoot parent is nil by default")
    func atomRootParentNil() async throws {
        let root = AtomObjects()
        #expect(root.parent == nil)
    }

    @Test("AtomRoot parent set when nested")
    func atomRootParentSet() async throws {
        let root = AtomObjects()
        _ = root[ChildRootKey.self] as AtomObjects
        let child: AtomObjects? = root.roots[ChildRootKey.self]
        #expect(child?.parent === root)
    }

    // ── Nested-root ownership enforcement ──

    @Test("Nested-root attachment is idempotent (same child, same parent)")
    func nestedRootIdempotentAttach() async throws {
        let root = AtomObjects()
        let child = AtomObjects()
        root[ChildRootKey.self] = child
        #expect(child.parent === root)

        // Capture the parent identity before re-set.
        let parentBefore = child.parent

        // Setting the same child again should be a no-op — no mutation at all.
        root[ChildRootKey.self] = child

        #expect(child.parent === root, "idempotent re-set preserves parent")
        #expect(child.parent === parentBefore,
                "idempotent re-set should not change the parent reference")
    }

    @Test("Replacing a nested root detaches the displaced child")
    func nestedRootReplacementDetachesOld() async throws {
        let root = AtomObjects()
        let oldChild = AtomObjects()
        let newChild = AtomObjects()

        root[ChildRootKey.self] = oldChild
        #expect(oldChild.parent === root)

        root[ChildRootKey.self] = newChild
        #expect(oldChild.parent == nil, "displaced child should be detached")
        #expect(newChild.parent === root, "new child should be attached")
    }

    @Test("canAttachNestedRoot rejects root with existing parent")
    func nestedRootCrossParentRejection() async throws {
        let parent1 = AtomObjects()
        let child = AtomObjects()

        // Attach child to parent1.
        parent1[ChildRootKey.self] = child
        #expect(child.parent === parent1)

        // The validation seam should reject a child that already has a parent.
        #expect(!AtomRoot.canAttachNestedRoot(child),
                "child with existing parent should not be attachable")
    }

    @Test("canAttachNestedRoot accepts root without parent")
    func nestedRootAttachableWhenOrphan() async throws {
        let child = AtomObjects()
        #expect(child.parent == nil)
        #expect(AtomRoot.canAttachNestedRoot(child),
                "orphan child should be attachable")
    }

    @Test("Same-slot re-set produces zero @Observable change notifications")
    func nestedRootIdempotentNoObservation() async throws {
        let root = AtomObjects()
        let child = AtomObjects()
        root[ChildRootKey.self] = child

        // Observe the `parent` property on the child for changes.
        // Use nonisolated(unsafe) because the onChange closure is @Sendable
        // but executes synchronously on the same actor context as the test.
        nonisolated(unsafe) var changeCount = 0
        withObservationTracking {
            _ = child.parent
        } onChange: {
            changeCount += 1
        }

        // Same-slot re-set should be a no-op — zero notifications.
        root[ChildRootKey.self] = child

        #expect(changeCount == 0,
                "idempotent re-set must not trigger @Observable change notifications")
        #expect(child.parent === root, "final parent identity should be preserved")
    }

    // ── AtomObjects Equatable ──

    @Test("AtomObjects equatable same instance")
    func atomObjectsEquatableSame() async throws {
        let root = AtomObjects()
        #expect(root == root, "same instance should be equal")
    }

    @Test("AtomObjects equatable different instances")
    func atomObjectsEquatableDifferent() async throws {
        let root1 = AtomObjects()
        let root2 = AtomObjects()
        #expect(root1 != root2, "different instances should not be equal")
    }

    @Test("AtomObjects equatable identity")
    func atomObjectsEquatableIdentity() async throws {
        let root: AtomObjects = AtomObjects()
        let ref = root
        #expect(root == ref, "same reference should be equal")
    }

    // ── AtomStorage ──

    @Test("AtomStorage initial state is empty")
    func atomStorageEmpty() async throws {
        let storage = AtomStorage()
        let atom: GenericAtom<Int>? = storage[CounterKey.self]
        #expect(atom == nil)
    }

    @Test("AtomStorage store and retrieve")
    func atomStorageStoreRetrieve() async throws {
        var storage = AtomStorage()
        let atom = GenericAtom<String>(value: "test")
        storage[NameKey.self] = atom
        let stored: GenericAtom<String>? = storage[NameKey.self]
        #expect(stored?.value == "test")
    }

    @Test("AtomStorage overwrite")
    func atomStorageOverwrite() async throws {
        var storage = AtomStorage()
        storage[CounterKey.self] = GenericAtom<Int>(value: 1)
        storage[CounterKey.self] = GenericAtom<Int>(value: 2)
        let stored: GenericAtom<Int>? = storage[CounterKey.self]
        #expect(stored?.value == 2)
    }

    @Test("AtomStorage multiple keys independent")
    func atomStorageMultipleKeys() async throws {
        var storage = AtomStorage()
        storage[CounterKey.self] = GenericAtom<Int>(value: 10)
        storage[FlagKey.self] = GenericAtom<Bool>(value: true)
        let counter: GenericAtom<Int>? = storage[CounterKey.self]
        let flag: GenericAtom<Bool>? = storage[FlagKey.self]
        #expect(counter?.value == 10)
        #expect(flag?.value == true)
    }

    // ── RootStorage ──

    @Test("RootStorage initial state is empty")
    func rootStorageEmpty() async throws {
        let storage = RootStorage()
        let root: AtomObjects? = storage[ChildRootKey.self]
        #expect(root == nil)
    }

    @Test("RootStorage store and retrieve")
    func rootStorageStoreRetrieve() async throws {
        var storage = RootStorage()
        let root = AtomObjects()
        storage[ChildRootKey.self] = root
        let stored: AtomObjects? = storage[ChildRootKey.self]
        #expect(stored !== nil)
    }

    @Test("RootStorage overwrite")
    func rootStorageOverwrite() async throws {
        var storage = RootStorage()
        let root1 = AtomObjects()
        let root2 = AtomObjects()
        storage[ChildRootKey.self] = root1
        storage[ChildRootKey.self] = root2
        let stored: AtomObjects? = storage[ChildRootKey.self]
        #expect(stored === root2)
    }

    // ── AtomValue ──

    @Test("AtomValue wrappedValue get")
    func atomValueGet() async throws {
        let root = AtomObjects()
        root[CounterKey.self] = GenericAtom<Int>(value: 42)
        let value = AtomValue(\.counter, in: root)
        #expect(value.wrappedValue == 42)
    }

    @Test("AtomValue wrappedValue set")
    func atomValueSet() async throws {
        let root = AtomObjects()
        root[CounterKey.self] = GenericAtom<Int>(value: 0)
        var value = AtomValue(\.counter, in: root)
        value.wrappedValue = 100
        #expect((root[CounterKey.self] as GenericAtom<Int>).value == 100)
    }

    @Test("AtomValue init with atom directly")
    func atomValueDirectInit() async throws {
        let atom = GenericAtom<String>(value: "direct")
        var value = AtomValue(atom)
        #expect(value.wrappedValue == "direct")
        value.wrappedValue = "updated"
        #expect(atom.value == "updated")
    }

    @Test("AtomValue equatable same atom")
    func atomValueEquatableSame() async throws {
        let root = AtomObjects()
        _ = root[CounterKey.self] as GenericAtom<Int>
        let v1 = AtomValue(\.counter, in: root)
        let v2 = AtomValue(\.counter, in: root)
        #expect(v1 == v2, "same atom should produce equal AtomValue instances")
    }

    @Test("AtomValue equatable different atoms same type")
    func atomValueEquatableDifferent() async throws {
        struct AltCounterKey: AtomObjectKey {
            static var defaultValue: Int = 0
        }
        let root = AtomObjects()
        _ = root[CounterKey.self] as GenericAtom<Int>
        _ = root[AltCounterKey.self] as GenericAtom<Int>
        let atom1 = root[CounterKey.self] as GenericAtom<Int>
        let atom2 = root[AltCounterKey.self] as GenericAtom<Int>
        let v1 = AtomValue(atom1)
        let v2 = AtomValue(atom2)
        #expect(v1 != v2, "different atoms should produce unequal AtomValue instances")
    }

    // ── Equatable extension (isEqual) ──

    @Test("isEqual with matching types")
    func isEqualMatchingTypes() async throws {
        let value: Int = 5
        #expect(value.isEqual(5) == true)
        #expect(value.isEqual(10) == false)
    }

    @Test("isEqual with mismatched types returns false")
    func isEqualMismatchedTypes() async throws {
        let value: Int = 5
        #expect(value.isEqual("hello") == false)
        #expect(value.isEqual(5.0) == false)
        #expect(value.isEqual(true) == false)
    }

    @Test("isEqual with String")
    func isEqualString() async throws {
        let value: String = "test"
        #expect(value.isEqual("test") == true)
        #expect(value.isEqual("other") == false)
    }

}
