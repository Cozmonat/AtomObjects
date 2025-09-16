//
//  Created by Natan Zalkin on 12/01/2023.
//  Copyright © 2023 Natan Zalkin. All rights reserved.
//
    

import SwiftUI
import AtomObjects

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
            
            QuaternaryView()
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
    
    var body: some View {
        HStack {
            Button {
                Task {
                    await $decrement()
                }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title)
            }
            
            Slider(value: $counter, in: 0...10) {
                isEditing = $0
            }
            
            Button {
                increment()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title)
            }
        }
    }
}

struct SecondaryView: View {
    
    @AtomState(\AtomObjects.counter)
    var counter
    
    var body: some View {
        VStack {
            Text("Secondary counter: \(Int(counter))")
            Controls()
        }
    }
}

struct TertiaryView: View {
    
    @AtomState(\AtomObjects.counter, set: { newValue, atom in
        atom.value = newValue < atom.value ? newValue - 1 : newValue + 1
    })
    var counter
    
    @EnvironmentObject
    var root: AtomObjects
    
    var body: some View {
        VStack {
            HStack {
                Button {
                    counter -= 1
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title)
                }
                
                Spacer()
                
                Text("Tertiary counter: \(Int(counter))")
                
                Spacer()
                
                Button {
                    counter += 1
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                }
            }
            
            Button {
                root.counter = GenericAtom(value: 5)
            } label: {
                Text("Rewrite atom")
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("rewrite")
        }
        .padding(.vertical)
    }
}

struct QuaternaryView: View {
    
    @AtomState(\AtomObjects.counter)
    var counter
    
    @EnvironmentObject
    var dispatcher: AtomObjects
    
    var body: some View {
        VStack {
            HStack {
                Button {
                    dispatcher.dispatch(AtomObjects.DecrementCounter(by: counter == 0 ? 1 : abs(counter)))
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title)
                }
                
                Spacer()
                
                Text("Quaternary counter: \(Int(counter))")
                
                Spacer()
                
                Button {
                    AtomObjects.IncrementCounter(by: counter == 0 ? 1 : abs(counter)).perform(with: dispatcher)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                }
            }
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
