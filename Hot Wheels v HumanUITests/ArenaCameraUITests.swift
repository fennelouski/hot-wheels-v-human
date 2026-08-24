//
//  ArenaCameraUITests.swift
//  Hot Wheels v HumanUITests
//
//  The arena's camera toggle: races start in Driver View (the kid asked
//  to ride in the car), one tap swaps to the chase camera and back.
//  Screenshots attach so the framing can be eyeballed too.
//

import XCTest

final class ArenaCameraUITests: XCTestCase {

    @MainActor
    func testDriverViewTogglesToChaseCam() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--hill-track"]
        app.launch()

        // Default is Driver View — the button names the view you're in.
        let driver = button(app, "Driver View")
        XCTAssertTrue(driver.waitForExistence(timeout: 20))
        snap(app, "1-driver-view")

        driver.tap()
        let chase = button(app, "Chase Cam")
        XCTAssertTrue(chase.waitForExistence(timeout: 5))
        snap(app, "2-chase-cam")

        chase.tap()
        XCTAssertTrue(button(app, "Driver View").waitForExistence(timeout: 5))
    }

    @MainActor
    private func button(_ app: XCUIApplication, _ text: String) -> XCUIElement {
        app.buttons.containing(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    @MainActor
    private func snap(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

/// The dashboard radio that rides along with Driver View.
final class ArenaRadioUITests: XCTestCase {

    @MainActor
    func testRadioPresetsTuneTheDashboard() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--hill-track"]
        app.launch()

        // Races start in Driver View, so the dash is up with them.
        let rock = app.buttons.containing(NSPredicate(format: "label CONTAINS 'ROCK'")).firstMatch
        XCTAssertTrue(rock.waitForExistence(timeout: 20))
        for preset in ["JAZZ", "POP", "FUNK", "SMOOTH", "8-BIT"] {
            XCTAssertTrue(app.buttons.containing(
                NSPredicate(format: "label CONTAINS %@", preset)).firstMatch.exists,
                          "\(preset) preset missing from the dashboard")
        }

        rock.tap()
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "radio-rock-tuned"
        shot.lifetime = .keepAlways
        add(shot)

        // The power key kills the radio and says so in the display window.
        let power = app.buttons["Radio on"]
        XCTAssertTrue(power.exists)
        power.tap()
        XCTAssertTrue(app.staticTexts["OFF"].waitForExistence(timeout: 3))
        app.buttons["Radio off"].tap()
        XCTAssertFalse(app.staticTexts["OFF"].exists)

        // Chase cam stows the dash — there's no cockpit to bolt it to.
        app.buttons.containing(NSPredicate(format: "label CONTAINS 'Driver View'"))
            .firstMatch.tap()
        XCTAssertTrue(app.buttons.containing(NSPredicate(format: "label CONTAINS 'Chase Cam'"))
            .firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons.containing(NSPredicate(format: "label CONTAINS 'FUNK'"))
            .firstMatch.exists)
    }
}
