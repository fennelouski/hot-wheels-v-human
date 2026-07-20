//
//  PiPTunerTileUITests.swift
//  Hot Wheels v HumanUITests
//
//  Confirms the TEMPORARY "PiP Tuner (dev)" home tile exists and opens the
//  tuner. Delete this file with the tile (RootView's dev GridRow) once the
//  PiP framing numbers are settled.
//
//  Goes through the "Who's playing?" gate first — a fresh install has no
//  profile, and the dev deep links deliberately skip the home screen, so
//  this is the only route to the tile.
//

import XCTest

final class PiPTunerTileUITests: XCTestCase {

    @MainActor
    func testPiPTunerTileOpensTheTuner() throws {
        let app = XCUIApplication()
        app.launch()

        // Profile gate, if this install has no racer yet.
        let newRacer = app.buttons
            .containing(NSPredicate(format: "label CONTAINS 'New Racer'")).firstMatch
        if newRacer.waitForExistence(timeout: 10) {
            newRacer.tap()
            // Sheet: name is pre-filled by the dice, so just commit.
            let go = app.buttons
                .containing(NSPredicate(format: "label CONTAINS \"Let's go\"")).firstMatch
            XCTAssertTrue(go.waitForExistence(timeout: 5), "new-racer sheet never appeared")
            go.tap()
        }

        // Home screen.
        XCTAssertTrue(app.staticTexts["iPad Workshop"].waitForExistence(timeout: 15),
                      "never reached the Workshop home screen")
        snap(app, "1-home-with-tile")

        let tile = app.buttons
            .containing(NSPredicate(format: "label CONTAINS 'PiP Tuner'")).firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 5),
                      "PiP Tuner (dev) tile is missing from the home grid")
        tile.tap()

        // Tuner: the slider labels are the proof it actually opened.
        XCTAssertTrue(app.staticTexts["bustScale"].waitForExistence(timeout: 15),
                      "tuner opened but its sliders never appeared")
        XCTAssertTrue(app.staticTexts["wheelCenterY"].exists)
        XCTAssertTrue(app.sliders.firstMatch.exists, "no sliders in the tuner")
        snap(app, "2-tuner-open")
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
