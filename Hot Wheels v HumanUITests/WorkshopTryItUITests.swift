//
//  WorkshopTryItUITests.swift
//  Hot Wheels v HumanUITests
//
//  The three workshops all promise the same thing: see the thing you just
//  made, without backing out. This drives that promise on each of them —
//  track builder, customizer, character editor — through the race cover
//  and back to the workbench with the build still there. Screenshots
//  attach at each step for visual review.
//

import XCTest

final class WorkshopTryItUITests: XCTestCase {

    /// Track builder: load a starter track, drive it, come back still holding it.
    @MainActor
    func testTrackBuilderRaceIt() throws {
        let app = launch("--trackbuilder")

        // Fresh canvas offers the starter tracks — take one so the build is
        // raceable (a lone start gate isn't, and the button stays disabled).
        let starter = app.buttons
            .containing(NSPredicate(format: "label CONTAINS 'Wiggle Worm'")).firstMatch
        XCTAssertTrue(starter.waitForExistence(timeout: 10))
        starter.tap()
        snap(app, "track-1-loaded")

        let raceIt = button(app, "Race it")
        XCTAssertTrue(raceIt.isEnabled, "A loaded starter track must be raceable")
        raceIt.tap()

        assertRaceIsRunning(app, named: "track-2-racing")
        closeCover(app)

        // Back on the workbench with the track intact — not a fresh canvas.
        XCTAssertTrue(button(app, "Race it").waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["1 piece"].exists, "The build should survive the race")
        snap(app, "track-3-back-on-workbench")
    }

    /// Customizer: repaint, test drive the unsaved car, come back to it.
    @MainActor
    func testCustomizerTestDrive() throws {
        let app = launch("--customizer")

        let testDrive = button(app, "Test Drive")
        XCTAssertTrue(testDrive.waitForExistence(timeout: 10))

        // Change the car first: the point is that the *unsaved* edit races.
        app.buttons.containing(NSPredicate(format: "label CONTAINS 'Muscle'")).firstMatch.tap()
        snap(app, "car-1-chassis-changed")

        testDrive.tap()
        assertRaceIsRunning(app, named: "car-2-racing")
        closeCover(app)

        XCTAssertTrue(button(app, "Test Drive").waitForExistence(timeout: 10))
        snap(app, "car-3-back-in-shop")
    }

    /// Character editor: the PiP rides along with the edits, and the racer
    /// can be driven without leaving the wardrobe.
    @MainActor
    func testCharacterEditorPiPAndTestDrive() throws {
        let app = launch("--character-editor")

        let testDrive = button(app, "Test Drive")
        XCTAssertTrue(testDrive.waitForExistence(timeout: 10))

        // The PiP bust streams in behind the editor; give it room to arrive so
        // the edit below is provably a *repaint*, not a first paint.
        settle(seconds: 12)
        snap(app, "racer-1-pip-loaded")

        // Restyle the hair on a bust that's already on screen — the PiP has to
        // follow, otherwise it's frozen on whoever it loaded with. Two very
        // different styles, because the editor picks a random starting racer
        // and one of them could have been a no-op. Visual evidence: compare
        // the PiP circle across racer-1 / -2 / -3.
        app.buttons.containing(NSPredicate(format: "label CONTAINS 'Hair'")).firstMatch.tap()
        app.buttons.containing(NSPredicate(format: "label CONTAINS 'Bald'")).firstMatch.tap()
        settle(seconds: 3)
        snap(app, "racer-2-pip-after-bald")

        // "Top Bun", not "Curly": 4406c57 lifted the hairstyles off the
        // roster's own heads and renamed them, and this tap has been failing
        // ever since. Any style with an actual mesh works — the point is that
        // the PiP changes again, from bald to something.
        app.buttons.containing(NSPredicate(format: "label CONTAINS 'Top Bun'")).firstMatch.tap()
        settle(seconds: 3)
        snap(app, "racer-3-pip-after-bun")

        testDrive.tap()
        assertRaceIsRunning(app, named: "racer-4-racing")
        closeCover(app)

        XCTAssertTrue(button(app, "Test Drive").waitForExistence(timeout: 10))
        snap(app, "racer-5-back-in-wardrobe")
    }

    // MARK: Helpers

    @MainActor
    private func launch(_ argument: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [argument]
        app.launch()
        return app
    }

    @MainActor
    private func button(_ app: XCUIApplication, _ text: String) -> XCUIElement {
        app.buttons.containing(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    /// The cover is up AND a real race is behind it: the mini-dashboard only
    /// draws its speedometer once snapshots are actually flowing from the
    /// coordinator, so "m/s" means the loopback rig came up, not just a sheet.
    @MainActor
    private func assertRaceIsRunning(_ app: XCUIApplication, named name: String) {
        XCTAssertTrue(app.staticTexts["m/s"].waitForExistence(timeout: 30),
                      "Race cover should present a live Solo Arena rig")
        snap(app, name)
    }

    @MainActor
    private func closeCover(_ app: XCUIApplication) {
        app.buttons["Close"].tap()
    }

    /// Let async asset loads land. Nothing to poll for — the bust is a
    /// RealityKit entity, invisible to XCUITest — so this waits on the clock.
    @MainActor
    private func settle(seconds: TimeInterval) {
        _ = XCTWaiter.wait(for: [expectation(description: "settle")], timeout: seconds)
    }

    @MainActor
    private func snap(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
