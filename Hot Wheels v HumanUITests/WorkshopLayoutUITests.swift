//
//  WorkshopLayoutUITests.swift
//  Hot Wheels v HumanUITests
//
//  The workshop tab strips are as tall as their tallest tab — the Paint
//  swatch grid and the Face bench both overflowed the old fixed content
//  frame and drew straight through "Test Drive!"/"Save it!". These tests
//  assert the action row stays clear of the tab content, and attach
//  screenshots of every tab for eyeballing.
//

import XCTest

final class WorkshopLayoutUITests: XCTestCase {

    @MainActor
    func testCarWorkshopTabsClearTheActionRow() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--customizer"]
        app.launch()

        for tab in ["Chassis", "Tires", "Paint", "Livery", "Stickers", "Draw", "Driver"] {
            app.buttons.containing(NSPredicate(format: "label CONTAINS %@", tab))
                .firstMatch.tap()
            snap(app, "car-\(tab)")
            assertActionRowIsClear(app, tab: tab)
        }
    }

    @MainActor
    func testCharacterWorkshopTabsClearTheActionRow() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--character-editor"]
        app.launch()

        for tab in ["Face", "Hair", "Clothes", "Extras", "Me!"] {
            app.buttons.containing(NSPredicate(format: "label CONTAINS %@", tab))
                .firstMatch.tap()
            snap(app, "character-\(tab)")
            assertActionRowIsClear(app, tab: tab)
        }
    }

    /// Nothing in the tab content may sit on top of the two action buttons.
    private func assertActionRowIsClear(_ app: XCUIApplication, tab: String) {
        let testDrive = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Test Drive'"))
            .firstMatch
        XCTAssertTrue(testDrive.waitForExistence(timeout: 5), "\(tab): no Test Drive button")
        let actionRow = testDrive.frame

        for other in app.buttons.allElementsBoundByIndex {
            let frame = other.frame
            // Off-screen and scrolled-away elements report empty or infinite
            // frames; they can't be sitting on the buttons, and asking them
            // for hittability throws.
            guard !frame.isEmpty, frame.maxY.isFinite, !frame.equalTo(actionRow),
                  frame.intersects(actionRow) else { continue }
            let label = other.label
            guard !label.contains("Test Drive"), !label.contains("Save it"),
                  !label.contains("Saved") else { continue }
            XCTFail("\(tab): '\(label)' overlaps the action row")
        }
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
