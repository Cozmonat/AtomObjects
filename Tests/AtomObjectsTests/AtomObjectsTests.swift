// Copyright (c) 2023 Natan Zalkin — MIT License

import SwiftUI
import Testing

@testable import AtomObjects

@MainActor
@Suite("AtomObject Tests")
struct AtomObjectTests {

    struct CounterKey: AtomObjectKey {
        static var defaultValue: Int = 0
    }

    @Test("Default value from key")
    func defaultValue() async throws {
        let root = AtomObjects()
        let atom = root[CounterKey.self] as GenericAtom<Int>
        #expect(atom.value == 0)
    }

    @Test("Atom value mutation")
    func mutation() async throws {
        let root = AtomObjects()
        let atom = root[CounterKey.self] as GenericAtom<Int>
        atom.value = 5
        #expect(atom.value == 5)
    }

    @Test("GenericAtom initialization")
    func genericAtomInit() async throws {
        let atom = GenericAtom<String>(value: "hello")
        #expect(atom.value == "hello")
    }

    @Test("setThenNotEqual guard")
    func setThenNotEqual() async throws {
        let atom = GenericAtom<Int>(value: 10)
        atom.setThenNotEqual(10)  // Same value — no change
        #expect(atom.value == 10)
        atom.setThenNotEqual(20)  // Different value — updates
        #expect(atom.value == 20)
    }

    @Test("AtomStorage subscript")
    func atomStorage() async throws {
        var storage = AtomStorage()
        let atom = GenericAtom<String>(value: "test")
        storage[TestKey.self] = atom
        let stored: GenericAtom<String>? = storage[TestKey.self]
        #expect(stored?.value == "test")
    }

    struct TestKey: AtomObjectKey {
        static var defaultValue: String = ""
    }

    @Test("RootStorage subscript")
    func rootStorage() async throws {
        var storage = RootStorage()
        let root = AtomObjects()
        storage[TestRootKey.self] = root
        #expect(storage[TestRootKey.self] !== nil)
    }

    struct TestRootKey: AtomRootKey {
        static var defaultRoot: AtomObjects = AtomObjects()
    }

    @Test("Lazy atom creation")
    func lazyCreation() async throws {
        let root = AtomObjects()
        _ = root[CounterKey.self] as GenericAtom<Int>
        let testAtom: GenericAtom<String>? = root.atoms[TestKey.self]
        #expect(testAtom == nil)  // Only CounterKey was accessed
    }
}
