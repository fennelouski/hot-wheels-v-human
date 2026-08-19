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

        for world in ["Big City", "Speedway", "Castle", "Winter",
                      "Pirate Cove", "Spooky", "Snack Land", "Canyon"] {
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
    }
}
