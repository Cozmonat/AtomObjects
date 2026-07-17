//
//  Created by Natan Zalkin on 12/01/2023.
//  Copyright © 2023 Natan Zalkin. All rights reserved.
//

import AtomObjects
import SwiftUI

struct ContentView: View {

    @AtomState(\AtomObjects.counter)
    var counter

    var body: some View {
        VStack {
            Text("Counter: \(Int(counter))")
            Controls()

            SecondaryView()
                .atomScope(root: AtomObjects())

            TertiaryView()
                .atomScope(root: AtomObjects())
        }
        .padding()
    }
}

struct Controls: View {

    @AtomState(\AtomObjects.counter)
    var counter

    @AtomAction(AtomObjects.IncrementCounter(by: 1))
    var increment

    @AtomAction(AtomObjects.IncrementCounter(by: -1))
    var decrement

    @State
    var isEditing = false

    @State
    private var actionError: String?

    var body: some View {
        VStack {
            HStack {
                Button {
                    decrement()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title)
                }
                .accessibilityIdentifier("decrement")

                Slider(
                    value: $counter, in: 0...10,
                    onEditingChanged: { editing in
                        isEditing = editing
                    }
                ) {
                    Text("Value")
                }

                Button {
                    Task {
                        do {
                            try await $increment()
                            actionError = nil
                        } catch {
                            actionError = error.localizedDescription
                        }
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                }
                .accessibilityIdentifier("increment")
            }

            if let error = actionError {
                Text("Error: \(error)")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
    }
}

struct SecondaryView: View {

    @AtomState(\AtomObjects.counter)
    var counter: Float

    var body: some View {
        VStack {
            Text("Secondary counter: \(Int(counter))")
            Controls()
        }
    }
}

struct TertiaryView: View {

    @AtomState(
        \AtomObjects.counter,
        set: { newValue, atom in
            atom.value = newValue < atom.value ? newValue - 1 : newValue + 1
        })
    var counter

    @Environment(\.atomRoot) private var environmentRoot

    private var root: AtomObjects? {
        environmentRoot as? AtomObjects
    }

    var body: some View {
        VStack {
            HStack {
                Button {
                    counter -= 1
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title)
                }
                .accessibilityIdentifier("tertiaryDecrement")

                Spacer()

                Text("Tertiary counter: \(Int(counter))")

                Spacer()

                Button {
                    counter += 1
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                }
                .accessibilityIdentifier("tertiaryIncrement")
            }

            Button {
                root?.counter = GenericAtom(value: 5)
            } label: {
                Text("Rewrite atom")
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("rewrite")
        }
        .padding(.vertical)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var root = AtomObjects()

    static var previews: some View {
        AtomScope(root: root) {
            ContentView()
        }
    }
}
