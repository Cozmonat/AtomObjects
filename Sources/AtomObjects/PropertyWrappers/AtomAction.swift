// Copyright (c) 2023 Natan Zalkin — MIT License

import SwiftUI

/// A property wrapper type that exposes the invocation of an action of the specified type with the actual root.
/// The returned closure must be invoked on the main actor.
@propertyWrapper public struct AtomAction<Action>: DynamicProperty, Equatable
where Action: AtomObjectsAction {

    public static func == (lhs: Self, rhs: Self) -> Bool {
        true
    }

    public typealias Root = Action.Root

    private var action: Action

    @Environment(\.atomRoot) private var environmentRoot

    private var root: Root? {
        environmentRoot as? Root
    }

    public var wrappedValue: (() -> Void) {
        return {
            guard let root = self.root else { return }
            Task { @MainActor in
                do {
                    try await self.action.perform(with: root)
                } catch {
                    assertionFailure("AtomAction failed: \(error)")
                }
            }
        }
    }

    public var projectedValue: (() async throws -> Void) {
        return {
            guard let root = self.root else { return }
            try await self.action.perform(with: root)
        }
    }

    public init(_ action: @autoclosure @escaping () -> Action) {
        self.action = action()
    }
}
