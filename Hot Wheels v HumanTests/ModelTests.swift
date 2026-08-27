//
//  ModelTests.swift
//  Hot Wheels v HumanTests
//
//  Codable round-trips for every wire message, PRD §4 JSON compatibility,
//  and raw-value stability (renaming a case = breaking the wire protocol).
//

import Foundation
import Testing
@testable import Hot_Wheels_v_Human

struct ModelTests {

    static let player = PlayerInfo(id: UUID(), name: "Kid", deviceRole: .iPad)
    static let car = CarDesign(
        id: UUID(), name: "Lightning", chassis: .superlightDrift, tires: .slickRacing,
        paint: PaintSpec(colorHex: "#FF6600", finish: .metallic))
    static let allMessages: [GameMessage] = [
        .hello(player, protocolVersion: gameProtocolVersion),
        .trackBlueprint(.demo, rank: 0, ownerID: player.id),
        .trackBlueprint(.demo, rank: nil, ownerID: nil),
        .carDesign(car, ownerID: player.id),
        .carDesign(car, ownerID: nil),
        .matchConfig(MatchConfig(mode: .twoPlayer, laps: 3)),
        .readyState(playerID: player.id, ready: true),
        .raceEvent(.countdownTick(3)),
        .raceEvent(.carDestroyed(playerID: player.id)),
        .raceEvent(.respawned(playerID: player.id)),
        .raceEvent(.finished(playerID: player.id, time: 42.5)),
        .raceEvent(.blueprintRejected(reason: "needs a start gate")),
        .boost(playerID: player.id, token: UUID()),
        .reactionCam(playerID: player.id, on: true),
        .trackVisibility(.hideAll),
        .raceSnapshot(RaceSnapshot(raceClock: 12.3, phase: .racing, cars: [
            CarSnapshot(playerID: player.id, progress: 0.5, speed: 2.1,
                        boostMeter: 0.8, livesLeft: 4, lane: 0),
        ])),
        .raceSnapshot(RaceSnapshot(raceClock: 1, phase: .racing, cars: [],
                                   trackVisibility: .all)),
    ]

    @Test func everyMessageCaseRoundTrips() throws {
        for message in Self.allMessages {
            let decoded = try GameMessage.decoded(from: message.encoded())
            #expect(decoded == message)
        }
    }

    /// The switch is additive: a snapshot from a peer that predates it
    /// still decodes, and reads as "no opinion" rather than a default that
    /// would stomp what the host is actually showing.
    @Test func oldSnapshotWithoutTrackVisibilityStillDecodes() throws {
        let json = """
        { "raceSnapshot": { "_0": {
            "raceClock": 3.5, "phase": "racing", "cars": [] } } }
        """
        let decoded = try GameMessage.decoded(from: Data(json.utf8))
        guard case .raceSnapshot(let snap) = decoded else {
            Issue.record("decoded as \(decoded)")
            return
        }
        #expect(snap.trackVisibility == nil)
    }

    @Test func oldCarDesignMessageWithoutOwnerIDStillDecodes() throws {
        // Pre-2P peers encode carDesign without the ownerID key.
        let json = """
        { "carDesign": { "_0": {
            "id": "6BE2A5D4-6A00-4C4A-8B49-586E6E355A93", "name": "Old Timer",
            "chassis": "heavyMuscle", "tires": "standard",
            "paint": { "colorHex": "#FF6600", "finish": "glossy" } } } }
        """
        let decoded = try GameMessage.decoded(from: Data(json.utf8))
        guard case .carDesign(let design, let ownerID) = decoded else {
            Issue.record("decoded as \(decoded)")
            return
        }
        #expect(design.name == "Old Timer")
        #expect(ownerID == nil)
    }

    @Test func oldTrackBlueprintMessageWithoutRankStillDecodes() throws {
        // Pre-track-draft peers encode trackBlueprint with the blueprint only.
        let json = """
        { "trackBlueprint": { "_0": {
            "trackId": "6BE2A5D4-6A00-4C4A-8B49-586E6E355A93", "lanes": 2,
            "segments": [ { "index": 0, "type": "startGate" } ] } } }
        """
        let decoded = try GameMessage.decoded(from: Data(json.utf8))
        guard case .trackBlueprint(let bp, let rank, let ownerID) = decoded else {
            Issue.record("decoded as \(decoded)")
            return
        }
        #expect(bp.lanes == 2)
        #expect(rank == nil)
        #expect(ownerID == nil)
    }

    @Test func blueprintDecodesPRDSampleJSON() throws {
        // PRD §4 sample, with a concrete UUID.
        let json = """
        { "trackId": "6BE2A5D4-6A00-4C4A-8B49-586E6E355A93", "lanes": 2,
          "segments": [
            { "index": 0, "type": "startGate" },
            { "index": 1, "type": "straight" },
            { "index": 2, "type": "loop" },
            { "index": 3, "type": "curve90R" },
            { "index": 4, "type": "finishGate" } ] }
        """
        let blueprint = try JSONDecoder().decode(TrackBlueprint.self, from: Data(json.utf8))
        #expect(blueprint.lanes == 2)
        #expect(blueprint.segments.map(\.type) ==
                [.startGate, .straight, .loop, .curve90R, .finishGate])
        // No worldTheme key (pre-worlds peer) → nil, auto-pick.
        #expect(blueprint.worldTheme == nil)
        // And back out with identical shape.
        let reencoded = try JSONDecoder().decode(
            TrackBlueprint.self, from: JSONEncoder().encode(blueprint))
        #expect(reencoded == blueprint)
    }

    @Test func blueprintWorldThemeRoundTrips() throws {
        var blueprint = TrackBlueprint.demo
        blueprint.worldTheme = "city"
        blueprint.scenery = [
            SceneryItem(model: "city-house-a", x: 1.5, z: -2, yaw: .pi / 2),
            SceneryItem(model: "pirate-ship-large", x: -3, z: 0, yaw: 0),
        ]
        let reencoded = try JSONDecoder().decode(
            TrackBlueprint.self, from: JSONEncoder().encode(blueprint))
        #expect(reencoded.worldTheme == "city")
        #expect(reencoded.scenery?.count == 2)
        #expect(reencoded == blueprint)
    }

    /// Portal exit coords are additive optionals on SegmentSpec — old
    /// JSON without them decodes, new JSON round-trips them.
    @Test func portalCoordsRideTheWireAdditively() throws {
        let legacy = try JSONDecoder().decode(
            SegmentSpec.self,
            from: Data(#"{ "index": 1, "type": "straight" }"#.utf8))
        #expect(legacy.portalX == nil && legacy.portalZ == nil)

        var blueprint = TrackBlueprint.demo
        blueprint.segments = [
            SegmentSpec(index: 0, type: .startGate),
            SegmentSpec(index: 1, type: .portalIn),
            SegmentSpec(index: 2, type: .portalOut, portalX: 4.2, portalZ: -1.4),
            SegmentSpec(index: 3, type: .finishGate),
        ]
        let reencoded = try JSONDecoder().decode(
            TrackBlueprint.self, from: JSONEncoder().encode(blueprint))
        #expect(reencoded == blueprint)
        #expect(reencoded.segments[2].portalX == 4.2)
    }

    @Test func wireRawValuesAreStable() {
        #expect(PieceType.allCases.map(\.rawValue) == [
            "startGate", "finishGate", "straight", "curve90L", "curve90R",
            "curveLarge", "hillUp", "hillDown", "bump", "loop", "rampJump",
            "portalIn", "portalOut",
        ])
        #expect(ChassisClass.allCases.map(\.rawValue) ==
                ["heavyMuscle", "balancedFormula", "superlightDrift"])
        #expect(TireType.allCases.map(\.rawValue) ==
                ["standard", "slickRacing", "grippyOffroad"])
        #expect(PaintFinish.allCases.map(\.rawValue) ==
                ["metallic", "glossy", "matte", "sparkle"])
        #expect(DeviceRole.iPad.rawValue == "iPad" && DeviceRole.tv.rawValue == "tv")
    }

    // MARK: Customization graphics (G1)

    @Test func oldCarDesignJSONStillDecodes() throws {
        // A pre-G1 saved design: no partColors key at all.
        let json = """
        { "id": "6BE2A5D4-6A00-4C4A-8B49-586E6E355A93", "name": "Old Timer",
          "chassis": "heavyMuscle", "tires": "standard",
          "paint": { "colorHex": "#FF6600", "finish": "glossy" } }
        """
        let design = try JSONDecoder().decode(CarDesign.self, from: Data(json.utf8))
        #expect(design.partColors == nil)
        #expect(design.paint.colorHex == "#FF6600")
    }

    @Test func partColorsAndSparkleRoundTrip() throws {
        var design = Self.car
        design.partColors = [CarPaintSlot.wheels: "#1C1C1E"]
        design.paint.finish = .sparkle
        let decoded = try JSONDecoder().decode(
            CarDesign.self, from: JSONEncoder().encode(design))
        #expect(decoded == design)
    }

    @Test func paintSlotMapsKenneyMeshNames() {
        for wheel in ["wheel_fl", "wheel_fr", "wheel_bl", "wheel_br", "wheel_back"] {
            #expect(CarPaintSlot.slot(forPartName: wheel) == CarPaintSlot.wheels)
        }
        for body in ["body", "vehicle_racer", "vehicle_speedster",
                     "Human_CylinderMesh_003", "anything_else"] {
            #expect(CarPaintSlot.slot(forPartName: body) == CarPaintSlot.body)
        }
    }

    @Test func chassisAndTiresExposeTuningValues() {
        // Exact numbers live in RaceTuning and get tuned freely; the stable
        // invariants are the wiring and the relative ordering.
        #expect(ChassisClass.heavyMuscle.mass > ChassisClass.balancedFormula.mass)
        #expect(ChassisClass.balancedFormula.mass > ChassisClass.superlightDrift.mass)
        #expect(ChassisClass.superlightDrift.modelName == "vehicle-speedster")
        #expect(TireType.slickRacing.staticFriction < TireType.standard.staticFriction)
        #expect(TireType.standard.staticFriction < TireType.grippyOffroad.staticFriction)
        #expect(TireType.slickRacing.restitution < TireType.grippyOffroad.restitution)
    }
}
