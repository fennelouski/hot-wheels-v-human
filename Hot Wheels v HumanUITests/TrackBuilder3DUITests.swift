//
//  TrackBuilder3DUITests.swift
//  Hot Wheels v HumanUITests
//
//  Drives the 3D builder (`--trackbuilder` deep link): appends pieces
//  from the palette, toggles the mini-map between corner- and
//  reading-size. Screenshots attach at each step for visual review.
//

import XCTest

final class TrackBuilder3DUITests: XCTestCase {

    @MainActor
    func testBuildAndMiniMap() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--trackbuilder"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Track Builder"].waitForExistence(timeout: 10))
        snap(app, "1-fresh-builder")

        // Build: straight, loop, straight, right — 5 pieces with the gate.
        for piece in ["Straight", "Loop", "Straight", "Right"] {
            app.buttons.containing(NSPredicate(format: "label CONTAINS %@", piece))
                .firstMatch.tap()
        }
        XCTAssertTrue(app.staticTexts["5 pieces"].waitForExistence(timeout: 5))
        // Let the async spawn land before the shot.
        sleep(2)
        snap(app, "2-five-pieces-3d")

        // Mini-map: tap → reading-size, tap → corner-size.
        let map = app.buttons["miniMap"]
        XCTAssertTrue(map.exists)
        map.tap()
        snap(app, "3-map-expanded")
        map.tap()
        snap(app, "4-map-corner")

        // Orbit: drag across the 3D canvas → camera angle changes.
        let mid = app.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.35))
        mid.press(forDuration: 0.05,
                  thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.45)))
        snap(app, "5-orbited")

        // Zoom: pinch out → camera moves closer.
        app.pinch(withScale: 2.0, velocity: 2.0)
        snap(app, "6-zoomed-in")
    }

    @MainActor
    private func snap(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
