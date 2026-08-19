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

        for world in ["Big City", "Speedway"] {
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

        // Sidewalk tiles from the Streets shelf...
        let streets = app.buttons.containing(
            NSPredicate(format: "label CONTAINS 'Streets'")).firstMatch
        XCTAssertTrue(streets.waitForExistence(timeout: 5))
        streets.tap()
        let tile = app.buttons["street-square"]
        XCTAssertTrue(tile.waitForExistence(timeout: 5))
        tile.tap()
        for spot in [CGPoint(x: 0.35, y: 0.30), CGPoint(x: 0.45, y: 0.30),
                     CGPoint(x: 0.55, y: 0.30)] {
            app.coordinate(withNormalizedOffset: CGVector(dx: spot.x, dy: spot.y)).tap()
            sleep(1)
        }

        // ...and a couple of people to stroll them.
        app.buttons.containing(NSPredicate(format: "label CONTAINS 'People'"))
            .firstMatch.tap()
        let person = app.buttons["person-a"]
        XCTAssertTrue(person.waitForExistence(timeout: 5))
        person.tap()
        for spot in [CGPoint(x: 0.4, y: 0.28), CGPoint(x: 0.6, y: 0.33)] {
            app.coordinate(withNormalizedOffset: CGVector(dx: spot.x, dy: spot.y)).tap()
            sleep(1)
        }
        sleep(2)
        var shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "decorated"
        shot.lifetime = .keepAlways
        add(shot)

        // Sky-stuff: a ringed planet and a nebula floating over the track.
        app.buttons.containing(NSPredicate(format: "label CONTAINS 'Planets'"))
            .firstMatch.tap()
        let planet = app.buttons["space-planet-rings"]
        XCTAssertTrue(planet.waitForExistence(timeout: 5))
        planet.tap()
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.45)).tap()
        sleep(1)
        app.buttons["space-nebula-pink"].tap()
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.4)).tap()
        sleep(2)
        shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "planets"
        shot.lifetime = .keepAlways
        add(shot)
    }

    @MainActor
    func testEmptyWorldAndTrain() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--trackbuilder"]
        app.launch()
        let straight = app.buttons.containing(
            NSPredicate(format: "label CONTAINS 'Straight'")).firstMatch
        XCTAssertTrue(straight.waitForExistence(timeout: 10))
        for _ in 0..<2 { straight.tap() }

        app.buttons["worldChip"].tap()
        let winter = app.buttons.containing(
            NSPredicate(format: "label CONTAINS 'Winter'")).firstMatch
        XCTAssertTrue(winter.waitForExistence(timeout: 5))
        winter.tap()
        sleep(4)
        var shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "winter-train"
        shot.lifetime = .keepAlways
        add(shot)

        app.buttons["emptyWorldCard"].tap()
        sleep(3)
        shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "winter-empty"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
