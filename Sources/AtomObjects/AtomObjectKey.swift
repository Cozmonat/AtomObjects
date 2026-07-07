// Copyright (c) 2023 Natan Zalkin — MIT License

/// Type-safe key for storing and retrieving atoms in an ``AtomRoot``.
///
/// Each unique type conforming to this protocol acts as a unique identifier
/// for an atom slot. The ``AtomRoot`` uses `ObjectIdentifier(Key.self)` to
/// index atoms, so the type itself is the key — no string-based lookup.
///
/// ```swift
/// struct CounterKey: AtomObjectKey {
///     static var defaultValue: Int = 0
/// }
///
/// let atom = root[CounterKey.self] as GenericAtom<Int>
/// ```
public protocol AtomObjectKey {

    /// The value type of the atom associated with this key.
    associatedtype Value

    /// The initial value used when the atom is lazily created on first access.
    static var defaultValue: Value { get }
}
