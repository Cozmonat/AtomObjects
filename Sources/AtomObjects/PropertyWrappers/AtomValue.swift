// Copyright (c) 2023 Natan Zalkin — MIT License

/// A convenience property wrapper type that can read and write a value of a specific atom.
@propertyWrapper public struct AtomValue<Atom>: Equatable
where Atom: AtomObject {

    public static func == (lhs: AtomValue<Atom>, rhs: AtomValue<Atom>) -> Bool {
        lhs.atom === rhs.atom
    }

    public typealias Value = Atom.Value

    private var atom: Atom

    public var wrappedValue: Value {
        get { return atom.value }
        set { atom.value = newValue }
    }

    /// Creates a proxy for a specific atom value.
    ///
    /// - Parameters:
    ///   - keyPath: A key path to a specific atom in the root.
    ///   - root: An atom root type.
    public init<Root>(_ keyPath: ReferenceWritableKeyPath<Root, Atom>, in root: Root)
    where Root: AtomRoot {
        atom = root[keyPath: keyPath]
    }

    /// Creates a proxy for a specific atom value.
    public init(_ atom: Atom) {
        self.atom = atom
    }
}
