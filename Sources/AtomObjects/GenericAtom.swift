// Copyright (c) 2023 Natan Zalkin — MIT License

import SwiftUI

@Observable
public class GenericAtom<Value>: AtomObject where Value: Sendable {

    public var value: Value

    public required init(value: Value) {
        self.value = value
    }
}
