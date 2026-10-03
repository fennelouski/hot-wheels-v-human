#if os(iOS)
import XCTest

final class IPadReleaseFlowUITests: XCTestCase {
    @MainActor
    func testNormalEntryAndSavedCarSurviveColdLaunch() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Who's playing?"].waitForExistence(timeout: 15))
        app.buttons.containing(NSPredicate(format: "label CONTAINS 'New Racer'")).firstMatch.tap()
        let name = app.textFields["Your name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        // Keep the generated profile name. Creation uses the real sheet and
        // persistence path, without model injection or a test-only store.
        app.buttons["tv-profile-create"].tap()
        XCTAssertTrue(app.staticTexts["iPad Workshop"].waitForExistence(timeout: 15))
        if app.alerts.firstMatch.waitForExistence(timeout: 2) {
            let allow = app.alerts.buttons["Allow"]
            if allow.exists { allow.tap() }
        }
        capture(app, "ipad-home")

        app.buttons.containing(NSPredicate(format: "label CONTAINS 'Build a Car'")).firstMatch.tap()
        let paint = app.buttons.containing(NSPredicate(format: "label == 'Paint'")).firstMatch
        XCTAssertTrue(paint.waitForExistence(timeout: 15))
        paint.tap()
        let red = app.buttons["Red"]
        XCTAssertTrue(red.waitForExistence(timeout: 10))
        red.tap()
        let save = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Save it' OR label CONTAINS 'Saved!'")).firstMatch
        XCTAssertTrue(save.isHittable)
        save.tap()
        XCTAssertTrue(app.buttons.containing(NSPredicate(format: "label CONTAINS 'Saved!'")).firstMatch.waitForExistence(timeout: 10))
        capture(app, "ipad-saved-red-car")
        app.terminate()

        app.launchArguments = ["--garage"]
        app.launch()
        let saved = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'tv-garage-car-'")).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 15), "A saved car must reopen in Garage after a cold launch")
        saved.tap()
        let edit = app.buttons["tv-garage-edit-car"]
        XCTAssertTrue(edit.waitForExistence(timeout: 10))
        edit.tap()
        XCTAssertTrue(paint.waitForExistence(timeout: 10))
        paint.tap()
        XCTAssertTrue(red.isSelected, "The saved paint must survive reopening the editor")
        capture(app, "ipad-reopened-red-car")
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
#endif
