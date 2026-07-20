//
//  GarageUITests.swift
//  Hot Wheels v HumanUITests
//
//  Drives the garage hub (`--garage` deep link): a starter card opens the
//  car's own page, and that page carries the preview plus every action.
//  Guards the layout as much as the wiring — CarDetailView is a plain
//  VStack (a ScrollView would fight the turntable's drag-to-orbit), so
//  "the buttons fell off the bottom" is a real way for it to break.
//

import XCTest

final class GarageUITests: XCTestCase {

    @MainActor
    func testStarterCarOpensItsOwnPageWithEveryAction() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--garage"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Starter Cars"].waitForExistence(timeout: 10))
        // The body shop is what makes the bundled-but-unreachable car models
        // reachable; if the section vanishes, so do 15 cars.
        XCTAssertTrue(app.staticTexts["Body Shop"].exists)
        snap(app, "1-garage-grid")

        app.buttons.containing(NSPredicate(format: "label CONTAINS 'Fire Chief'"))
            .firstMatch.tap()

        // The car's own page: name, then every action a kid can take on it.
        XCTAssertTrue(app.staticTexts["Fire Chief"].waitForExistence(timeout: 10))
        for action in ["RACE THIS ONE!", "Remix It", "Test Drive", "Make a Copy"] {
            let button = app.buttons
                .containing(NSPredicate(format: "label CONTAINS %@", action)).firstMatch
            XCTAssertTrue(button.exists, "\(action) is missing")
            XCTAssertTrue(button.isHittable, "\(action) is off-screen or covered")
        }
        // Starters can't be scrapped — the built-ins stay pristine.
        XCTAssertFalse(app.buttons
            .containing(NSPredicate(format: "label CONTAINS 'Scrap It'")).firstMatch.exists)
        snap(app, "2-car-detail")

        // Racing it selects it and drops back to the grid, badged.
        app.buttons.containing(NSPredicate(format: "label CONTAINS 'RACE THIS ONE!'"))
            .firstMatch.tap()
        XCTAssertTrue(app.staticTexts["RACING NEXT"].waitForExistence(timeout: 10))
        snap(app, "3-back-in-garage-selected")
    }

    @MainActor
    private func snap(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
