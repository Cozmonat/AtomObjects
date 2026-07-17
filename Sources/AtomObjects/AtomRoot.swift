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

/// Type-erased storage for atom instances, keyed by their ``AtomObjectKey`` type.
///
/// Uses `ObjectIdentifier(Key.self)` as the dictionary key, which is stable
/// for the lifetime of the process (type metadata never changes address).
/// Values are stored as `AnyObject` — this is safe because ``AtomObject``
/// inherits from `AnyObject`, guaranteeing all atoms are reference types.
public struct AtomStorage {

    private var storage = [ObjectIdentifier: AnyObject]()

    public subscript<Key, Atom>(key: Key.Type) -> Atom?
    where Key: AtomObjectKey, Atom: AtomObject, Atom.Value == Key.Value {
        get { storage[ObjectIdentifier(Key.self)] as? Atom }
        set { storage[ObjectIdentifier(Key.self)] = newValue }
    }

    public init() {}
}

/// Type-erased storage for nested root instances, keyed by their ``AtomRootKey`` type.
///
/// Uses the same `ObjectIdentifier(Key.self)` strategy as ``AtomStorage``.
/// Values are stored as `AnyObject` — safe because ``AtomRoot`` is a class.
///
/// > Important: Mutate nested roots through the ``AtomRoot/subscript(key:)``
/// > accessor, which enforces the single-parent invariant. Direct storage
/// > mutation bypasses those checks.
public struct RootStorage {

    private var storage = [ObjectIdentifier: AnyObject]()

    public subscript<Key>(key: Key.Type) -> Key.Root? where Key: AtomRootKey {
        get { storage[ObjectIdentifier(Key.self)] as? Key.Root }
        set { storage[ObjectIdentifier(Key.self)] = newValue }
    }

    public init() {}
}

/// Central state container managing atoms and nested roots.
///
/// - Memory management: ``parent`` is `weak` to break retain cycles between
///   nested roots. The owning parent holds a strong reference to the child
///   via ``RootStorage``, while the child holds only a `weak` back-reference.
/// - Thread safety: All public APIs are isolated to `@MainActor` (package default).
/// - Nested roots: Use the ``subscript(key:)`` accessor (constrained to
///   ``AtomRootKey``) for all attachment. Directly mutating ``parent`` is
///   blocked — only this class can set the back-reference internally.
@Observable
open class AtomRoot {

    /// Weak back-reference to the parent root.
    /// `weak` to prevent retain cycles: parent → (strong) → child → (weak) → parent.
    /// Write-access is restricted to `private(set)` so only the attachment
    /// subscript inside this class can mutate the relationship — direct
    /// `child.parent = someRoot` from outside is a compile-time error.
    public weak private(set) var parent: AtomRoot?

    public var atoms: AtomStorage
    public private(set) var roots: RootStorage

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
                attachNestedRoot(root, for: Key.self)
                return root
            }
        }
        set {
            attachNestedRoot(newValue, for: Key.self)
        }
    }

    // ── Nested-root attachment chokepoint ──

    /// Single point for attaching a nested root to this parent.
    ///
    /// Mutation order: guard → detach → attach.
    /// 1. Idempotent: setting the same child already attached to `self` is a no-op.
    /// 2. Validate incoming child has no existing parent (before any mutation).
    /// 3. Detach the replaced child (its `parent` cleared).
    /// 4. Attach the new child (`parent` set to `self`, stored in ``roots``).
    private func attachNestedRoot<Key: AtomRootKey>(_ root: Key.Root, for key: Key.Type) {
        // Idempotent: already attached to this parent — nothing to do.
        if let existing = roots[Key.self], existing === root, root.parent === self {
            return
        }

        // Validate incoming child before mutating any state.
        guard root.parent == nil else {
            fatalError(
                "Cannot attach nested root for \(Key.self): instance already owned by another root. "
                + "Make \(Key.self).defaultRoot a computed property that returns a fresh instance."
            )
        }

        // Detach the old child, if any.
        if let existing = roots[Key.self] {
            existing.parent = nil
        }

        root.parent = self
        roots[Key.self] = root
    }
}
