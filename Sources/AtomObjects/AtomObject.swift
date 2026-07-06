// Copyright (c) 2023 Natan Zalkin — MIT License

import Foundation

public protocol AtomObject: AnyObject {

    associatedtype Value

    var value: Value { get set }

    init(value: Value)
}

extension AtomObject {

    func setThenNotEqual(_ newValue: Value) {
        if let value = value as? any Equatable {
            guard !value.isEqual(newValue) else {
                return
            }
        }
        value = newValue
    }
}
