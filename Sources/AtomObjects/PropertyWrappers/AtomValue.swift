// Copyright (c) 2023 Natan Zalkin — MIT License

/// A non-reactive property wrapper that provides direct read/write access to an atom value.
///
/// Unlike ``AtomState``, ``AtomValue`` does **not** conform to `DynamicProperty` — it
/// does not trigger view re-evaluation. Use it inside ``AtomObjectsAction`` implementations
/// to read and mutate atom values without creating a view binding.
///
/// ```swift
/// struct IncrementAction: AtomObjectsAction {
///     func perform(with root: AtomObjects) async throws {
///         @AtomValue(\.counter, in: root) var counter
///         counter += 1  // Direct mutation, no view binding
///     }
/// }
/// ```
@propertyWrapper public struct AtomValue<Atom>: Equatable
where Atom: AtomObject {

    /// Compares the underlying atom instances by identity.
    public static func == (lhs: AtomValue<Atom>, rhs: AtomValue<Atom>) -> Bool {
        lhs.atom === rhs.atom
    }

    public typealias Value = Atom.Value

    private var atom: Atom

    public var wrappedValue: Value {
        get { return atom.value }
        set { atom.value = newValue }
    }

    /// Creates a proxy for a specific atom value by resolving it from a root via key path.
    ///
    /// - Parameters:
    ///   - keyPath: A key path to a specific atom in the root.
    ///   - root: The ``AtomRoot`` instance to resolve the atom from.
    public init<Root>(_ keyPath: ReferenceWritableKeyPath<Root, Atom>, in root: Root)
    where Root: AtomRoot {
        atom = root[keyPath: keyPath]
    }

    /// Creates a proxy for a specific atom value directly.
    public init(_ atom: Atom) {
        self.atom = atom
    }
}
