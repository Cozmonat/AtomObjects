// Copyright (c) 2023 Natan Zalkin — MIT License

import Foundation

public protocol AtomObject: AnyObject {

    associatedtype Value: Sendable

    var value: Value { get set }

    init(value: Value)
}

extension AtomObject {

    /// Sets the value only if it differs from the current value.
    /// For non-Equatable values, the assignment always proceeds.
    func setIfNotEqual(_ newValue: Value) {
        if let value = value as? any Equatable {
            guard !value.isEqual(newValue) else {
                return
            }
        }
        value = newValue
    }
}
