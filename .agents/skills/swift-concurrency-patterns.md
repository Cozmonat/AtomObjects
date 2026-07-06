# Swift Concurrency Patterns Skill

## Overview
Specialized skill for Swift 6.2 concurrency patterns in the AtomObjects project.

## Key Patterns

### @Observable
- Use on state classes that need to trigger view updates
- Tracks property changes automatically
- No need for @Published or ObservableObject

### @MainActor
- Use for UI-related code
- Ensures main thread execution
- Important for SwiftUI view updates

### Sendable
- Mark types as Sendable for cross-actor safety
- Use `@unchecked Sendable` only when type is truly thread-safe
- Generic constraints: `where Value: Sendable`

## Concurrency Best Practices
- Use `async/await` for asynchronous operations
- Prefer structured concurrency with `Task`
- Use `@MainActor` for UI updates
- Mark types as Sendable when possible

## Common Patterns
```swift
@Observable
class ViewModel: Sendable {
    var value: String = ""
}

@MainActor
func updateUI() async {
    // Safe UI updates
}
```

## Testing Concurrency
- Use `@Test` for async testing
- Test actor isolation
- Verify thread safety
