// Copyright (c) 2023 Natan Zalkin — MIT License

import SwiftUI

/// View modifier that injects an ``AtomRoot`` into the environment.
///
/// Uses `@State` + `@Observable` (same pattern as ``AtomScope``) to ensure
/// the root is properly observed and view updates are triggered.
internal struct AtomScopeViewModifier<Root>: ViewModifier where Root: AtomRoot {

    @State private var root: Root

    public func body(content: Content) -> some View {
        content.environment(\.atomRoot, root)
    }

    init(root: @autoclosure @escaping () -> Root) {
        _root = State(wrappedValue: root())
    }
}

extension View {

    /// Attaches an ``AtomRoot`` to this view's environment, making it available
    /// to all child views via `@Environment(\.atomRoot)`.
    public func atomScope<Root>(root: @autoclosure @escaping () -> Root) -> some View
    where Root: AtomRoot {
        return self.modifier(AtomScopeViewModifier(root: root()))
    }
}
