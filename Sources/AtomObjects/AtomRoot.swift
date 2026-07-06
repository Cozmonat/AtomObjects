// Copyright (c) 2023 Natan Zalkin — MIT License

import Foundation
import SwiftUI

/// Environment key for AtomRoot instances.
private struct AtomRootEnvironmentKey: EnvironmentKey {
    static var defaultValue: AtomRoot? = nil
}

extension EnvironmentValues {
    /// The current atom root in the environment.
    public var atomRoot: AtomRoot? {
        get { self[AtomRootEnvironmentKey.self] }
        set { self[AtomRootEnvironmentKey.self] = newValue }
    }
}

public struct AtomStorage {

    private var storage = [ObjectIdentifier: AnyObject]()

    public subscript<Key, Atom>(key: Key.Type) -> Atom?
    where Key: AtomObjectKey, Atom: AtomObject, Atom.Value == Key.Value {
        get { storage[ObjectIdentifier(Key.self)] as? Atom }
        set { storage[ObjectIdentifier(Key.self)] = newValue }
    }

    public init() {}
}

public struct RootStorage {

    private var storage = [ObjectIdentifier: AnyObject]()

    public subscript<Key>(key: Key.Type) -> Key.Root? where Key: AtomRootKey {
        get { storage[ObjectIdentifier(Key.self)] as? Key.Root }
        set { storage[ObjectIdentifier(Key.self)] = newValue }
    }

    public init() {}
}

@Observable
open class AtomRoot {

    public var parent: AtomRoot?

    public var atoms: AtomStorage
    public var roots: RootStorage

    public init() {
        atoms = AtomStorage()
        roots = RootStorage()
    }

    open subscript<Key, Atom>(key: Key.Type) -> Atom
    where Key: AtomObjectKey, Atom: AtomObject, Atom.Value == Key.Value {
        get {
            if let atom: Atom = atoms[Key.self] {
                return atom
            } else {
                let atom = Atom(value: Key.defaultValue)
                atoms[Key.self] = atom
                return atom
            }
        }
        set {
            atoms[Key.self] = newValue
        }
    }

    open subscript<Key>(key: Key.Type) -> Key.Root where Key: AtomRootKey {
        get {
            if let root = roots[Key.self] {
                return root
            } else {
                let root = Key.defaultRoot
                roots[Key.self] = root
                root.parent = self
                return root
            }
        }
        set {
            roots[Key.self] = newValue
            newValue.parent = self
        }
    }
}
