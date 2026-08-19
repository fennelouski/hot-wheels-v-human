//
//  WorldPickerUITests.swift
//  Hot Wheels v HumanUITests
//
//  Screenshot drill for the builder's world picker: build a short track,
//  open the world strip, visit a spread of worlds, capture evidence.
//

import XCTest

final class WorldPickerUITests: XCTestCase {

    @MainActor
    func testPickWorldsAndScreenshot() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--trackbuilder"]
        app.launch()

        // A little track so the worlds have something to surround.
        let straight = app.buttons.containing(
            NSPredicate(format: "label CONTAINS 'Straight'")).firstMatch
        XCTAssertTrue(straight.waitForExistence(timeout: 10))
        for _ in 0..<3 { straight.tap() }
        app.buttons.containing(NSPredicate(format: "label CONTAINS 'Left'"))
            .firstMatch.tap()

        let chip = app.buttons["worldChip"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        chip.tap()    // open the world strip

        for world in ["Big City", "Canyon", "Space"] {
            let card = app.buttons.containing(
                NSPredicate(format: "label CONTAINS '\(world)'")).firstMatch
            XCTAssertTrue(card.waitForExistence(timeout: 5), world)
            if !card.isHittable { app.swipeLeft() }
            card.tap()
            sleep(3)    // async world rebuild + prop spawn
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = "world-\(world)"
            shot.lifetime = .keepAlways
            add(shot)
        }
        chip.tap()      // close the world strip
    }

    @MainActor
    func testDecoratePlacesAndMoves() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--trackbuilder"]
        app.launch()

        let straight = app.buttons.containing(
            NSPredicate(format: "label CONTAINS 'Straight'")).firstMatch
        XCTAssertTrue(straight.waitForExistence(timeout: 10))
        for _ in 0..<2 { straight.tap() }

        app.buttons["decorateToggle"].tap()
        // Pick the first prop of the first world group (candy).
        let prop = app.buttons["item-banana"]
        XCTAssertTrue(prop.waitForExistence(timeout: 5))
        prop.tap()

        // Drop three of them on the ground around the scene.
        for spot in [CGPoint(x: 0.3, y: 0.30), CGPoint(x: 0.7, y: 0.28),
                     CGPoint(x: 0.55, y: 0.38)] {
            app.coordinate(withNormalizedOffset: CGVector(dx: spot.x, dy: spot.y)).tap()
            sleep(1)
        }
        sleep(2)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "decorated"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
