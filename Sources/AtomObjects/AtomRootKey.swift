// Copyright (c) 2023 Natan Zalkin — MIT License

public protocol AtomRootKey {

    associatedtype Root: AtomRoot

    static var defaultRoot: Root { get }
}
