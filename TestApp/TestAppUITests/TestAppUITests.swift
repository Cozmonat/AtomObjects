//
//  Created by Natan Zalkin on 12/01/2023.
//  Copyright © 2023 Natan Zalkin. All rights reserved.
//
    

import XCTest

final class TestAppUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testAtoms() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["Counter: 0"].waitForExistence(timeout: 10))
        var button = app.buttons.element(boundBy: 1)
        XCTAssertTrue(button.waitForExistence(timeout: 1))
        button.tap()
        XCTAssertTrue(app.staticTexts["Counter: 1"].waitForExistence(timeout: 1))
        let slider = app.sliders.element(boundBy: 0)
        slider.adjust(toNormalizedSliderPosition: 0.2)
        XCTAssertTrue(app.staticTexts["Counter: 2"].waitForExistence(timeout: 1))
        button = app.buttons.element(boundBy: 0)
        button.tap()
        XCTAssertTrue(app.staticTexts["Counter: 1"].waitForExistence(timeout: 1))

        XCTAssertTrue(app.staticTexts["Secondary counter: 0"].waitForExistence(timeout: 1))
        var scopedButton = app.buttons.element(boundBy: 3)
        XCTAssertTrue(scopedButton.waitForExistence(timeout: 10))
        scopedButton.tap()
        XCTAssertTrue(app.staticTexts["Secondary counter: 1"].waitForExistence(timeout: 1))
        let scopedSlider = app.sliders.element(boundBy: 1)
        scopedSlider.adjust(toNormalizedSliderPosition: 0.2)
        XCTAssertTrue(app.staticTexts["Secondary counter: 2"].waitForExistence(timeout: 1))
        scopedButton = app.buttons.element(boundBy: 2)
        scopedButton.tap()
        XCTAssertTrue(app.staticTexts["Secondary counter: 1"].waitForExistence(timeout: 1))
        
        XCTAssertTrue(app.staticTexts["Tertiary counter: 0"].waitForExistence(timeout: 1))
        var tertiaryButton = app.buttons.element(boundBy: 5)
        XCTAssertTrue(tertiaryButton.waitForExistence(timeout: 1))
        tertiaryButton.tap()
        XCTAssertTrue(app.staticTexts["Tertiary counter: 2"].waitForExistence(timeout: 1))
        let resetButton = app.buttons.element(boundBy: 6)
        XCTAssertTrue(resetButton.waitForExistence(timeout: 1))
        resetButton.tap()
        XCTAssertTrue(app.staticTexts["Tertiary counter: 5"].waitForExistence(timeout: 1))
        tertiaryButton = app.buttons.element(boundBy: 4)
        tertiaryButton.tap()
        XCTAssertTrue(app.staticTexts["Tertiary counter: 3"].waitForExistence(timeout: 1))
    }
}
