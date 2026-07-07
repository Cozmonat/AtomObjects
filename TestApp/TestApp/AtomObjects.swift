//
//  Created by Natan Zalkin on 17/01/2023.
//  Copyright © 2023 Natan Zalkin. All rights reserved.
//

import AtomObjects
import Foundation

extension AtomObjects {

    struct CounterAtomKey: AtomObjectKey {

        static var defaultValue: Float = 0
    }

    struct IncrementCounter: AtomObjectsAction {

        var value: Float

        init(by value: Float) {
            self.value = value
        }

        func perform(with root: AtomObjects) async throws {

            @AtomValue(\.counter, in: root) var counter

            counter += value
        }
    }

    struct DecrementCounter: AtomObjectsAction {

        var value: Float

        init(by value: Float) {
            self.value = value
        }

        func perform(with root: AtomObjects) async throws {

            @AtomValue(\.counter, in: root) var counter

            counter -= value
        }
    }

    var counter: GenericAtom<Float> {
        get { return self[CounterAtomKey.self] }
        set { self[CounterAtomKey.self] = newValue }
    }
}
