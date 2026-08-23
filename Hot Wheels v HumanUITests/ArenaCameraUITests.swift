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
