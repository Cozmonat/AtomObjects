// Copyright (c) 2023 Natan Zalkin — MIT License

import Foundation

extension Equatable {

    func isEqual<Other>(_ other: Other) -> Bool {
        if let other = other as? Self {
            return self == other
        }
        return false
    }
}
