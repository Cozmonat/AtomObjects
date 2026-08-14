// Copyright (c) 2023 Natan Zalkin — MIT License

import SwiftUI

/// Default ``AtomObject`` implementation for any `Sendable` value type.
///
/// Uses the `@Observable` macro so that property changes are automatically
/// tracked by SwiftUI when accessed through ``AtomScope`` or ``AtomState``.
///
/// ```swift
/// struct CounterKey: AtomObjectKey {
///     static var defaultValue: Int = 0
/// }
///
/// // In an AtomRoot extension:
/// var counter: GenericAtom<Int> {
///     get { self[CounterKey.self] }
///     set { self[CounterKey.self] = newValue }
/// }
/// ```
@Observable
public class GenericAtom<Value>: AtomObject {

    public var value: Value

    public required init(value: Value) {
        self.value = value
    }

    // Swift 6.3.3 crashes in the SIL EarlyPerfInliner while optimizing this
    // class's *implicit* deinit, so `-O` builds cannot compile the module at
    // all. Declaring the deinit explicitly is enough to avoid it. Remove once
    // the compiler no longer needs the hint.
    deinit {}
}
