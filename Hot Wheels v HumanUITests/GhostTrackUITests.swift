//
//  GhostTrackUITests.swift
//  Hot Wheels v HumanUITests
//
//  Ghost tracks end to end: the builder's sticky Ghost mode (palette card,
//  translucent pieces in the 3D scene, dashed footprints on the mini-map)
//  and the arena's icon-only three-way track switch under the camera
//  toggle. Screenshots attach at each step for visual review.
//

import XCTest

final class GhostTrackUITests: XCTestCase {

    @MainActor
    func testGhostPiecesInTheBuilder() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--trackbuilder"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Track Builder"].waitForExistence(timeout: 10))

        // Two solid pieces, then Ghost on and two more — the difference has
        // to be visible in the same shot.
        for piece in ["Straight", "Right"] { tapPiece(app, piece) }
        let ghost = app.buttons["ghostToggle"]
        XCTAssertTrue(ghost.exists)
        ghost.tap()
        snap(app, "1-ghost-mode-on")

        for piece in ["Straight", "Straight"] { tapPiece(app, piece) }
        XCTAssertTrue(app.staticTexts["5 pieces"].waitForExistence(timeout: 20))
        sleep(2)                                   // async respawn
        snap(app, "2-two-ghost-pieces")

        // Back to solid, one more piece: ghost mode is sticky, not one-shot.
        ghost.tap()
        tapPiece(app, "Left")
        sleep(2)
        snap(app, "3-solid-again")

        app.buttons["miniMap"].tap()
        snap(app, "4-map-ghosts-dashed")
    }

    /// Tap a piece already on the track to flip it — the thing ghost mode
    /// can't do. The camera auto-fits and aims at the footprint centre, so
    /// on a straight run the middle of the canvas IS a piece.
    @MainActor
    func testTapAPlacedPieceToFlipIt() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--trackbuilder"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Track Builder"].waitForExistence(timeout: 10))
        for _ in 0..<3 { tapPiece(app, "Straight") }
        XCTAssertTrue(app.staticTexts["4 pieces"].waitForExistence(timeout: 20))
        sleep(2)
        snap(app, "9-all-solid")

        // Middle of the 3D canvas → a piece. Tap ghosts it, tap again undoes.
        let piece = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.42))
        piece.tap()
        sleep(2)
        snap(app, "10-tapped-piece-now-ghost")
        piece.tap()
        sleep(2)
        snap(app, "11-tapped-again-solid")
    }

    @MainActor
    func testArenaTrackSwitch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--solo-arena"]
        app.launch()

        // Let the world build and the countdown run out.
        sleep(12)
        snap(app, "5-arena-default-hide-ghosts")

        let showAll = app.buttons["Show all track"]
        XCTAssertTrue(showAll.waitForExistence(timeout: 10))
        showAll.tap()
        sleep(1)
        snap(app, "6-show-all-track")

        app.buttons["Hide all track"].tap()
        sleep(1)
        snap(app, "7-hide-all-track")

        app.buttons["Hide ghost track"].tap()
        sleep(1)
        snap(app, "8-back-to-default")
    }

    /// Wait for the chip, then tap it. `firstMatch` resolves in the same run
    /// loop, so under a parallel suite a palette that is still arriving eats
    /// the tap and the piece count never reaches the number asserted below.
    @MainActor
    private func tapPiece(_ app: XCUIApplication, _ piece: String) {
        let chip = app.buttons
            .containing(NSPredicate(format: "label CONTAINS %@", piece)).firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "No \(piece) in the palette")
        chip.tap()
    }

    @MainActor
    private func snap(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
