// Copyright (c) 2023 Natan Zalkin — MIT License

import Foundation

/// Base protocol for observable state units stored in an ``AtomRoot``.
///
/// - Inheritance: Requires `AnyObject` (class-only) so atoms can be stored
///   as `AnyObject` in ``AtomStorage`` and compared by identity.
/// - Value type: `Value` is constrained to `Sendable` to ensure values can
///   safely cross concurrency boundaries (e.g. when read from background tasks).
/// - Observation: Concrete atoms should be `@Observable` classes so that
///   changes propagate through SwiftUI via ``AtomScope``.
public protocol AtomObject: AnyObject {

    /// The stored value type. Must be `Sendable` for concurrency safety.
    associatedtype Value: Sendable

    /// The current value. Mutating this property triggers observation
    /// when the atom is an `@Observable` class.
    var value: Value { get set }

    init(value: Value)
}

extension AtomObject {

    /// Sets the value only if it differs from the current value.
    ///
    /// Uses runtime `Equatable` checking via ``Equatable/isEqual(_:)``.
    /// For non-Equatable values, the assignment always proceeds.
    /// This prevents unnecessary observation notifications when the value
    /// hasn't actually changed.
    func setIfNotEqual(_ newValue: Value) {
        if let value = value as? any Equatable {
            guard !value.isEqual(newValue) else {
                return
            }
        }
        value = newValue
    }
}
