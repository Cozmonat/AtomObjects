// Copyright (c) 2023 Natan Zalkin — MIT License

/// Protocol for async state-mutating commands.
///
/// Actions are invoked via ``AtomAction`` property wrappers in SwiftUI views.
/// - `wrappedValue`: fire-and-forget closure (errors trigger `assertionFailure`).
/// - `projectedValue` (`$action`): `async throws` closure for explicit error handling.
///
/// Implementations should use ``AtomValue`` to read/write atoms within ``perform(with:)``.
public protocol AtomObjectsAction {

    /// The root type this action operates on.
    associatedtype Root: AtomRoot

    /// Execute the action against the given root.
    ///
    /// - Parameter root: The ``AtomRoot`` to mutate.
    /// - Throws: Any error encountered during execution. Callers using
    ///   ``AtomAction/wrappedValue`` will see `assertionFailure` in debug builds.
    func perform(with root: Root) async throws
}
