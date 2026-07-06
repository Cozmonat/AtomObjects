// Copyright (c) 2023 Natan Zalkin — MIT License

import SwiftUI

public struct AtomScope<Root, Content>: View where Root: AtomRoot, Content: View {

    @State private var root: Root

    private var content: () -> Content

    public var body: some View {
        content().environment(\.atomRoot, root)
    }

    public init(root: @autoclosure @escaping () -> Root, content: @escaping () -> Content) {
        self.content = content

        _root = State(wrappedValue: root())
    }
}
