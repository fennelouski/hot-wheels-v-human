//
//  TunnelUITests.swift
//  Hot Wheels v HumanUITests
//
//  Screenshot drill for the tunnel: build a track that dives under the
//  ground and climbs back out, and look at what you get — an arch at
//  each mouth and lamps strung down the buried run.
//
//  The piece shelf scrolls, and the hill cards sit off the right-hand
//  end of it, so `tapCard` drags the shelf until the card it wants is
//  actually hittable. (Tapping a card whose frame is off-screen fails
//  with "Activation point invalid", which is exactly what
//  UndergroundPortalUITests trips over.)
//

import XCTest

final class TunnelUITests: XCTestCase {

    /// Every card on the piece shelf, in the order they're laid out.
    private static let shelf = ["Ghost", "Straight", "Left", "Right", "Sweeper",
                                "Loop", "Bump", "Hill Up", "Hill Down", "Jump",
                                "Finish"]

    /// Drags the shelf by swiping ON one of its own cards — a swipe that
    /// starts on a shelf button stays inside the ScrollView, where a raw
    /// window-coordinate drag lands on the 3D view behind it and orbits
    /// the camera instead.
    @MainActor
    private func scrollShelf(_ app: XCUIApplication, left: Bool) -> Bool {
        let window = app.windows.firstMatch.frame
        for label in Self.shelf {
            let card = app.buttons.containing(
                NSPredicate(format: "label CONTAINS %@", label)).firstMatch
            guard card.exists, window.insetBy(dx: 4, dy: 0).contains(card.frame)
            else { continue }
            if left { card.swipeLeft() } else { card.swipeRight() }
            return true
        }
        return false
    }

    @MainActor
    private func tapCard(_ label: String, in app: XCUIApplication) {
        let card = app.buttons.containing(
            NSPredicate(format: "label CONTAINS %@", label)).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 15), "no '\(label)' card")
        // Frames, not `isHittable`: asking a card that is scrolled off the
        // end whether it's hittable THROWS ("Activation point invalid"),
        // so the check that decides whether to scroll can't use it.
        let window = app.windows.firstMatch
        for _ in 0..<10 {
            let frame = card.frame
            if window.frame.insetBy(dx: 4, dy: 0).contains(frame) {
                card.tap()
                return
            }
            // Off the right-hand end scrolls left, off the left end right.
            guard scrollShelf(app, left: frame.midX > window.frame.midX) else { break }
        }
        XCTFail("'\(label)' never scrolled into view")
    }

    /// Dive, run buried, climb back out — the shape the tunnel dressing
    /// is built for. Two hillDowns make it a two-level dig, so the dirt
    /// mounded over the buried run is deep enough to read as a hill.
    @MainActor
    func testTunnelHasAMouthAtEachEndAndLampsBetween() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--trackbuilder"]
        app.launch()

        tapCard("Straight", in: app)
        tapCard("Hill Down", in: app)
        tapCard("Hill Down", in: app)
        for _ in 0..<4 { tapCard("Straight", in: app) }
        tapCard("Hill Up", in: app)
        tapCard("Hill Up", in: app)
        tapCard("Straight", in: app)
        sleep(3)

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "tunnel-builder"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
