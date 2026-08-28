//
//  TunnelUITests.swift
//  Hot Wheels v HumanUITests
//
//  Screenshot drill for the tunnel: build a track that dives under the
//  ground and climbs back out, and look at what you get — an arch at
//  each mouth and lamps strung down the buried run.
//
//  Tapping the shelf is `PieceShelf.swift`'s job — the hill cards sit
//  off the right-hand end of a ScrollView and need dragging into view
//  first.
//

import XCTest

final class TunnelUITests: XCTestCase {

    /// Dive, run buried, climb back out — the shape the tunnel dressing
    /// is built for. Two hillDowns make it a two-level dig, so the dirt
    /// mounded over the buried run is deep enough to read as a hill.
    @MainActor
    func testTunnelHasAMouthAtEachEndAndLampsBetween() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--trackbuilder"]
        app.launch()

        tapPieceCard("Straight", in: app)
        tapPieceCard("Hill Down", in: app)
        tapPieceCard("Hill Down", in: app)
        for _ in 0..<4 { tapPieceCard("Straight", in: app) }
        tapPieceCard("Hill Up", in: app)
        tapPieceCard("Hill Up", in: app)
        tapPieceCard("Straight", in: app)
        sleep(3)

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "tunnel-builder"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
