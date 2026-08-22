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

/// Protocol for async commands with event-time `Input` and a returned `Output`.
///
/// Invoked via ``AtomInputAction``.
public protocol ParameterizedAtomObjectsAction {

    /// The root type this action operates on.
    associatedtype Root: AtomRoot

    /// Event-time input passed at the call site.
    associatedtype Input

    /// Value returned to `$action` callers.
    associatedtype Output

    /// Execute the action against the given root with an event-time input.
    ///
    /// - Parameters:
    ///   - root: The ``AtomRoot`` to mutate.
    ///   - input: Event-time input.
    /// - Returns: The action result.
    /// - Throws: Any error encountered during execution. Callers using
    ///   ``AtomInputAction/wrappedValue`` will see `assertionFailure` in debug builds.
    func perform(with root: Root, input: Input) async throws -> Output
}

/// A flat marker protocol for actions constructible with no arguments.
///
/// Conforming actions can be passed to the action wrappers as a metatype
/// instead of an instance — `@AtomAction(MyAction.self)` and
/// `@AtomInputAction(MyAction.self)` — skipping the empty `()`.
///
/// A stored-property-free struct's implicit `init()` satisfies this
/// requirement, so most parameterless actions need no added code. Actions
/// with required init parameters cannot conform, so the shorthand stays
/// unavailable exactly where it would be meaningless.
///
/// Deliberately a flat marker rather than a refinement of
/// ``AtomObjectsAction`` or ``ParameterizedAtomObjectsAction``: subprotocols
/// of those protocols trip `#ConformanceIsolation` on user conformances under
/// this package's MainActor default isolation.
public protocol DefaultInitializableAction {
    init()
}

/// Errors thrown by action wrappers before `perform` runs.
public enum AtomObjectsActionError: Error, Sendable, Equatable {
    /// `$action` was invoked with no matching ``AtomRoot`` in the environment.
    /// Fire-and-forget `wrappedValue` still no-ops; projected value with a
    /// non-Void `Output` throws so callers cannot receive a forged result.
    case missingRoot
}
