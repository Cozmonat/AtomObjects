// Copyright (c) 2023 Natan Zalkin — MIT License

import SwiftUI
import os

private let actionLogger = Logger(subsystem: "AtomObjects", category: "AtomAction")

/// A property wrapper that exposes an ``AtomObjectsAction`` as a callable closure in SwiftUI views.
///
/// Provides two access patterns:
/// - **`wrappedValue`** (`action()`): fire-and-forget `() -> Void` closure. Spawns a `Task`
///   with `@MainActor` isolation. Errors are logged via `os.Logger` and trigger
///   `assertionFailure` in debug builds; `CancellationError` is ignored as a normal outcome.
///   Use this for simple button actions where error handling is not needed.
/// - **`projectedValue`** (`$action()`): `async throws` closure for explicit error handling.
///   Use this when you need to `await` completion or catch errors.
///
/// The action instance is stored once at initialization (not recreated per invocation).
/// `Equatable` always returns `true` — action wrappers are compared as structurally identical
/// to avoid unnecessary view re-evaluations.
///
/// ```swift
/// @AtomAction(MyActions.SubmitForm())
/// var submit
///
/// @State private var submitError: String?
///
/// var body: some View {
///     Button("Submit") { submit() }           // fire-and-forget
///     Button("Submit (safe)") {
///         Task {
///             do {
///                 try await $submit()
///                 submitError = nil
///             } catch {
///                 submitError = error.localizedDescription
///             }
///         }
///     }
/// }
/// ```
@propertyWrapper public struct AtomAction<Action>: DynamicProperty, Equatable
where Action: AtomObjectsAction {

    /// Always returns `true` — action wrappers are structurally identical for SwiftUI diffing.
    public static func == (lhs: Self, rhs: Self) -> Bool {
        true
    }

    public typealias Root = Action.Root

    /// The stored action instance, created once at initialization.
    private var action: Action

    @Environment(\.atomRoot) private var environmentRoot

    private var root: Root? {
        environmentRoot as? Root
    }

    /// Fire-and-forget closure. Spawns a `Task { @MainActor in ... }`, logs errors
    /// via `os.Logger`, and raises `assertionFailure` in debug builds.
    /// `CancellationError` is treated as a normal outcome, not a failure.
    public var wrappedValue: () -> Void {
        return {
            guard let root = self.root else { return }
            Task { @MainActor in
                do {
                    try await self.action.perform(with: root)
                } catch is CancellationError {
                    // Cancellation is a normal outcome, not a failure.
                } catch {
                    actionLogger.error("\(String(describing: Action.self)) failed: \(error)")
                    assertionFailure("AtomAction failed: \(error)")
                }
            }
        }
    }

    /// Async throws closure for explicit error handling and awaiting.
    public var projectedValue: () async throws -> Void {
        return {
            guard let root = self.root else { return }
            try await self.action.perform(with: root)
        }
    }

    public init(_ action: @autoclosure @escaping () -> Action) {
        self.action = action()
    }
}

/// Metatype shorthand for actions conforming to ``DefaultInitializableAction``:
/// `@AtomAction(MyAction.self)` instead of `@AtomAction(MyAction())`.
extension AtomAction where Action: DefaultInitializableAction {

    /// Creates the wrapper from an action's metatype, constructing the action
    /// with its no-argument initializer.
    public init(_ type: Action.Type) {
        self.init(type.init())
    }
}

/// A property wrapper that exposes a ``ParameterizedAtomObjectsAction`` as a callable closure.
///
/// - **`wrappedValue`**: fire-and-forget `(Input) -> Void`. Errors are logged
///   via `os.Logger` and trigger `assertionFailure` in debug builds.
///   `CancellationError` is ignored as a normal outcome.
/// - **`projectedValue`** (`$action`): `(Input) async throws -> Output`.
///
/// ```swift
/// @AtomInputAction(MyActions.SavePreset())
/// var save
///
/// Button("Save") {
///     Task {
///         let preset = try await $save(draft)
///     }
/// }
/// ```
@propertyWrapper public struct AtomInputAction<Action>: DynamicProperty, Equatable
where Action: ParameterizedAtomObjectsAction {

    public static func == (lhs: Self, rhs: Self) -> Bool {
        true
    }

    public typealias Root = Action.Root
    public typealias Input = Action.Input
    public typealias Output = Action.Output

    private var action: Action

    @Environment(\.atomRoot) private var environmentRoot

    private var root: Root? {
        environmentRoot as? Root
    }

    public var wrappedValue: (Input) -> Void {
        return { input in
            guard let root = self.root else { return }
            Task { @MainActor in
                do {
                    _ = try await self.action.perform(with: root, input: input)
                } catch is CancellationError {
                } catch {
                    actionLogger.error("\(String(describing: Action.self)) failed: \(error)")
                    assertionFailure("AtomAction failed: \(error)")
                }
            }
        }
    }

    public var projectedValue: (Input) async throws -> Output {
        return { input in
            guard let root = self.root else {
                return try await Self.missingRootOutput()
            }
            return try await self.action.perform(with: root, input: input)
        }
    }

    public init(_ action: @autoclosure @escaping () -> Action) {
        self.action = action()
    }

    private static func missingRootOutput() async throws -> Output {
        if let void = () as? Output {
            return void
        }
        throw AtomObjectsActionError.missingRoot
    }
}

/// Metatype shorthand for actions conforming to ``DefaultInitializableAction``:
/// `@AtomInputAction(MyAction.self)` instead of `@AtomInputAction(MyAction())`.
extension AtomInputAction where Action: DefaultInitializableAction {

    /// Creates the wrapper from an action's metatype, constructing the action
    /// with its no-argument initializer.
    public init(_ type: Action.Type) {
        self.init(type.init())
    }
}
