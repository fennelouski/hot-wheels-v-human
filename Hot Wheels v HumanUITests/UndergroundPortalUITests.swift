//
//  UndergroundPortalUITests.swift
//  Hot Wheels v HumanUITests
//
//  Screenshot drills for digging + portals: a track that goes
//  underground should show through a see-through ground in the builder,
//  and the Portal card should drop a ring pair with a tappable exit.
//

import XCTest

final class UndergroundPortalUITests: XCTestCase {

    @MainActor
    func testDiggingFadesTheGround() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--trackbuilder"]
        app.launch()

        // Pick a world so there's real terrain to see through.
        let chip = app.buttons["worldChip"]
        XCTAssertTrue(chip.waitForExistence(timeout: 10))
        chip.tap()
        let park = app.buttons.containing(
            NSPredicate(format: "label CONTAINS 'Park'")).firstMatch
        XCTAssertTrue(park.waitForExistence(timeout: 5))
        park.tap()
        chip.tap()
        sleep(3)

        // Dig: two hill-downs then some buried straights. The hill cards
        // are off the end of the shelf, so they need scrolling to — this
        // test used to tap them where they weren't and fail with
        // "Activation point invalid".
        tapPieceCard("Hill Down", in: app)
        tapPieceCard("Hill Down", in: app)
        for _ in 0..<3 { tapPieceCard("Straight", in: app) }
        sleep(2)

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "underground-builder"
        shot.lifetime = .keepAlways
        add(shot)
    }

    @MainActor
    func testPortalPairPlaces() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--trackbuilder"]
        app.launch()

        for _ in 0..<2 { tapPieceCard("Straight", in: app) }
        // The Portal card sits at the far end of the piece shelf; the
        // same scroll-then-tap gets there.
        tapPieceCard("Portal", in: app)
        sleep(1)

        let pending = XCTAttachment(screenshot: app.screenshot())
        pending.name = "portal-pending"
        pending.lifetime = .keepAlways
        add(pending)

        // Tap the 3D view to place the exit ring off to one side.
        let window = app.windows.firstMatch
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.35)).tap()
        sleep(2)

        let placed = XCTAttachment(screenshot: app.screenshot())
        placed.name = "portal-placed"
        placed.lifetime = .keepAlways
        add(placed)
    }
}
