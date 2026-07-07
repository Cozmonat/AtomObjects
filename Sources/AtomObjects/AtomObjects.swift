// Copyright (c) 2023 Natan Zalkin — MIT License

import Foundation

/// Default ``AtomRoot`` implementation with identity-based equality.
///
/// Conforms to `Equatable` using identity comparison (`===`) so that root
/// instances can be compared for identity rather than structural equality.
/// This is useful for verifying that the same root is propagated through
/// the view hierarchy (e.g. in tests or debugging).
open class AtomObjects: AtomRoot, Equatable {

    /// Compares two roots for identity (same instance).
    public static func == (lhs: AtomObjects, rhs: AtomObjects) -> Bool {
        return lhs === rhs
    }

    public override init() {
        super.init()
    }
}
