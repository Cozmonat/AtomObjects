// Copyright (c) 2023 Natan Zalkin — MIT License

import SwiftUI

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

    public func atomScope<Root>(root: @autoclosure @escaping () -> Root) -> some View
    where Root: AtomRoot {
        return self.modifier(AtomScopeViewModifier(root: root()))
    }
}
