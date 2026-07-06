// Copyright (c) 2023 Natan Zalkin — MIT License

import Foundation

open class AtomObjects: AtomRoot, Equatable {

    public static func == (lhs: AtomObjects, rhs: AtomObjects) -> Bool {
        return lhs === rhs
    }

    public override init() {
        super.init()
    }
}
