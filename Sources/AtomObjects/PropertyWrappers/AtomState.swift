// Copyright (c) 2023 Natan Zalkin — MIT License

import SwiftUI

/// A property wrapper that reads and writes an atom value and triggers view updates on change.
///
/// ``AtomState`` is the primary way to bind atom values to SwiftUI views. It:
/// 1. Resolves the ``AtomRoot`` from the environment (injected by ``AtomScope``).
/// 2. Reads the atom via a key path to the root.
/// 3. Writes using ``AtomObject/setIfNotEqual(_:)`` by default, skipping no-op assignments.
/// 4. Optionally accepts a custom setter for validation or transformation.
///
/// The `projectedValue` (`$state`) returns a `Binding<Value>` for use with controls
/// like `Slider`, `TextField`, etc.
///
/// ```swift
/// @AtomState(\AtomObjects.counter)
/// var counter
///
/// var body: some View {
///     Slider(value: $counter, in: 0...10)  // projectedValue → Binding
/// }
/// ```
@propertyWrapper public struct AtomState<Root, Atom, Value>: DynamicProperty, Equatable
where Root: AtomRoot, Atom: AtomObject, Atom.Value == Value {

    /// Equality compares key paths — two states are equal if they observe the same atom.
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.keyPath == rhs.keyPath
    }

    @Environment(\.atomRoot) private var environmentRoot

    private var keyPath: ReferenceWritableKeyPath<Root, Atom>
    private var setter: ((_ newValue: Value, _ atomObject: Atom) -> Void)?

    private var root: Root? {
        environmentRoot as? Root
    }

    public var wrappedValue: Value {
        get {
            guard let root = root else {
                fatalError(
                    "AtomState: no AtomRoot found in environment. Ensure AtomScope is set up correctly."
                )
            }
            return root[keyPath: keyPath].value
        }
        nonmutating set {
            guard let root = root else { return }
            let atom = root[keyPath: keyPath]
            setter?(newValue, atom) ?? atom.setIfNotEqual(newValue)
        }
    }

    /// A `Binding<Value>` for use with SwiftUI controls (Slider, TextField, etc.).
    public var projectedValue: Binding<Value> {
        Binding {
            guard let root = self.root else {
                fatalError("AtomState: no AtomRoot found in environment.")
            }
            return root[keyPath: self.keyPath].value
        } set: { newValue in
            guard let root = self.root else { return }
            let atom = root[keyPath: keyPath]
            self.setter?(newValue, atom) ?? atom.setIfNotEqual(newValue)
        }
    }

    public mutating func update() {}

    /// Creates a proxy for a specific atom value that refreshes a view when the atom value is changed.
    ///
    /// - Parameters:
    ///   - keyPath: A key path to a specific atom in the root.
    ///   - root: An atom root type (defaults to `Root.self`).
    ///   - set: Optional custom setter. If `nil`, uses ``AtomObject/setIfNotEqual(_:)``.
    public init(
        _ keyPath: ReferenceWritableKeyPath<Root, Atom>,
        root: Root.Type = Root.self,
        set: ((_ newValue: Value, _ atomObject: Atom) -> Void)? = nil
    ) {
        self.keyPath = keyPath
        self.setter = set
    }
}
