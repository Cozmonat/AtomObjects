// Copyright (c) 2023 Natan Zalkin — MIT License

import Foundation

extension Equatable {

    /// Type-erased equality check for values whose concrete type is only known at runtime.
    ///
    /// Used by ``AtomObject/setIfNotEqual(_:)`` to compare the current value
    /// against a new value without requiring a compile-time `Equatable` constraint
    /// on the associated type. Returns `false` if the types don't match.
    func isEqual<Other>(_ other: Other) -> Bool {
        if let other = other as? Self {
            return self == other
        }
        return false
    }
}
