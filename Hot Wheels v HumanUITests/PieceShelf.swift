//
//  PieceShelf.swift
//  Hot Wheels v HumanUITests
//
//  Tapping a piece card in the Track Builder, from any UI test.
//
//  The shelf is a horizontal ScrollView and the hill cards sit off the
//  right-hand end of it on an iPad in portrait. Two things bite anyone
//  who taps one without thinking, and both are handled here so no test
//  has to rediscover them:
//
//  1. Tapping a card whose frame is off-screen fails with "Activation
//     point invalid and no suggested hit points based on element frame".
//  2. So does ASKING one whether it `isHittable` — the query itself
//     throws, so the check that decides whether to scroll can't use it.
//     Compare frames against the window instead.
//

import XCTest

extension XCTestCase {

    /// Every card on the piece shelf, in the order they're laid out
    /// (`PiecePaletteView.cards`, with the sticky Ghost toggle leading).
    static let pieceShelf = ["Ghost", "Straight", "Left", "Right", "Sweeper",
                             "Loop", "Bump", "Hill Up", "Hill Down", "Jump",
                             "Finish", "Portal"]

    /// Scrolls the piece shelf into view and taps the card whose label
    /// contains `label`.
    @MainActor
    func tapPieceCard(_ label: String, in app: XCUIApplication,
                      file: StaticString = #filePath, line: UInt = #line) {
        let card = app.buttons.containing(
            NSPredicate(format: "label CONTAINS %@", label)).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 15),
                      "no '\(label)' card on the shelf", file: file, line: line)
        let window = app.windows.firstMatch
        for _ in 0..<10 {
            let frame = card.frame
            if window.frame.insetBy(dx: 4, dy: 0).contains(frame) {
                card.tap()
                return
            }
            // Off the right-hand end scrolls left, off the left end right.
            guard scrollPieceShelf(app, left: frame.midX > window.frame.midX)
            else { break }
        }
        XCTFail("'\(label)' never scrolled into view", file: file, line: line)
    }

    /// Drags the shelf by swiping ON one of its own cards. A swipe that
    /// starts on a shelf button stays inside the ScrollView; a raw
    /// window-coordinate drag lands on the 3D view behind it and orbits
    /// the camera instead. Returns false when no card is on screen to
    /// grab, which means the shelf isn't up.
    @MainActor
    func scrollPieceShelf(_ app: XCUIApplication, left: Bool) -> Bool {
        let window = app.windows.firstMatch.frame
        for label in Self.pieceShelf {
            let card = app.buttons.containing(
                NSPredicate(format: "label CONTAINS %@", label)).firstMatch
            guard card.exists, window.insetBy(dx: 4, dy: 0).contains(card.frame)
            else { continue }
            if left { card.swipeLeft() } else { card.swipeRight() }
            return true
        }
        return false
    }
}
