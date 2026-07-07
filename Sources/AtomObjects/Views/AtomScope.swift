// Copyright (c) 2023 Natan Zalkin — MIT License

import SwiftUI

/// A view that provides an ``AtomRoot`` instance to its content via environment.
///
/// Uses `@State` to hold the root — this is the recommended pattern for
/// `@Observable` classes in iOS 17+. The `@State` property wrapper wraps
/// the `@Observable` reference and notifies SwiftUI when observed properties
/// change, triggering view body re-evaluation.
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
