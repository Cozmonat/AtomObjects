// Copyright (c) 2023 Natan Zalkin — MIT License

public protocol AtomObjectKey {

    associatedtype Value

    static var defaultValue: Value { get }
}
