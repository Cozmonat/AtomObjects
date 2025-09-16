# AtomObjects for SwiftUI

[![License](https://img.shields.io/badge/license-MIT-ff69b4.svg)](https://github.com/kzlekk/AtomObjects/raw/master/LICENSE)
![Language](https://img.shields.io/badge/swift-5.7-orange.svg)
![Coverage](https://img.shields.io/badge/coverage-78%25-green)

AtomObjects is a lightweight state management library for SwiftUI. It allows building reusable shared and scoped 
states for SwiftUI applications with minimum boilerplate code.

The current version of the library is considered stable and production ready. There is no intention to make changes
to the API other than bug fixes.

## Motivation

The main idea of AtomObject is to use small "decentralized" atom state primitives instead of a centralized store or 
data model.  Atom objects easily allow pinpoint refreshes of SwiftUI views instead of trying to think out an 
efficient update strategy for bigger data models. Although it is not encouraged, you can implement complex state value 
provided by a single AtomObject if you'll wish so.

## Installation

### Swift Package Manager

Add "AtomObjects" dependency via integrated Swift Package Manager in XCode

## Setup

In the first step you need to implement an atom class conforming to the AtomObject protocol. This will be your shared 
object with the state value:

```swift
// Instead of implementing AtomObject protocol by yourself, you can just use GenericAtom class with the similar basic
// implementation as below:
class EditingAtom: AtomObject {
    
    // Published property wrapper is needed allowing to trigger value updates.
    // You can trigger an update manually by calling objectWillChange.send() where appropriate.
    @Published var value: Bool
    
    required init() {
        value = false
    }
}
```

The next step is registering unique key associated with the default atom value:

```swift
struct EditingAtomKey: AtomObjectKey {

    static let defaultValue = false
}
```

At last you need to implement AtomRoot protocol or subclass/extend AtomObjects class and register your atom in the 
container. Atom object key is intended to be used as the identifier of an atom path inside root container:

```swift
extension AtomObjects {
     
    var isEditing: EditingAtom {
        get { return self[EditingAtomKey.self] }
        set { self[EditingAtomKey.self] = newValue }
    }
```

Implementation option using GenericAtom:

```swift
extension AtomObjects {    
     
    var isEditing: GenericAtom<Bool> {
        get { return self[EditingAtomKey.self] }
        set { self[EditingAtomKey.self] = newValue }
    }
}
```

## Usage

Put atom root scope outside of the state consuming view. Atoms will be resolved in the root container provided by 
the nearest scope. Scopes can be nested and injected in any view. That way you can reuse business logic associated with 
the specific atom root in the different places in your app.

```swift
@main
struct TheApp: App {
    var body: some Scene {
        WindowGroup {
            AtomScope(root: AtomObjects()) {
                HomeView()
            }
        }
    }
}
```

You can also use view modifier on view to set new atom root. The result will be the same as wraping view with AtomScope:

```swift
@main
struct TheApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
                .atomScope(root: AtomObjects())
        }
    }
}
```

After that, you can use @AtomState wrapper to get access to atom value in your SwiftUI view. All the views in the scope 
that use AtomState will automatically refresh when the atom is changed:

```swift
struct HomeView: View {
    
    @AtomState(\AtomObjects.isEditing)
    var isEditing

    var body: some View {
        Button {
            isEditing.toggle()
        } label: {
            Text("Edit")
        }
        .popover(isPresented: $isEditing) {
            EditorView()
        }
    }
}
```

## Actions

If you have recurring logic applied to the atoms inside a specific root, you can wrap it inside the AtomObjectsAction 
object and reuse it in the app. 

For example, we have a simple counter atom:

```swift
    struct CounterAtomKey: AtomObjectKey {
        static var defaultValue: Int = 0
    }
    
    class AtomObjects: AtomRoot {
        var counter: AtomObject<Int> {
            get { return self[CounterAtomKey.self] }
            set { self[CounterAtomKey.self] = newValue }
        }
    }
```

What if you want to reuse configurable increment action in various views? It is possible by imlementing the action as in
the code example below. The action in the example have a configurable increment value. 

```swift
    struct IncrementCounter: AtomObjectsAction {
        
        var value: Int
        
        init(by value: Int) {
            self.value = value
        }
        
        func perform(with root: AtomObjects) async {
            
            // Convenience wrapper allowing to access atom value via local variable
            @AtomValue(root.counter) var counter; 
            
            counter += value
        }
    }
```

The action from the example above can be stored and cashed inside consuming view, and called then needed:

```swift
    struct CounterView: View {
        
        @AtomState(\AtomObjects.counter)
        var counter
    
        @AtomAction(AtomObjects.IncrementCounter(by: 1))
        var increment
    
        var body: some View {
        
            Button {
                increment()
            } label: {
                Text("Increment counter: \(counter)")
            }
        }
    } 
```

Any AtomObjectsAction execution can be awaited by accessing its projectedValue:

```swift
    struct CounterView: View {
        
        @AtomState(\AtomObjects.counter)
        var counter
    
        @AtomAction(AtomObjects.IncrementCounter(by: 1))
        var increment
    
        var body: some View {
        
            Button {
                Task {
                    await $increment()
                    // You do additional stuff here after the action finished
                }
            } label: {
                Text("Increment counter: \(counter)")
            }
        }
    } 
```

If you need to configure the action upon execution, it can be done by directly dispatching action from atom root:

```swift

    struct CounterView: View {
        
        @AtomState(\AtomObjects.counter)
        var counter
    
        @EnvironmentObject
        var root: AtomObjects
    
        var body: some View {
        
            HStack {
                Button {
                    root.dispatch(IncrementCounter(by: count * 2))
                } label: {
                    Text("Increment")
                }
                .buttonStyle(.borderedProminent)
                            
                Text("Counter: \(counter)")
                
                Button {
                    // It is possible to use action execution method notation
                    DecrementCounter(by: count * 2).perform(with: root)
                } label: {
                    Text("Decrement")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }     
```

