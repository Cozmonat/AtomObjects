// Copyright (c) 2023 Natan Zalkin — MIT License

public protocol AtomObjectsAction {

    associatedtype Root: AtomRoot

    func perform(with root: Root) async
}
