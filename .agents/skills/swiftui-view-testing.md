# SwiftUI View Testing Skill

## Overview
Specialized skill for testing SwiftUI views in the AtomObjects project.

## Testing Strategies

### Preview Testing
- Use `PreviewProvider` for visual testing
- Test with different size classes and orientations
- Verify view hierarchy and accessibility identifiers

### Snapshot Testing
- Use iOS simulator for screenshot comparisons
- Test different states of views
- Compare against baseline images

### Accessibility Testing
- Verify all interactive elements have accessibility identifiers
- Test VoiceOver compatibility
- Ensure proper accessibility labels

## Test Structure
```swift
struct MyView_Previews: PreviewProvider {
    static var previews: some View {
        AtomScope(root: AtomObjects()) {
            MyView()
        }
    }
}
```

## Best Practices
- Use `AtomScope` to provide root context in previews
- Test with mock atom values
- Verify view updates when atom values change
- Test both light and dark modes
