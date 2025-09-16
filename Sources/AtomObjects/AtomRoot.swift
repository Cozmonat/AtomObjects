/*
 
AtomObjects
 
Copyright (c) 2023 Natan Zalkin

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
 
*/


import Foundation
import Combine

public struct AtomStorage {
    
    private var storage = [ObjectIdentifier: AnyObject]()

    public subscript<Key, Atom>(key: Key.Type) -> Atom? where Key: AtomObjectKey, Atom: AtomObject, Atom.Value == Key.Value {
        get { storage[ObjectIdentifier(Key.self)] as? Atom }
        set { storage[ObjectIdentifier(Key.self)] = newValue }
    }
    
    public init() {}
}

public struct RootStorage {
    
    private var storage = [ObjectIdentifier: any AtomRoot]()

    public subscript<Key>(key: Key.Type) -> Key.Root? where Key: AtomRootKey {
        get { storage[ObjectIdentifier(Key.self)] as? Key.Root }
        set { storage[ObjectIdentifier(Key.self)] = newValue }
    }
    
    public init() {}
}

public protocol AtomRoot: ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {
    
    var parent: (any AtomRoot)? { get set }
    
    var atoms: AtomStorage { get set }
    var roots: RootStorage { get set }
    
    var version: AnyHashable { get set }
    
    func dispatch<Action>(_ action: Action) where Action: AtomObjectsAction, Action.Root == Self
    func dispatch<Action>(_ action: Action) async where Action: AtomObjectsAction, Action.Root == Self
}

public extension AtomRoot {
    
    subscript<Key, Atom>(key: Key.Type) -> Atom where Key: AtomObjectKey, Atom: AtomObject, Atom.Value == Key.Value {
        get {
            if let atom: Atom = atoms[Key.self] {
                return atom
            } else {
                let atom = Atom(value: Key.defaultValue)
                atoms[Key.self] = atom
                return atom
            }
        }
        set {
            upgrade()
            atoms[Key.self] = newValue
        }
    }
    
    subscript<Key>(key: Key.Type) -> Key.Root where Key: AtomRootKey {
        get {
            if let root = roots[Key.self] {
                return root
            } else {
                let root = Key.defaultRoot
                roots[Key.self] = root
                root.parent = self
                return root
            }
        }
        set {
            upgrade()
            roots[Key.self] = newValue
            newValue.parent = self
        }
    }
    
    func upgrade() {
        objectWillChange.send()
        version = UUID()
        parent?.upgrade()
    }
    
    func dispatch<Action>(_ action: Action) where Action: AtomObjectsAction, Action.Root == Self {
        Task {
            await action.perform(with: self)
        }
    }
    
    func dispatch<Action>(_ action: Action) async where Action: AtomObjectsAction, Action.Root == Self {
        await action.perform(with: self)
    }
}
