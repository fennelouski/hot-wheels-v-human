#if os(iOS)
import XCTest

/// Release evidence from native touch input and the production persistence path.
@MainActor
final class IPadWorkshopReleaseUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
    }

    override func tearDownWithError() throws {
        if let testRun, testRun.failureCount > 0 {
            capture("iPad workshop failure - full screen")
            let tree = XCTAttachment(string: XCUIApplication().debugDescription)
            tree.name = "iPad workshop failure - native accessibility tree"
            tree.lifetime = .keepAlways
            add(tree)
        }
        XCUIApplication().terminate()
    }

    func testIPad01FingerDrawingStickerLiverySaveAndColdReopen() throws {
        let app = try launch("--garage", ready: { $0.buttons.containing(
            NSPredicate(format: "label CONTAINS 'Build a New Car'")).firstMatch })
        capture("IPAD01 - Garage before the native drawing workflow")
        app.buttons.containing(NSPredicate(format: "label CONTAINS 'Build a New Car'"))
            .firstMatch.tap()

        let name = app.textFields["Car name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        let carName = "iPad Art \(UUID().uuidString.prefix(8))"
        let originalName = try XCTUnwrap(name.value as? String)
        // Touch the trailing edge to put the insertion point after the name,
        // then replace it with real keyboard input. The saved card is unique.
        name.coordinate(withNormalizedOffset: CGVector(dx: 0.96, dy: 0.5)).tap()
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue,
                             count: originalName.count) + carName + "\n")
        XCTAssertEqual(name.value as? String, carName)

        try tab("Paint", in: app)
        let red = app.buttons["Red"]
        XCTAssertTrue(red.waitForExistence(timeout: 5))
        red.tap()
        XCTAssertTrue(red.isSelected)
        try save(app)

        try tab("Draw", in: app)
        let canvas = try drawingCanvas(in: app)
        XCTContext.runActivity(named: "Draw two real finger strokes in PencilKit") { _ in
            point(app, in: canvas, x: 0.25, y: 0.50).press(forDuration: 0.05,
                thenDragTo: point(app, in: canvas, x: 0.53, y: 0.66))
            point(app, in: canvas, x: 0.53, y: 0.66).press(forDuration: 0.05,
                thenDragTo: point(app, in: canvas, x: 0.76, y: 0.46))
        }
        try requireUnsaved(app, "A real PencilKit stroke must change the saved car")
        capture("IPAD02 - Actual finger strokes on the car drawing canvas")
        try save(app)

        let stampShelf = try drawingStampShelf(in: app)
        let star = stampShelf.buttons.element(boundBy: 0)
        XCTAssertTrue(star.waitForExistence(timeout: 5))
        try reveal(star, in: stampShelf, app: app)
        star.tap() // DrawingPadView's first native stamp is star.fill.
        point(app, in: canvas, x: 0.43, y: 0.36).tap()
        try requireUnsaved(app, "Placing a real sticker on the pad must edit the car")
        capture("IPAD03 - A star sticker placed with native touch input")
        try save(app)

        try tab("Stickers", in: app)
        XCTAssertTrue(app.staticTexts["Pick a sticker!"].waitForExistence(timeout: 5))
        let turntable = try turntableElement(in: app)
        turntable.pinch(withScale: 1.45, velocity: 1)
        try requireUnsaved(app, "Pinching in the sticker tools must resize the placed sticker")
        capture("IPAD04 - Real sticker resize on the 3D car")

        try tab("Livery", in: app)
        let patterns = app.scrollViews.containing(.staticText, identifier: "Plain").firstMatch
        XCTAssertTrue(patterns.waitForExistence(timeout: 5))
        XCTAssertEqual(patterns.buttons.count, 8,
                       "The production shelf must contain Plain and its seven patterns")
        // These decorative image chips have no text label. Their native shelf
        // order is Plain, Racing Stripes, Flames, Dots, Bolt, Checks, Stars, Zigzag.
        let flames = patterns.buttons.element(boundBy: 2)
        try reveal(flames, in: patterns, app: app)
        flames.tap()
        let size = app.sliders["Size"]
        XCTAssertTrue(size.waitForExistence(timeout: 5),
                      "Picking an actual livery must reveal its Size control")
        size.adjust(toNormalizedSliderPosition: 0.70)
        let savedSize = try sliderValue(size)
        XCTAssertGreaterThan(savedSize, 1.2)
        try save(app)
        capture("IPAD05 - Saved hand drawn car with resized sticker and flame livery")

        app.terminate()
        _ = try launch("--garage", app: app, ready: { $0.buttons.containing(
            NSPredicate(format: "label CONTAINS 'Build a New Car'")).firstMatch })
        let card = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH 'tv-garage-car-' AND label CONTAINS %@", carName))
            .firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10),
                      "The exact car created through the workshop must survive a cold launch")
        let savedCarID = card.identifier
        XCTAssertTrue(savedCarID.hasPrefix("tv-garage-car-"))
        try revealVertically(card, in: app.scrollViews.firstMatch, app: app)
        app.buttons[savedCarID].tap()
        let edit = app.buttons["tv-garage-edit-car"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, carName)
        try tab("Paint", in: app)
        XCTAssertTrue(red.isSelected, "The saved paint must survive reopening this exact car")
        try tab("Livery", in: app)
        XCTAssertTrue(size.waitForExistence(timeout: 5), "The saved livery must reopen")
        XCTAssertEqual(try sliderValue(size), savedSize, accuracy: 0.01,
                       "The livery's real slider value must survive persistence")
        try tab("Draw", in: app)
        let reopenedCanvas = try drawingCanvas(in: app)
        capture("IPAD06 - Cold reopened strokes and sticker in the editable drawing pad")

        // Clearing only the drawing changes the design iff drawing data really
        // reopened. It leaves paint, livery and stickers alone. Undo restores it.
        try save(app)
        let clearDrawing = try drawingClearButton(in: app, canvas: reopenedCanvas)
        clearDrawing.tap()
        try requireUnsaved(app, "The cold reopened car must contain actual saved drawing data")
        app.buttons.containing(NSPredicate(format: "label CONTAINS 'Undo'"))
            .firstMatch.tap()
        try save(app)
        capture("IPAD07 - Persisted drawing restored through the native Undo control")
    }

    func testIPad02PersonalFinishableTrackAndWorldSaveAndColdLibraryReload() throws {
        let app = try launch("--trackbuilder", ready: { $0.staticTexts["Track Builder"] })
        XCTAssertTrue(app.staticTexts["1 piece"].waitForExistence(timeout: 5))
        let previousLabels = savedTrackLabels(in: app)
        capture("IPAD08 - Fresh native track builder and personal library")

        for count in 2...5 {
            tapPieceCard("Straight", in: app)
            XCTAssertTrue(app.staticTexts["\(count) pieces"].waitForExistence(timeout: 5))
        }
        tapPieceCard("Finish", in: app)
        XCTAssertTrue(app.staticTexts["6 pieces"].waitForExistence(timeout: 5))
        let race = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Race it!'"))
            .firstMatch
        XCTAssertTrue(race.waitForExistence(timeout: 5))
        XCTAssertTrue(race.isEnabled, "The native piece edits must produce a finishable track")

        let world = app.buttons["worldChip"]
        world.tap()
        let candy = app.buttons.containing(.staticText, identifier: "Candy").firstMatch
        XCTAssertTrue(candy.waitForExistence(timeout: 5))
        let worlds = app.scrollViews.containing(.staticText, identifier: "Candy").firstMatch
        try reveal(candy, in: worlds, app: app)
        candy.tap()
        XCTAssertEqual(world.label, "World: Candy")
        world.tap()
        settle(2)
        capture("IPAD09 - Six real track pieces and the selected Candy world")
        try save(app)
        capture("IPAD10 - Personal finishable track saved through the native action")

        app.buttons.containing(NSPredicate(format: "label CONTAINS 'Clear'"))
            .firstMatch.tap()
        XCTAssertTrue(app.staticTexts["1 piece"].waitForExistence(timeout: 5))
        let newLabels = savedTrackLabels(in: app).subtracting(previousLabels)
        XCTAssertEqual(newLabels.count, 1,
                       "Saving must create one distinct personal library chip; names: \(newLabels)")
        let savedLabel = try XCTUnwrap(newLabels.first)
        let exactChip = app.buttons.matching(NSPredicate(format: "label == %@", savedLabel))
        XCTAssertEqual(exactChip.count, 1, "The new saved chip must identify one library entry")
        let library = app.scrollViews.containing(NSPredicate(format: "label == %@", savedLabel))
            .firstMatch
        try reveal(exactChip.firstMatch, in: library, app: app)
        capture("IPAD11 - Exact newly saved personal track in the library")

        app.terminate()
        _ = try launch("--trackbuilder", app: app, ready: { $0.staticTexts["Track Builder"] })
        XCTAssertTrue(app.staticTexts["1 piece"].waitForExistence(timeout: 5))
        XCTAssertTrue(exactChip.firstMatch.waitForExistence(timeout: 10),
                      "The exact new personal track chip must survive a cold launch")
        XCTAssertEqual(exactChip.count, 1)
        try reveal(exactChip.firstMatch, in: library, app: app)
        exactChip.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["6 pieces"].waitForExistence(timeout: 5),
                      "The actual six-piece build must reload from the saved library entry")
        XCTAssertEqual(world.label, "World: Candy", "The saved world must reload with the track")
        XCTAssertTrue(race.isEnabled, "The reloaded personal track must remain finishable")
        app.buttons["miniMap"].tap()
        settle(2)
        capture("IPAD12 - Cold loaded personal track, saved world and expanded track map")
    }

    func testIPad03ActiveRaceNativeBoostHoldAndChaseToDriverCamera() throws {
        let app = try launch("--stress-track", ready: { $0.buttons["race-camera"] })
        let camera = app.buttons["race-camera"]
        let meter = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^[0-9]{1,3}%$"))
            .firstMatch
        try wait("A loaded race must report moving-car telemetry and a charged real boost meter",
                 timeout: 30) {
            let speed = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'm/s'"))
                .firstMatch
            return speed.exists && self.leadingNumber(speed.label) > 0.2
                && meter.exists && self.leadingNumber(meter.label) >= 100
        }
        XCTAssertEqual(camera.value as? String, "Driver View")
        camera.tap()
        try wait("The native camera must switch to Chase Cam", timeout: 5) {
            camera.value as? String == "Chase Cam"
        }
        capture("IPAD13 - Loaded moving race in Chase Cam")
        camera.tap()
        try wait("The native camera must return to Driver View", timeout: 5) {
            camera.value as? String == "Driver View"
        }
        capture("IPAD14 - Active Driver View with the dashboard radio")

        try wait("Boost must be charged before the real touch hold", timeout: 15) {
            meter.exists && self.leadingNumber(meter.label) >= 100
        }
        let before = leadingNumber(meter.label)
        XCTContext.runActivity(named: "Hold the real boost dial with native touch for three seconds") { _ in
            meter.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .press(forDuration: 3)
        }
        try wait("A real held boost must consume the charged meter", timeout: 3) {
            meter.exists && self.leadingNumber(meter.label) < before - 10
        }
        let after = leadingNumber(meter.label)
        XCTAssertLessThan(after, before - 10)
        capture("IPAD15 - Active race after a real charged boost hold")
        let proof = XCTAttachment(string: "Native touch hold: 3 seconds. Boost meter before: \(before)%; after: \(after)%. Camera: \(camera.value ?? "missing").")
        proof.name = "iPad native boost hold - actual control evidence"
        proof.lifetime = .keepAlways
        add(proof)
    }

    func testIPad04DeterministicPresetRaceAfterRenderedCameraSettles() throws {
        let app = XCUIApplication()
        // This is the ordinary, fixed starter blueprint available in the
        // Library. Keep the separate random stress-track test unchanged.
        app.launchArguments = ["--preset-track", "6"]
        app.launch()
        let camera = app.buttons["race-camera"]
        XCTAssertTrue(camera.waitForExistence(timeout: 15))
        XCTAssertGreaterThan(app.frame.width, app.frame.height)
        XCTAssertEqual(camera.value as? String, "Driver View")

        camera.tap()
        try wait("The native camera must switch to Chase Cam", timeout: 5) {
            camera.value as? String == "Chase Cam"
        }
        // The camera's accessibility value changes before RealityKit finishes
        // reparenting and easing it out of the car. Wait beyond the production
        // occlusion grace interval before taking an original full-screen image.
        settle(5)
        let speed = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'm/s'"))
            .firstMatch
        try wait("The deterministic starter race must report a moving car", timeout: 15) {
            speed.exists && self.leadingNumber(speed.label) > 0.2
        }
        capture("IPAD16 - Deterministic starter track after five seconds of Chase Cam rendering")

        let meter = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^[0-9]{1,3}%$"))
            .firstMatch
        try wait("The moving deterministic race must charge its actual boost meter", timeout: 30) {
            speed.exists && self.leadingNumber(speed.label) > 0.2
                && meter.exists && self.leadingNumber(meter.label) >= 100
        }
        capture("IPAD17 - Charged boost on the deterministic starter track in Chase Cam")
        let before = leadingNumber(meter.label)
        XCTContext.runActivity(named: "Hold the actual boost dial in Chase Cam for three seconds") { _ in
            meter.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .press(forDuration: 3)
        }
        try wait("The real held boost must consume the charged meter", timeout: 3) {
            meter.exists && self.leadingNumber(meter.label) < before - 10
        }
        let after = leadingNumber(meter.label)
        XCTAssertLessThan(after, before - 10)
        capture("IPAD18 - Deterministic starter race after the actual charged boost hold")

        camera.tap()
        try wait("The native camera must return to Driver View", timeout: 5) {
            camera.value as? String == "Driver View"
        }
        settle(2)
        capture("IPAD19 - Deterministic starter race after two seconds of Driver View rendering")
        let proof = XCTAttachment(string: "Existing native launch route: --preset-track 6. Starter blueprint: The Mega Mega Track, 75 pieces. Chase camera render settling: 5 seconds. Driver render settling: 2 seconds. Native boost touch hold: 3 seconds. Meter before: \(before)%; after: \(after)%. Final camera: \(camera.value ?? "missing"). No production source edits or screenshot transformations.")
        proof.name = "iPad deterministic starter race - actual camera and boost evidence"
        proof.lifetime = .keepAlways
        add(proof)
    }

    // MARK: Native UI helpers

    private func launch(_ argument: String, app: XCUIApplication = XCUIApplication(),
                        ready: (XCUIApplication) -> XCUIElement) throws -> XCUIApplication {
        app.launchArguments = [argument]
        app.launch()
        XCTAssertTrue(ready(app).waitForExistence(timeout: 15))
        XCTAssertGreaterThan(app.frame.width, app.frame.height,
                             "The release workshop must fill a landscape iPad window")
        return app
    }

    private func tab(_ title: String, in app: XCUIApplication) throws {
        let button = app.buttons.matching(identifier: title).firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Missing workshop tab \(title)")
        let row = app.scrollViews.containing(.button, identifier: title).firstMatch
        try reveal(button, in: row, app: app)
        button.tap()
        XCTAssertTrue(button.isSelected, "\(title) must be the selected native tool tab")
    }

    private func save(_ app: XCUIApplication) throws {
        let action = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Save it!'"))
            .firstMatch
        XCTAssertTrue(action.waitForExistence(timeout: 5))
        XCTAssertTrue(action.isEnabled)
        action.tap()
        XCTAssertTrue(app.buttons.containing(NSPredicate(format: "label CONTAINS 'Saved!'"))
            .firstMatch.waitForExistence(timeout: 8), "The production save must report success")
    }

    private func requireUnsaved(_ app: XCUIApplication, _ message: String) throws {
        XCTAssertTrue(app.buttons.containing(NSPredicate(format: "label CONTAINS 'Save it!'"))
            .firstMatch.waitForExistence(timeout: 5), message)
    }

    private func reveal(_ target: XCUIElement, in row: XCUIElement,
                        app: XCUIApplication) throws {
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        for _ in 0..<8 {
            let frame = target.frame
            if !frame.isEmpty && app.frame.insetBy(dx: 4, dy: 0).contains(frame) { return }
            guard row.exists else { break }
            if !frame.isEmpty && frame.midX < app.frame.midX { row.swipeRight() }
            else { row.swipeLeft() }
        }
        throw failure("Native shelf could not reveal '\(target.label)' in eight swipes")
    }

    private func revealVertically(_ target: XCUIElement, in scroll: XCUIElement,
                                  app: XCUIApplication) throws {
        for _ in 0..<8 {
            let frame = target.frame
            if !frame.isEmpty && app.frame.insetBy(dx: 4, dy: 4).contains(frame) { return }
            scroll.swipeUp()
        }
        throw failure("The saved Garage car did not become reachable in eight native swipes")
    }

    private func drawingCanvas(in app: XCUIApplication) throws -> CGRect {
        let tabBottom = app.buttons["Draw"].frame.maxY
        let actionTop = app.buttons.containing(NSPredicate(
            format: "label CONTAINS 'Test Drive!'" )).firstMatch.frame.minY
        let window = app.frame
        // PKCanvasView and its SwiftUI host can appear as a scroll view or an
        // Other element. Read one public native snapshot and select the actual
        // canvas geometry; the tool grid and stamp shelf both contain buttons.
        let snapshot = try app.snapshot()
        var candidates: [CGRect] = []
        func hasButton(_ node: any XCUIElementSnapshot) -> Bool {
            node.children.contains { $0.elementType == .button || hasButton($0) }
        }
        func visit(_ node: any XCUIElementSnapshot) {
            let frame = node.frame
            if (node.elementType == .scrollView || node.elementType == .other)
                && frame.width > 140 && frame.width < window.width - 120
                && frame.height > 100 && frame.minY >= tabBottom - 2
                && frame.maxY <= actionTop + 2 && window.contains(frame) && !hasButton(node) {
                candidates.append(frame)
            }
            for child in node.children { visit(child) }
        }
        visit(snapshot)
        guard let canvas = candidates.max(by: { $0.width * $0.height < $1.width * $1.height })
        else { throw failure("No native PencilKit canvas frame between Draw and Test Drive: \(candidates)") }
        return canvas
    }

    private func drawingStampShelf(in app: XCUIApplication) throws -> XCUIElement {
        let tabBottom = app.buttons["Draw"].frame.maxY
        let actionTop = app.buttons.containing(NSPredicate(
            format: "label CONTAINS 'Test Drive!'" )).firstMatch.frame.minY
        for row in app.scrollViews.allElementsBoundByIndex {
            let frame = row.frame
            if frame.minY >= tabBottom && frame.maxY <= actionTop
                && frame.height >= 58 && frame.height <= 70 && row.buttons.count == 19 {
                return row
            }
        }
        throw failure("The native 19-stamp drawing shelf was not exposed below Draw")
    }

    private func drawingClearButton(in app: XCUIApplication, canvas: CGRect) throws -> XCUIElement {
        var tools: [(element: XCUIElement, frame: CGRect)] = []
        let top = app.buttons["Draw"].frame.maxY
        let bottom = try drawingStampShelf(in: app).frame.minY
        for button in app.buttons.allElementsBoundByIndex {
            let frame = button.frame
            if frame.width >= 44 && frame.width < 58 && frame.height >= 44 && frame.height < 58
                && frame.minX >= canvas.maxX && frame.minY >= top
                && frame.maxY <= bottom {
                tools.append((button, frame))
            }
        }
        XCTAssertEqual(tools.count, 8, "The real drawing grid must have six inks, eraser and clear")
        // The last row is Eraser/Clear. Native geometry avoids relying on the
        // OS's localized name for the decorative trash symbol.
        guard let clear = tools.max(by: {
            if abs($0.frame.midY - $1.frame.midY) > 4 { return $0.frame.midY < $1.frame.midY }
            return $0.frame.midX < $1.frame.midX
        }) else { throw failure("No native drawing Clear tool to verify saved ink") }
        return clear.element
    }

    private func turntableElement(in app: XCUIApplication) throws -> XCUIElement {
        let top = app.textFields["Car name"].frame.maxY
        let bottom = app.buttons["Stickers"].frame.minY
        var candidates: [(element: XCUIElement, area: CGFloat)] = []
        for element in app.otherElements.allElementsBoundByIndex {
            let frame = element.frame
            if frame.width > app.frame.width * 0.7 && frame.height >= 200
                && frame.minY >= top - 2 && frame.maxY <= bottom + 2 {
                candidates.append((element, frame.width * frame.height))
            }
        }
        if let turntable = candidates.max(by: { $0.area < $1.area }) { return turntable.element }
        // A RealityView can omit its own AX node. XCUITest's native pinch uses
        // the element centre; only use the window when that centre lies inside
        // the real turntable band bounded by the visible name and tool tabs.
        guard app.frame.midY > top + 20 && app.frame.midY < bottom - 20
        else { throw failure("The native pinch centre is outside the 3D turntable") }
        return app
    }

    private func point(_ app: XCUIApplication, in rect: CGRect,
                       x: CGFloat, y: CGFloat) -> XCUICoordinate {
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
            dx: rect.minX - app.frame.minX + rect.width * x,
            dy: rect.minY - app.frame.minY + rect.height * y))
    }

    private func sliderValue(_ slider: XCUIElement) throws -> Double {
        let value = try XCTUnwrap(slider.value as? String)
        guard let number = Double(value), number.isFinite
        else { throw failure("The native Size slider did not expose its scalar value: \(value)") }
        return number
    }

    private func savedTrackLabels(in app: XCUIApplication) -> Set<String> {
        Set(app.buttons.matching(NSPredicate(format: "label MATCHES '.*Track [0-9]{3}.*'"))
            .allElementsBoundByIndex.map { $0.label })
    }

    private func leadingNumber(_ value: String) -> Double {
        Double(value.prefix { $0.isNumber || $0 == "." }) ?? -1
    }

    private func wait(_ message: String, timeout: TimeInterval,
                      until condition: () -> Bool) throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            settle(0.15)
        }
        throw failure(message)
    }

    private func settle(_ seconds: TimeInterval) {
        _ = XCTWaiter.wait(for: [expectation(description: "native UI settle")], timeout: seconds)
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func failure(_ message: String) -> NSError {
        XCTFail(message)
        return NSError(domain: "IPadWorkshopReleaseUITests", code: 1,
                       userInfo: [NSLocalizedDescriptionKey: message])
    }
}
#endif
