#if os(tvOS)
import XCTest

/// All interaction goes through the real Siri Remote and the TV focus engine.
/// Deep links isolate screens, but the home, car and racer cases start at the
/// normal local-profile gate. No saved data or view-model state is injected.
@MainActor
final class TVRemoteUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testTV01WorkshopRoutesAndLocalProfile() throws {
        let app = launch()
        screenshot("TV01 - Choose a local player")
        _ = try enterWorkshop(app)
        screenshot("TV02 - Apple TV workshop")
        for tile in ["quickPlay", "car", "track", "robot", "garage", "twoPlayer", "racers", "iPad"] {
            XCTAssertTrue(app.buttons["tv-home-\(tile)"].exists, "The TV workshop is missing \(tile)")
        }

        try select(app.buttons["tv-home-track"], in: app)
        try expect("Build a Track must open the native TV builder", in: app) {
            app.buttons["tvTrackAppend-straight"].exists
        }
        try returnHome(app)
        try select(app.buttons["tv-home-robot"], in: app)
        for difficulty in ["Easy", "Medium", "Hard"] {
            XCTAssertTrue(button(difficulty, in: app).exists)
        }
        try returnHome(app)
        try select(app.buttons["tv-home-iPad"], in: app)
        try expect("The TV must advertise its local iPad race lobby", in: app) {
            app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Grab an iPad'")).firstMatch.exists
        }
        screenshot("TV03 - Race with a nearby iPad")
        try returnHome(app)
        try select(app.buttons["tv-home-quickPlay"], in: app)
        try expect("Quick Play must create a playable local race", timeout: 30, in: app) {
            app.buttons["race-camera"].exists
        }
        XCUIRemote.shared.press(.menu)
        try expect("Menu must return Quick Play to the workshop", in: app) {
            app.buttons["tv-home-quickPlay"].exists
        }
    }

    func testTV02CarToolsSaveAndColdGarageReopen() throws {
        let app = launch()
        _ = try enterWorkshop(app)
        try select(app.buttons["tv-home-garage"], in: app)
        let oldCars = identifiers(prefix: "tv-garage-car-", in: app)
        try returnHome(app)
        try select(app.buttons["tv-home-car"], in: app)

        try select(app.buttons["tv-car-tab-paint"], in: app)
        try select(button("Color, Red", in: app), in: app)
        XCTAssertTrue(button("Color, Red", in: app).isSelected, "Selecting red must change the car paint")
        try select(button("Metallic", in: app), in: app)
        XCTAssertTrue(button("Metallic", in: app).isSelected)
        screenshot("TV04 - Paint a car with the remote")

        try select(app.buttons["tv-car-tab-livery"], in: app)
        try select(button("Flames", in: app), in: app)
        try expect("Choosing a livery must reveal its editable pattern size", in: app) {
            button("Increase Pattern Size", in: app).exists
        }
        try select(button("Increase Pattern Size", in: app), in: app)
        XCTAssertTrue(app.staticTexts["Pattern Size, 1.1×"].exists)
        screenshot("TV05 - Flame livery and its inspector")

        try select(app.buttons["tv-car-tab-stickers"], in: app)
        try select(button("Star", in: app), in: app)
        try select(app.buttons["tv-add-sticker"], in: app)
        XCTAssertTrue(app.staticTexts["Sticker, 1 / 1"].exists, "Add Sticker must create a real placement")
        try select(button("Increase Position Across", in: app), in: app)
        XCTAssertTrue(app.staticTexts["Position Across, 52%"].exists)
        screenshot("TV06 - Place and move a sticker")

        try select(app.buttons["tv-car-tab-draw"], in: app)
        try select(app.buttons["tv-drawing-pen"], in: app)
        XCTAssertTrue(app.buttons["tv-drawing-pen"].label.contains("Pen Down"))
        try select(button("Right", in: app), in: app)
        try select(button("Down", in: app), in: app)
        try select(app.buttons["tv-drawing-pen"], in: app)
        XCTAssertTrue(app.buttons["tv-drawing-pen"].label.contains("Pen Up"))
        screenshot("TV07 - Draw on the car without touch")

        try select(saveButton("Save Car", in: app), in: app)
        try expect("Save Car must report a successful persistent save", in: app) {
            saveButton("Save Car", in: app).label.contains("Saved")
        }
        try returnHome(app)
        try select(app.buttons["tv-home-garage"], in: app)
        let newCars = identifiers(prefix: "tv-garage-car-", in: app).subtracting(oldCars)
        try require(newCars.count == 1, "Save must create exactly one new personal garage car, found \(newCars)", in: app)
        let savedID = try XCTUnwrap(newCars.first)
        screenshot("TV08 - Saved car in the garage")

        app.terminate()
        app.launchArguments = ["--garage"]
        app.launch()
        try select(app.buttons[savedID], in: app)
        try select(app.buttons["tv-garage-edit-car"], in: app)
        try select(app.buttons["tv-car-tab-paint"], in: app)
        XCTAssertTrue(button("Color, Red", in: app).isSelected, "Body paint must survive a cold launch")
        XCTAssertTrue(button("Metallic", in: app).isSelected, "Paint finish must survive a cold launch")
        try select(app.buttons["tv-car-tab-livery"], in: app)
        XCTAssertTrue(app.staticTexts["Pattern Size, 1.1×"].exists, "Livery size must survive a cold launch")
        try select(app.buttons["tv-car-tab-stickers"], in: app)
        XCTAssertTrue(app.staticTexts["Sticker, 1 / 1"].exists)
        XCTAssertTrue(app.staticTexts["Position Across, 52%"].exists, "Sticker position must survive a cold launch")
    }

    func testTV03GhostTrackWorldSaveAndColdLibraryLoad() throws {
        let app = launch(["--trackbuilder"])
        try require(button("Save a copy", in: app).waitForExistence(timeout: 8), "The track footer must expose Save a copy", in: app)
        XCTAssertFalse(button("Save a copy", in: app).isEnabled, "An unfinished track must not be saved as raceable")
        try select(app.buttons["tvTrackGhostMode"], in: app)
        XCTAssertTrue(app.buttons["tvTrackGhostMode"].label.contains("On"))
        try select(app.buttons["tvTrackAppend-straight"], in: app)
        try select(app.buttons["tvTrackGhostMode"], in: app)
        for _ in 0..<3 { try select(app.buttons["tvTrackAppend-straight"], in: app) }
        try select(app.buttons["tvTrackAppend-finishGate"], in: app)
        XCTAssertTrue(app.staticTexts["6 pieces"].exists)
        XCTAssertFalse(app.buttons["tvTrackAppend-straight"].isEnabled, "A finished sprint must reject another piece")
        screenshot("TV09 - Build a finished track with a ghost stretch")

        try select(button("Worlds", in: app), in: app)
        XCTAssertTrue(button("Worlds", in: app).isSelected)
        try select(app.buttons["tvTrackWorld-candy"], in: app)
        try select(app.buttons["tvTrackEmptyWorld"], in: app)
        XCTAssertTrue(app.buttons["tvTrackEmptyWorld"].label.contains("On"))
        screenshot("TV10 - Choose a world and its scenery mode")
        try select(button("Camera", in: app), in: app)
        try select(app.buttons["tvTrackOrbitLeft"], in: app)
        try select(app.buttons["tvTrackZoomIn"], in: app)
        try select(app.buttons["tvTrackPanRight"], in: app)
        screenshot("TV11 - Look around the track with the remote")

        try select(button("Save a copy", in: app), in: app)
        try expect("Saving must report the saved track name", in: app) {
            status(prefix: "Saved ", in: app).exists
        }
        let savedName = String(status(prefix: "Saved ", in: app).label.dropFirst("Saved ".count))
        try select(button("Library", in: app), in: app)
        let savedTrack = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'tvTrackLoad-' AND label CONTAINS %@", savedName)).firstMatch
        try require(savedTrack.exists, "The saved track must appear in the library", in: app)
        let savedID = savedTrack.identifier
        screenshot("TV14 - Saved tracks and starter tracks")
        app.terminate()
        app.launchArguments = ["--trackbuilder"]
        app.launch()
        try select(button("Library", in: app), in: app)
        try select(app.buttons[savedID], in: app)
        XCTAssertTrue(app.staticTexts["6 pieces"].exists, "Loading must restore the complete saved path")
        XCTAssertTrue(app.staticTexts["Loaded \(savedName)"].exists)
        try select(button("Worlds", in: app), in: app)
        XCTAssertTrue(app.buttons["tvTrackEmptyWorld"].label.contains("On"), "World options must survive a cold launch")
        try select(button("Pieces", in: app), in: app)
        try select(app.buttons["tvTrackPiece-1"], in: app)
        XCTAssertEqual(app.buttons["tvTrackSelectedGhost"].label, "Make solid", "The saved ghost flag must load on its original piece")
    }

    func testTV04PortalAndDecorationUseDirectionalCursor() throws {
        let app = launch(["--trackbuilder"])
        try select(app.buttons["tvTrackAppend-straight"], in: app)
        try select(app.buttons["tvTrackAppendPortal"], in: app)
        try require(button("Save a copy", in: app).waitForExistence(timeout: 8), "The portal editor must retain Save a copy", in: app)
        XCTAssertFalse(button("Save a copy", in: app).isEnabled, "A pending portal exit must block saving")
        try select(app.buttons["tvTrackMoveCursor"], in: app)
        let cursor = app.buttons["tvTrackRemoteCursor"]
        try focus(cursor, in: app)
        XCUIRemote.shared.press(.left)
        XCUIRemote.shared.press(.left)
        XCUIRemote.shared.press(.down)
        XCUIRemote.shared.press(.down)
        XCTAssertTrue(cursor.hasFocus, "Directional cursor input must keep focus on Place here")
        screenshot("TV13 - Position a portal exit with the remote")
        XCUIRemote.shared.press(.select)
        try expect("Select must place the portal exit", in: app) {
            app.staticTexts["Portal exit placed"].exists
        }
        XCTAssertTrue(app.staticTexts["4 pieces"].exists, "Portal placement must retain its paired entry and exit")

        try select(button("Decorate", in: app), in: app)
        try select(app.buttons["tvTrackDecoration-street-straight"], in: app)
        try select(app.buttons["tvTrackMoveCursor"], in: app)
        try focus(cursor, in: app)
        XCUIRemote.shared.press(.left)
        XCUIRemote.shared.press(.down)
        XCTAssertTrue(cursor.hasFocus)
        XCUIRemote.shared.press(.select)
        try expect("The decoration must be placed, rather than only selected in the box", in: app) {
            app.staticTexts["Decoration placed"].exists
        }
        try select(app.buttons["tvTrackRotateDecoration"], in: app)
        screenshot("TV12 - Place and rotate world decorations")
        try select(app.buttons["tvTrackCancelDecoration"], in: app)
        XCTAssertTrue(app.buttons["tvTrackPlacedDecoration-0"].exists)
        try select(app.buttons["tvTrackPlacedDecoration-0"], in: app)
        try select(app.buttons["tvTrackRemoveDecoration"], in: app)
        XCTAssertFalse(app.buttons["tvTrackPlacedDecoration-0"].exists, "Removing the selected decoration must update the placed list")
    }

    func testTV05UnsavedTrackPreviewReturnsToTheSameDraft() throws {
        let app = launch(["--trackbuilder"])
        for _ in 0..<4 { try select(app.buttons["tvTrackAppend-straight"], in: app) }
        try select(app.buttons["tvTrackAppend-finishGate"], in: app)
        try select(button("Race it!", in: app), in: app)
        try expect("Race it must present the draft race without saving", timeout: 30, in: app) {
            app.buttons["race-preview-close"].exists && app.buttons["race-camera"].exists
        }
        screenshot("TV15 - Race the unsaved track")
        XCUIRemote.shared.press(.menu)
        try expect("Menu must close the preview and retain the track draft", in: app) {
            button("Race it!", in: app).exists && app.staticTexts["6 pieces"].exists
        }
        XCTAssertTrue(button("Save a copy", in: app).isEnabled)
        XCTAssertFalse(status(prefix: "Saved ", in: app).exists, "Previewing a track must not silently save it")
    }

    func testTV06RacerWardrobeSaveAndColdReopen() throws {
        let app = launch()
        let profileID = try enterWorkshop(app)
        try select(app.buttons["tv-home-racers"], in: app)
        let oldRacers = identifiers(prefix: "tv-racer-card-", in: app)
        try select(button("Make a New Racer", in: app), in: app)
        try select(button("Boy", in: app), in: app)
        XCTAssertTrue(button("Boy", in: app).isSelected)
        try select(app.buttons["tv-racer-tab-hair"], in: app)
        try select(button("Crop", in: app), in: app)
        XCTAssertTrue(button("Crop", in: app).isSelected)
        try select(app.buttons["tv-racer-tab-clothes"], in: app)
        try select(button("Shirt, Red", in: app), in: app)
        XCTAssertTrue(button("Shirt, Red", in: app).isSelected)
        try select(app.buttons["tv-racer-tab-extras"], in: app)
        try select(button("Cap", in: app), in: app)
        XCTAssertTrue(button("Cap", in: app).isSelected)
        screenshot("TV16 - Dress and save a personal racer")
        try select(saveButton("Save Racer", in: app), in: app)
        try expect("Save Racer must report a successful save", in: app) {
            saveButton("Save Racer", in: app).label.contains("Saved")
        }
        XCUIRemote.shared.press(.menu)
        try expect("Menu must return the racer editor to My Racers", in: app) {
            button("Make a New Racer", in: app).exists
        }
        let newRacers = identifiers(prefix: "tv-racer-card-", in: app).subtracting(oldRacers)
        try require(newRacers.count == 1, "Saving must add one personal racer, found \(newRacers)", in: app)
        let savedID = try XCTUnwrap(newRacers.first)
        app.terminate()
        app.launchArguments = []
        app.launch()
        _ = try enterWorkshop(app, profileID: profileID)
        try select(app.buttons["tv-home-racers"], in: app)
        try select(app.buttons[savedID], in: app)
        try select(app.buttons["tv-racer-edit"], in: app)
        XCTAssertTrue(button("Boy", in: app).isSelected)
        try select(app.buttons["tv-racer-tab-hair"], in: app)
        XCTAssertTrue(button("Crop", in: app).isSelected)
        try select(app.buttons["tv-racer-tab-clothes"], in: app)
        XCTAssertTrue(button("Shirt, Red", in: app).isSelected)
        try select(app.buttons["tv-racer-tab-extras"], in: app)
        XCTAssertTrue(button("Cap", in: app).isSelected, "Saved wardrobe choices must survive a cold launch")
    }

    func testTV07TwoPlayerDraftsStayIndependentAndRaceTogether() throws {
        let app = launch()
        _ = try enterWorkshop(app)
        try select(app.buttons["tv-home-twoPlayer"], in: app)
        try select(app.buttons["tv-car-tab-paint"], in: app)
        try select(button("Color, Red", in: app), in: app)
        try select(app.buttons["tv-two-player-next"], in: app)
        try select(app.buttons["tv-car-tab-paint"], in: app)
        XCTAssertFalse(button("Color, Red", in: app).isSelected, "Player 2 must have a separate car draft")
        try select(button("Color, Blue", in: app), in: app)
        try select(button("Player 1", in: app), in: app)
        try select(app.buttons["tv-car-tab-paint"], in: app)
        XCTAssertTrue(button("Color, Red", in: app).isSelected, "Switching benches must retain Player 1's paint")
        screenshot("TV17 - Two players build their own cars")
        try select(app.buttons["tv-two-player-next"], in: app)
        try select(app.buttons["tv-car-tab-paint"], in: app)
        XCTAssertTrue(button("Color, Blue", in: app).isSelected, "Switching benches must retain Player 2's paint")
        try select(app.buttons["tv-two-player-next"], in: app)
        try expect("Race Together must create controls for both local players", timeout: 30, in: app) {
            app.buttons.matching(identifier: "race-boost").count == 2
        }
        screenshot("TV18 - Race two local players on Apple TV")
        XCUIRemote.shared.press(.menu)
        try expect("Menu must return Race Together to both retained drafts", in: app) {
            app.buttons["tv-two-player-next"].exists && !app.buttons["race-preview-close"].exists
        }
        try select(app.buttons["tv-car-tab-paint"], in: app)
        XCTAssertTrue(button("Color, Blue", in: app).isSelected)
        try select(app.buttons["tv-two-player-next"], in: app)
        try expect("Starting Race Together again must create a fresh live rig", timeout: 30, in: app) {
            app.buttons.matching(identifier: "race-boost").count == 2
        }
    }

    func testTV08BoostChargesAndTogglesWithSelectAndPlayPause() throws {
        let app = launch(["--stress-track"])
        let boost = app.buttons["race-boost"].firstMatch
        try focus(boost, in: app)
        try expect("The real boost meter must charge to at least 100 percent during the race", timeout: 25, in: app) {
            boost.exists && boostPercent(boost) >= 100
        }
        try focus(boost, in: app)
        XCUIRemote.shared.press(.select)
        try expect("Select must start a held remote boost", in: app) { boost.exists && boost.label == "Stop boost" }
        let charged = boostPercent(boost)
        try expect("A held boost must consume its real meter", timeout: 3, in: app) {
            boost.exists && boostPercent(boost) < charged
        }
        screenshot("TV19 - Siri Remote boost during a real race")
        XCTAssertTrue(boost.hasFocus)
        XCUIRemote.shared.press(.playPause)
        try expect("Play Pause must stop the boost while the control remains focused", in: app) {
            boost.exists && boost.label == "Boost"
        }
        let reaction = app.buttons["race-reaction-cam"].firstMatch
        try select(reaction, in: app)
        XCTAssertEqual(reaction.value as? String, "On")
        try select(reaction, in: app)
        XCTAssertEqual(reaction.value as? String, "Off")
    }

    func testTV09CameraRadioAndVolumeWithRemoteFocus() throws {
        let app = launch(["--stress-track"])
        let camera = app.buttons["race-camera"]
        try focus(camera, in: app)
        XCTAssertEqual(camera.value as? String, "Driver View")
        XCUIRemote.shared.press(.select)
        try expect("The camera toggle must switch to chase view", in: app) { camera.value as? String == "Chase Cam" }
        screenshot("TV20 - Chase camera and race world")
        try select(camera, in: app)
        try select(app.buttons["race-radio-jazz"], in: app)
        XCTAssertTrue(app.buttons["race-radio-jazz"].isSelected)
        try select(app.buttons["race-volume-down"], in: app)
        XCTAssertEqual(app.buttons["race-volume-down"].value as? String, "90%", "Volume down must change the actual music level")
        screenshot("TV21 - Driver view with the TV radio")
        try select(app.buttons["race-volume-up"], in: app)
        XCTAssertEqual(app.buttons["race-volume-up"].value as? String, "100%")
        let power = app.buttons["race-radio-power"]
        try select(power, in: app)
        XCTAssertEqual(power.value as? String, "Off")
        XCTAssertFalse(app.buttons["race-radio-jazz"].isSelected)
        try select(power, in: app)
        XCTAssertEqual(power.value as? String, "On")
        XCTAssertTrue(app.buttons["race-radio-jazz"].isSelected, "Turning the radio back on must retain its station")
    }

    func testTV10RobotResultsAndRemoteRematch() throws {
        let app = launch(["--robot-race"])
        let rematch = app.buttons["race-rematch"]
        try expect("A real robot race must reach results", timeout: 90, in: app) { rematch.exists }
        XCTAssertTrue(app.staticTexts["Top speed"].exists, "Results must include the actual race statistics")
        screenshot("TV22 - Robot race results")
        try select(rematch, in: app)
        try expect("Rematch must leave results and start another race", timeout: 25, in: app) {
            !rematch.exists && app.buttons["race-boost"].exists
        }
    }

    private func launch(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        return app
    }

    @discardableResult
    private func enterWorkshop(_ app: XCUIApplication, profileID: String? = nil) throws -> String {
        try expect("A normal launch must show the local profile picker", in: app) {
            app.buttons["tv-new-profile"].exists
        }
        let profiles = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'tv-profile-pick-'"))
        if let profileID {
            try select(app.buttons[profileID], in: app)
        } else if profiles.count > 0 {
            let chosen = profiles.firstMatch.identifier
            try select(app.buttons[chosen], in: app)
            try expect("Choosing a profile must open the TV workshop", in: app) { app.buttons["tv-home-car"].exists }
            return chosen
        } else {
            try select(app.buttons["tv-new-profile"], in: app)
            try select(app.buttons["tv-profile-create"], in: app)
        }
        try expect("Creating or choosing a profile must open the TV workshop", in: app) { app.buttons["tv-home-car"].exists }
        if let profileID { return profileID }
        // Learn the actual newly persisted identifier through the normal picker.
        try select(app.buttons["tv-switch-profile"], in: app)
        let created = profiles.firstMatch
        try require(created.waitForExistence(timeout: 5), "The new profile must persist in the local picker", in: app)
        let createdID = created.identifier
        try select(created, in: app)
        try expect("The persisted profile must reopen its workshop", in: app) { app.buttons["tv-home-car"].exists }
        return createdID
    }

    private func returnHome(_ app: XCUIApplication) throws {
        XCUIRemote.shared.press(.menu)
        try expect("Menu must return to the Apple TV workshop", in: app) { app.buttons["tv-home-car"].exists }
    }

    private func button(_ label: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    private func saveButton(_ unsavedLabel: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@ OR label == 'Saved!'", unsavedLabel)).firstMatch
    }

    private func status(prefix: String, in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    private func identifiers(prefix: String, in app: XCUIApplication) -> Set<String> {
        Set(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).allElementsBoundByIndex.map(\.identifier))
    }

    private func boostPercent(_ element: XCUIElement) -> Int {
        Int((element.value as? String ?? "").split(separator: " ").first ?? "") ?? -1
    }

    private func select(_ target: XCUIElement, in app: XCUIApplication,
                        file: StaticString = #filePath, line: UInt = #line) throws {
        try focus(target, in: app, file: file, line: line)
        try require(target.isEnabled && target.hasFocus,
                    "Select requires an enabled, focused target: \(describe(target))", in: app, file: file, line: line)
        XCUIRemote.shared.press(.select)
    }

    /// Geometry suggests the next direction. Tracking tried edges lets the
    /// remote escape a focus section when the shortest route stalls or loops.
    /// Every attempt is bounded and a failure includes the route and UI tree.
    private func focus(_ target: XCUIElement, in app: XCUIApplication,
                       file: StaticString = #filePath, line: UInt = #line) throws {
        try require(target.waitForExistence(timeout: 8),
                    "The Siri Remote target must exist before navigation: \(target)", in: app, file: file, line: line)
        let deadline = Date().addingTimeInterval(35)
        var tried: [String: Set<Int>] = [:]
        var route: [String] = []
        var stalled = 0
        var previousKey: String?
        for _ in 0..<90 {
            if Date() > deadline { break }
            let targetSnapshot = try target.snapshot()
            if targetSnapshot.hasFocus { return }
            let focused = focusedControl(in: app)
            let key = focused.map(describeSnapshot) ?? "no focused button or text field"
            stalled = key == previousKey ? stalled + 1 : 0
            if stalled >= 4 { break }
            let directions: [XCUIRemote.Button]
            if let focused, valid(targetSnapshot.frame), valid(focused.frame) {
                directions = rankedDirections(from: focused.frame, to: targetSnapshot.frame)
            } else {
                directions = [.right, .down, .left, .up]
            }
            let used = tried[key, default: []]
            guard let direction = directions.first(where: { !used.contains(Int($0.rawValue)) }) else { break }
            tried[key, default: []].insert(Int(direction.rawValue))
            route.append("\(key) -> \(direction)")
            previousKey = key
            XCUIRemote.shared.press(direction)
            Thread.sleep(forTimeInterval: 0.12)
        }
        let trace = XCTAttachment(string: route.joined(separator: "\n") + "\n\n" + app.debugDescription)
        trace.name = "Siri Remote focus route and accessibility tree"
        trace.lifetime = .keepAlways
        add(trace)
        throw failure("Could not focus \(describe(target)). Final focus: \(focusedControl(in: app).map(describeSnapshot) ?? "none"). Attempted \(route.count) moves. Check directional focus sections and target visibility.", in: app, file: file, line: line)
    }

    private func focusedControl(in app: XCUIApplication) -> (any XCUIElementSnapshot)? {
        guard let tree = try? app.snapshot() else { return nil }
        return focusedControl(in: tree)
    }

    /// snapshot() is Apple's public XCUIElementSnapshotProviding API. Its
    /// local attribute reads share one AX request for the entire hierarchy,
    /// so finding focus does not re-query every individual control twice.
    private func focusedControl(in snapshot: any XCUIElementSnapshot) -> (any XCUIElementSnapshot)? {
        if (snapshot.elementType == .button || snapshot.elementType == .textField) && snapshot.hasFocus {
            return snapshot
        }
        for child in snapshot.children {
            if let focused = focusedControl(in: child) { return focused }
        }
        return nil
    }

    private func describeSnapshot(_ snapshot: any XCUIElementSnapshot) -> String {
        // An ancestor identifier can be shared by several real SwiftUI
        // buttons. Include the label so those buttons remain distinct nodes.
        "\(snapshot.identifier) | \(snapshot.label) at \(snapshot.frame)"
    }

    private func rankedDirections(from current: CGRect, to target: CGRect) -> [XCUIRemote.Button] {
        let dx = target.midX - current.midX
        let dy = target.midY - current.midY
        let horizontal: XCUIRemote.Button = dx >= 0 ? .right : .left
        let vertical: XCUIRemote.Button = dy >= 0 ? .down : .up
        let oppositeHorizontal: XCUIRemote.Button = dx >= 0 ? .left : .right
        let oppositeVertical: XCUIRemote.Button = dy >= 0 ? .up : .down
        let alignedRow = current.minY < target.maxY && target.minY < current.maxY
        let alignedColumn = current.minX < target.maxX && target.minX < current.maxX
        if alignedRow || (!alignedColumn && abs(dx) > abs(dy)) {
            return [horizontal, vertical, oppositeVertical, oppositeHorizontal]
        }
        return [vertical, horizontal, oppositeHorizontal, oppositeVertical]
    }

    private func valid(_ frame: CGRect) -> Bool {
        !frame.isEmpty && frame.minX.isFinite && frame.minY.isFinite && frame.maxX.isFinite && frame.maxY.isFinite
    }

    private func describe(_ element: XCUIElement) -> String {
        guard element.exists else { return "missing target \(element)" }
        return "\(element.identifier.isEmpty ? element.label : element.identifier) at \(element.frame)"
    }

    private func expect(_ message: String, timeout: TimeInterval = 6, in app: XCUIApplication,
                        file: StaticString = #filePath, line: UInt = #line,
                        condition: () -> Bool) throws {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if condition() { return }
            Thread.sleep(forTimeInterval: 0.15)
        } while Date() < deadline
        throw failure(message, in: app, file: file, line: line)
    }

    private func require(_ condition: Bool, _ message: String, in app: XCUIApplication,
                         file: StaticString = #filePath, line: UInt = #line) throws {
        if !condition { throw failure(message, in: app, file: file, line: line) }
    }

    private func failure(_ message: String, in app: XCUIApplication,
                         file: StaticString, line: UInt) -> TVRemoteFailure {
        screenshot("TV failure - \(message.prefix(100))")
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "TV accessibility tree at failure"
        tree.lifetime = .keepAlways
        add(tree)
        XCTFail(message, file: file, line: line)
        return TVRemoteFailure(message: message)
    }

    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

private struct TVRemoteFailure: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
}
#endif
