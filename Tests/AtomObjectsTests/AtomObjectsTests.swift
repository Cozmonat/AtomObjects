import Quick
import Nimble
import Combine
import Foundation

@testable import AtomObjects

// Actual tests are implemented inside AtomObjects/TestApp

final class AtomObjectsTests: QuickSpec {
    override func spec() {
        
        describe("AtomObjects") {
            
            context("santiy test") {
                
                it("should compile") {
                    expect(42).to(equal(42))
                }
            }
        }
    }
}
