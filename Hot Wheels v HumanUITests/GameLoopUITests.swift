import XCTest

/// Only this class is authorized for the new bounded native round. Every launch
/// keeps its session UUID: a private disk store/suite, no real accounts, audio,
/// haptics, camera permissions or local-network advertising/browsing.
@MainActor final class GameLoopUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    override func tearDownWithError() throws {
        #if os(iOS)
        XCUIDevice.shared.orientation = .portrait
        #endif
    }

    func testFirstViewportPlayActualFinishShareAndRematch() throws {
        let app = launch()
        defer { app.terminate() }
        let play = app.buttons["launch-play"]
        XCTAssertTrue(play.waitForExistence(timeout: 15))
        XCTAssertTrue(play.isHittable, "Play must be visible without scrolling or choosing a profile")
        #if os(tvOS)
        XCTAssertTrue(play.hasFocus, "Select must start Play on a fresh TV launch")
        #endif
        capture("01 - First launch with visible Play")
        try select(play, in: app)
        XCTAssertTrue(app.buttons["race-camera"].waitForExistence(timeout: 45))
        XCTAssertTrue(raceControl(in: app).waitForExistence(timeout: 12),
                      "Capture only after the real race emits its first telemetry")
        capture("02 - Real standalone race")
        let rematch = app.buttons["race-rematch"]
        XCTAssertTrue(rematch.waitForExistence(timeout: 120), "The normal physics/rules path must finish")
        XCTAssertTrue(app.staticTexts["Top speed"].exists)
        capture("03 - Actual finish and race statistics")
        try wait("The real arena must prepare a valid finish frame before presentation", timeout: 15, in: app) {
            app.buttons["race-share"].value as? String == "Ready"
        }
        try select(app.buttons["race-share"], in: app)
        XCTAssertTrue(app.images["race-share-image"].waitForExistence(timeout: 20),
                      "A genuine decoded arena image must be prepared, never a placeholder")
        capture("04 - Frozen race image and result")
        #if os(iOS)
        let systemShare = app.buttons["race-share-system"]
        XCTAssertTrue(systemShare.exists && systemShare.isHittable)
        systemShare.tap()
        let chooser = app.otherElements["ActivityListView"]
        XCTAssertTrue(chooser.waitForExistence(timeout: 15), "Present the real native share chooser")
        capture("04b - Native image share chooser")
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "Native share chooser accessibility"; tree.lifetime = .keepAlways; add(tree)
        // There are dismissal regions for both sheets underneath the chooser.
        // The last native region belongs to the topmost popover; its center is
        // covered by ActivityListView, so tap a verified outside point instead.
        let regions = app.descendants(matching: .any).matching(identifier: "PopoverDismissRegion").allElementsBoundByIndex
        if let outside = regions.last {
            let bounds = outside.frame.intersection(app.windows.firstMatch.frame)
            let popover = chooser.frame.insetBy(dx: -8, dy: -8)
            let points = [CGPoint(x: popover.minX - 16, y: popover.midY),
                          CGPoint(x: popover.maxX + 16, y: popover.midY),
                          CGPoint(x: popover.midX, y: popover.minY - 16)]
            guard let point = points.first(where: { bounds.contains($0) && !popover.contains($0) }) else {
                XCTFail("The native dismissal region has no safe point outside the chooser")
                throw FlowError.dismissal
            }
            outside.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
                dx: point.x - outside.frame.minX, dy: point.y - outside.frame.minY)).tap()
        } else if app.buttons["Close"].exists && app.buttons["Close"].isHittable {
            app.buttons["Close"].tap()
        } else if app.buttons["Cancel"].exists && app.buttons["Cancel"].isHittable {
            app.buttons["Cancel"].tap()
        } else {
            XCTFail("The observed native chooser must expose a safe dismissal without selecting a destination")
            throw FlowError.dismissal
        }
        try wait("Dismiss the chooser and retain the same frozen result", timeout: 10, in: app) {
            !chooser.exists && app.images["race-share-image"].exists && systemShare.exists
        }
        capture("04c - Same frozen result after chooser dismissal")
        // No recipient, external application or share destination is selected.
        #else
        XCTAssertTrue(app.staticTexts["race-share-handoff"].exists)
        #endif
        try select(app.buttons["race-share-close"], in: app)
        try select(rematch, in: app)
        try wait("Rematch must start a fresh real race", timeout: 30, in: app) {
            !rematch.exists && self.raceControl(in: app).exists
        }
        capture("05 - Rematch begins another race")
    }

    func testIndependentSavedSettingsAndCalmPlay() throws {
        let app = launch(largestText: true)
        defer { app.terminate() }
        let play = app.buttons["launch-play"]
        XCTAssertTrue(play.waitForExistence(timeout: 15) && play.isHittable)
        capture("06 - Largest text launch actions")
        try select(app.buttons["launch-settings"], in: app)
        let animation = app.buttons["game-setting-animation"]
        let haptics = app.buttons["game-setting-haptics"]
        XCTAssertTrue(animation.waitForExistence(timeout: 10))
        XCTAssertEqual(animation.value as? String, "On")
        XCTAssertEqual(haptics.value as? String, "On")
        try select(animation, in: app)
        XCTAssertEqual(animation.value as? String, "Off")
        XCTAssertEqual(haptics.value as? String, "On", "Motion and haptics must remain independent")
        try select(haptics, in: app)
        XCTAssertEqual(haptics.value as? String, "Off")
        capture("07 - Independent animation and haptic settings")
        app.terminate()
        app.launch()
        try select(app.buttons["launch-settings"], in: app)
        XCTAssertEqual(animation.value as? String, "Off")
        XCTAssertEqual(haptics.value as? String, "Off")
        capture("08 - Saved choices after relaunch")
        try back(in: app)
        try select(play, in: app)
        let camera = app.buttons["race-camera"]
        XCTAssertTrue(camera.waitForExistence(timeout: 45))
        XCTAssertEqual(camera.value as? String, "Calm Cam")
        XCTAssertFalse(camera.isEnabled, "Saved driver view cannot override the calm camera policy")
        XCTAssertTrue(raceControl(in: app).waitForExistence(timeout: 8), "Calm play retains the real boost control after the first telemetry tick")
        capture("09 - Calm camera with live race controls")
    }

    func testOptionalProfileStillOpensEveryWorkshop() throws {
        let app = launch()
        defer { app.terminate() }
        #if os(tvOS)
        let newProfile = app.buttons["tv-new-profile"]
        #else
        let newProfile = app.buttons.containing(NSPredicate(format: "label CONTAINS 'New Racer'")).firstMatch
        #endif
        XCTAssertTrue(newProfile.waitForExistence(timeout: 15))
        try select(newProfile, in: app)
        let create = app.buttons["tv-profile-create"]
        XCTAssertTrue(create.waitForExistence(timeout: 10))
        try select(create, in: app)
        #if os(tvOS)
        XCTAssertTrue(app.buttons["tv-home-quickPlay"].waitForExistence(timeout: 15))
        for tile in ["quickPlay", "car", "track", "robot", "garage", "twoPlayer", "racers", "iPad"] {
            XCTAssertTrue(app.buttons["tv-home-\(tile)"].exists)
        }
        try select(app.buttons["tv-home-car"], in: app)
        XCTAssertTrue(app.buttons["tv-car-tab-paint"].waitForExistence(timeout: 20))
        try select(app.buttons["tv-car-tab-paint"], in: app)
        let red = app.buttons.matching(NSPredicate(format: "label == 'Color, Red'")).firstMatch
        try select(red, in: app)
        XCTAssertTrue(red.isSelected)
        capture("10 - TV workshop still edits the actual car")
        #else
        XCTAssertTrue(app.staticTexts["iPad Workshop"].waitForExistence(timeout: 15))
        for label in ["Build a Car", "Build a Track", "Race a Robot", "Garage", "2-Player Build", "My Racers"] {
            XCTAssertTrue(app.buttons.containing(NSPredicate(format: "label CONTAINS %@", label)).firstMatch.exists)
        }
        capture("10 - Optional player and touch workshop")
        #endif
    }

    private func launch(largestText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-HWTestSession", UUID().uuidString]
        #if os(iOS)
        XCUIDevice.shared.orientation = .landscapeLeft
        if largestText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        #endif
        app.launch()
        return app
    }

    private func select(_ element: XCUIElement, in app: XCUIApplication) throws {
        XCTAssertTrue(element.waitForExistence(timeout: 12))
        #if os(tvOS)
        var visits: [String: Int] = [:]
        for _ in 0..<60 {
            if element.hasFocus { XCUIRemote.shared.press(.select); return }
            guard let current = app.buttons.allElementsBoundByIndex.first(where: { $0.hasFocus }) else {
                XCUIRemote.shared.press(.down); continue
            }
            let key = current.identifier + "|" + current.label
            let seen = visits[key, default: 0]
            visits[key] = seen + 1
            let dx = element.frame.midX - current.frame.midX
            let dy = element.frame.midY - current.frame.midY
            let horizontal: XCUIRemote.Button = dx >= 0 ? .right : .left
            let vertical: XCUIRemote.Button = dy >= 0 ? .down : .up
            XCUIRemote.shared.press(seen % 2 == 0
                ? (abs(dx) > abs(dy) ? horizontal : vertical)
                : (abs(dx) > abs(dy) ? vertical : horizontal))
        }
        capture("Remote focus failure")
        XCTFail("The real TV focus engine could not reach \(element.identifier)")
        throw FlowError.focus
        #else
        XCTAssertTrue(element.isHittable)
        element.tap()
        #endif
    }

    private func back(in app: XCUIApplication) throws {
        #if os(tvOS)
        XCUIRemote.shared.press(.menu)
        #else
        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.exists && back.isHittable)
        back.tap()
        #endif
    }
    private func raceControl(in app: XCUIApplication) -> XCUIElement {
        #if os(tvOS)
        return app.buttons["race-boost"]
        #else
        // The touch boost dial exposes its genuine percentage label; it is
        // deliberately not a TV remote button on iPad.
        return app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^[0-9]{1,3}%$")).firstMatch
        #endif
    }
    private func wait(_ message: String, timeout: TimeInterval, in app: XCUIApplication, condition: () -> Bool) throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            Thread.sleep(forTimeInterval: 0.2)
        }
        capture("Flow failure")
        add(XCTAttachment(string: app.debugDescription))
        XCTFail(message)
        throw FlowError.timeout
    }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private enum FlowError: Error { case focus, timeout, dismissal }
}
