# AtomObjects — Agent Instructions

## Project Structure

```
AtomObjects/
├── Package.swift              # Swift Package (library + tests)
├── Sources/AtomObjects/       # Library source
├── Tests/AtomObjectsTests/    # Unit tests (Swift Testing)
├── TestApp/                   # Xcode project — separate from SPM
│   ├── TestApp.xcodeproj/
│   ├── TestApp/               # SwiftUI app that exercises the library
│   └── TestAppUITests/
└── README.md
```

## Build Commands

| Target | Command |
|--------|---------|
| Library | `swift build` |
| Tests | `swift test` |
| TestApp | **Open `TestApp/TestApp.xcodeproj` in Xcode and build/run** |

## Important

- **TestApp is a separate Xcode project**, NOT part of the Swift Package. It depends on the AtomObjects SPM package locally.
- `swift build` only compiles the library. It does **not** compile TestApp.
- To validate TestApp changes, build the TestApp target in Xcode.

## Architecture

- `@Observable` macro on `AtomRoot` class
- `@Environment(\.atomRoot)` for injection (custom `EnvironmentValues` key)
- `@State` in `AtomScope` (works with `@Observable` types)
- No Combine, no `ObservableObject`, no `@Published`
- Swift 6.2, Swift mode v6

## Testing

- Uses Swift Testing (`@Suite`, `@Test`, `#expect`)
- `swift-testing` package dependency is **required** (built-in Testing has `_TestingInternals` issue on current toolchain)
- Do not remove the `swift-testing` dependency — it's needed for tests to compile

## Platform Requirements

- iOS 17+, macOS 14+, watchOS 10+, tvOS 17+
