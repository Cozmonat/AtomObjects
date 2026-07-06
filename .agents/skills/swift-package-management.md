# Swift Package Management Skill

## Overview
Specialized skill for managing Swift Package Manager in the AtomObjects project.

## Package Structure
```
AtomObjects/
├── Package.swift              # Package definition
├── Sources/AtomObjects/       # Library source
├── Tests/AtomObjectsTests/    # Unit tests
└── TestApp/                   # Xcode project (separate from SPM)
```

## Build Commands
- `swift build` - Build library only
- `swift test` - Run unit tests
- TestApp requires Xcode (`TestApp/TestApp.xcodeproj`)

## Package.swift Best Practices
- Use `swift-tools-version: 6.2`
- Set appropriate platform minimums (iOS 17+, macOS 14+, etc.)
- Use `swiftLanguageModes: [.v6]` for Swift 6 features
- Keep dependencies minimal

## Dependency Management
- Use SPM for external dependencies
- Pin versions for stability
- Test with dependency updates

## Testing
- Use Quick/Nimble for unit tests
- Test in isolation from TestApp
- Verify package exports

## Common Issues
- TestApp not compiling with `swift build` (expected - use Xcode)
- Dependency resolution conflicts
- Platform compatibility issues
