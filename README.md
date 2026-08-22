# AtomObjects for SwiftUI

[![License](https://img.shields.io/badge/license-MIT-ff69b4.svg)](https://github.com/kzlekk/AtomObjects/raw/master/LICENSE)
![Language](https://img.shields.io/badge/swift-6.2-orange.svg)
![Coverage](https://img.shields.io/badge/coverage-92%25-blue)

AtomObjects is a lightweight state management library for SwiftUI. It lets you build reusable, scoped state with minimal boilerplate by using small, decentralized "atom" primitives instead of a centralized store.

## Requirements

- iOS 17.0+ / macOS 14.0+ / watchOS 10.0+ / tvOS 17.0+
- Swift 6.2+

## Motivation

Rather than managing a single large data model, AtomObjects uses small, independent atom state primitives. This approach enables pinpoint view refreshes without having to design a complex update strategy for a bigger model. While you *can* implement complex state within a single atom, the library is designed around keeping atoms small and focused.

AtomObjects leverages Swift's `@Observable` macro for automatic change tracking and efficient view updates — no Combine, `ObservableObject`, or `@Published` required.

## Installation

### Swift Package Manager

Add the AtomObjects package to your Xcode project via **File → Add Package Dependencies...**, or add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/kzlekk/AtomObjects.git", from: "1.0.0")
]
```

## Concepts

| Symbol | Role |
|--------|------|
| `AtomObject` | Protocol for atom state values |
| `GenericAtom<Value>` | Built-in atom implementation for any `Sendable` value |
| `AtomObjectKey` | Unique key that defines a default value for an atom |
| `AtomRoot` | `@Observable` container that holds atoms (and nested roots) |
| `AtomObjects` | Ready-to-subclass `AtomRoot` with `Equatable` support |
| `AtomScope` / `.atomScope()` | View wrapper / modifier that injects a root into the environment |
| `@AtomState` | Property wrapper that reads/writes an atom and refreshes the view |
| `@AtomAction` | Property wrapper that invokes an `AtomObjectsAction` against the root |
| `@AtomInputAction` | Property wrapper for `ParameterizedAtomObjectsAction` (input/output) |
| `DefaultInitializableAction` | Opt-in marker enabling the metatype shorthand for parameterless actions |
| `@AtomValue` | Property wrapper for direct atom access (e.g., inside actions) |

## Setup

### 1. Define an atom key

Every atom is identified by a key that provides a default value:

```swift
struct EditingAtomKey: AtomObjectKey {
    static var defaultValue: Bool = false
}
```

### 2. Register the atom on your root

Extend `AtomObjects` (or a custom subclass) to expose the atom as a property. The key is used as the identifier inside the root's storage:

```swift
extension AtomObjects {
    var isEditing: GenericAtom<Bool> {
        get { self[EditingAtomKey.self] }
        set { self[EditingAtomKey.self] = newValue }
    }
}
```

> **Tip:** For most use cases, `GenericAtom<Value>` is all you need. You only need to implement `AtomObject` yourself if you require custom behavior.

### 3. Scope the root in your view hierarchy

Place an `AtomScope` at the root of your view hierarchy (or use the `.atomScope()` modifier). Atoms are resolved from the nearest scope in the environment:

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            AtomScope(root: AtomObjects()) {
                HomeView()
            }
        }
    }
}
```

Or equivalently with the view modifier:

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
                .atomScope(root: AtomObjects())
        }
    }
}
```

Scopes can be nested — a child scope shadows the parent for any atoms it defines.

## Usage

### Reading and writing atoms

Use `@AtomState` to bind an atom to a view. The view automatically refreshes when the atom's value changes:

```swift
struct HomeView: View {
    @AtomState(\.isEditing)
    var isEditing

    var body: some View {
        Button("Edit") {
            isEditing.toggle()
        }
        .popover(isPresented: $isEditing) {
            EditorView()
        }
    }
}
```

### Custom value setters

You can provide a custom setter for in-place mutations:

```swift
@AtomState(
    \.counter,
    set: { newValue, atom in
        atom.value = newValue < atom.value ? newValue - 1 : newValue + 1
    }
)
var counter
```

## Actions

For recurring logic that mutates atoms, define an `AtomObjectsAction`. Actions are async and receive the root as a parameter:

```swift
extension AtomObjects {
    struct IncrementCounter: AtomObjectsAction {
        var value: Int

        init(by value: Int) {
            self.value = value
        }

        func perform(with root: AtomObjects) async throws {
            @AtomValue(\.counter, in: root) var counter
            counter += value
        }
    }
}
```

Use `@AtomAction` in a view to invoke the action:

```swift
struct CounterView: View {
    @AtomState(\.counter)
    var counter

    @AtomAction(IncrementCounter(by: 1))
    var increment

    var body: some View {
        Button("Increment: \(counter)") {
            increment()
        }
    }
}
```

If an action takes no init parameters, conform it to `DefaultInitializableAction`
and pass the metatype instead of an instance:

```swift
struct ResetCounter: AtomObjectsAction, DefaultInitializableAction {
    func perform(with root: AtomObjects) async throws {
        @AtomValue(\.counter, in: root) var counter
        counter = 0
    }
}

struct ResetView: View {
    @AtomAction(ResetCounter.self)
    var reset
}
```

The projected value `$action` returns an async throwing closure, so you can await it
and handle errors explicitly:

```swift
@State private var actionError: String?

Button("Increment") {
    Task {
        do {
            try await $increment()
            actionError = nil  // Clear any previous error
        } catch {
            actionError = error.localizedDescription
        }
    }
}
```

> **Note:** The fire-and-forget `wrappedValue` (`action()`) logs errors via `os.Logger`
> and raises `assertionFailure` in debug builds. Use the projected value (`$action()`)
> when you need explicit error handling or to `await` completion.

### Actions with input and output

When a command needs an argument at call time, or needs to return a value, use
`ParameterizedAtomObjectsAction` with `@AtomInputAction`.

```swift
struct SavePreset: ParameterizedAtomObjectsAction, DefaultInitializableAction {
    func perform(with root: AtomObjects, input: String) async throws -> String {
        @AtomValue(\.name, in: root) var name
        name = input
        return input
    }
}

struct EditorView: View {
    @AtomInputAction(SavePreset.self)
    var save

    var body: some View {
        Button("Save") {
            Task {
                let stored = try await $save("draft")
            }
        }
    }
}
```

Because `SavePreset` takes no init parameters, it conforms to
`DefaultInitializableAction` and can be passed as the metatype
`SavePreset.self` instead of `SavePreset()` — actions with init parameters
keep using the instance form.

If `$save` runs with no root in the environment, a Void-output action does
nothing. A non-Void output throws `AtomObjectsActionError.missingRoot`.

## Nested Roots

You can nest `AtomRoot` instances for modular state. Define a key conforming to `AtomRootKey` and register it on the parent:

```swift
struct SettingsRootKey: AtomRootKey {
    static var defaultRoot: SettingsRoot { SettingsRoot() }
}

extension AtomObjects {
    var settings: SettingsRoot {
        get { self[SettingsRootKey.self] }
        set { self[SettingsRootKey.self] = newValue }
    }
}
```

## Architecture

- **`@Observable` macro** on `AtomRoot` — handles all change tracking
- **`@State` in `AtomScope`** — works seamlessly with `@Observable` types
- **Environment injection** — custom `EnvironmentValues` key (`\.atomRoot`)
- **No Combine, no `ObservableObject`, no `@Published`**
- **Swift 6 strict concurrency** — all atoms are `Sendable`

## License

MIT — see [LICENSE](LICENSE) for details.
