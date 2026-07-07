// Copyright (c) 2023 Natan Zalkin — MIT License

import SwiftUI

/// A property wrapper type that can read and write a value of a specific atom and refreshes views when the value is changed.
@propertyWrapper public struct AtomState<Root, Atom, Value>: DynamicProperty, Equatable
where Root: AtomRoot, Atom: AtomObject, Atom.Value == Value {

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
    ///   - root: An atom root type.
    ///   - set: An in-place atom value setter.
    public init(
        _ keyPath: ReferenceWritableKeyPath<Root, Atom>,
        root: Root.Type = Root.self,
        set: ((_ newValue: Value, _ atomObject: Atom) -> Void)? = nil
    ) {
        self.keyPath = keyPath
        self.setter = set
    }
}
