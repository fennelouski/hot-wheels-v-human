//
//  RaceSetupUITests.swift
//  Hot Wheels v HumanUITests
//
//  Drives the Race-on-TV setup screen (`--race-on-tv` deep link): car
//  pick, track draft badges, the series cap, and the GO handoff to the
//  dashboard. Track cards are matched by their "N pieces" subtitle so
//  the test survives starter-roster changes. Screenshots attach at
//  each step for visual review.
//

import XCTest

final class RaceSetupUITests: XCTestCase {

    @MainActor
    func testTrackDraftFlow() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--race-on-tv"]
        app.launch()

        // Setup screen is up.
        XCTAssertTrue(app.staticTexts
            .containing(NSPredicate(format: "label CONTAINS 'Pick your car'"))
            .firstMatch.waitForExistence(timeout: 10))
        snap(app, "1-setup-screen")

        // Pick a car → selection is visual; verify the card is tappable.
        app.buttons.containing(NSPredicate(format: "label CONTAINS 'Banana Bolt'"))
            .firstMatch.tap()

        // Every track card's label ends in "N pieces".
        let tracks = app.buttons.containing(NSPredicate(format: "label CONTAINS 'pieces'"))
        XCTAssertTrue(tracks.firstMatch.exists)

        // Draft three tracks in order.
        tracks.element(boundBy: 0).tap()
        tracks.element(boundBy: 1).tap()
        tracks.element(boundBy: 2).tap()
        XCTAssertTrue(goButton(app, "RACE 3 TRACKS!").exists)
        snap(app, "2-three-picks")

        // Un-pick the #2 track → later picks shift up, button says 2.
        tracks.element(boundBy: 1).tap()
        XCTAssertTrue(goButton(app, "RACE 2 TRACKS!").exists)

        // Draft past the cap: only 5 stick (roster has ≥6 starters).
        tracks.element(boundBy: 1).tap()
        tracks.element(boundBy: 3).tap()
        tracks.element(boundBy: 4).tap()
        tracks.element(boundBy: 5).tap()
        XCTAssertTrue(goButton(app, "RACE 5 TRACKS!").exists)
        snap(app, "3-capped-at-five")

        // GO → the dashboard takes over and starts browsing for the TV.
        goButton(app, "RACE 5 TRACKS!").tap()
        XCTAssertTrue(app.staticTexts["Looking for the arena…"]
            .waitForExistence(timeout: 10))
        snap(app, "4-dashboard-browsing")
    }

    @MainActor
    private func goButton(_ app: XCUIApplication, _ text: String) -> XCUIElement {
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
