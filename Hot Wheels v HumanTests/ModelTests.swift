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
        .trackBlueprint(.demo),
        .carDesign(car),
        .matchConfig(MatchConfig(mode: .twoPlayer, laps: 3)),
        .readyState(playerID: player.id, ready: true),
        .raceEvent(.countdownTick(3)),
        .raceEvent(.carDestroyed(playerID: player.id)),
        .raceEvent(.respawned(playerID: player.id)),
        .raceEvent(.finished(playerID: player.id, time: 42.5)),
        .raceEvent(.blueprintRejected(reason: "needs a start gate")),
        .boost(playerID: player.id, token: UUID()),
        .reactionCam(playerID: player.id, on: true),
        .raceSnapshot(RaceSnapshot(raceClock: 12.3, phase: .racing, cars: [
            CarSnapshot(playerID: player.id, progress: 0.5, speed: 2.1,
                        boostMeter: 0.8, livesLeft: 4, lane: 0),
        ])),
    ]

    @Test func everyMessageCaseRoundTrips() throws {
        for message in Self.allMessages {
            let decoded = try GameMessage.decoded(from: message.encoded())
            #expect(decoded == message)
        }
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
        // And back out with identical shape.
        let reencoded = try JSONDecoder().decode(
            TrackBlueprint.self, from: JSONEncoder().encode(blueprint))
        #expect(reencoded == blueprint)
    }

    @Test func wireRawValuesAreStable() {
        #expect(PieceType.allCases.map(\.rawValue) == [
            "startGate", "finishGate", "straight", "curve90L", "curve90R",
            "curveLarge", "hillUp", "hillDown", "bump", "loop", "rampJump",
        ])
        #expect(ChassisClass.allCases.map(\.rawValue) ==
                ["heavyMuscle", "balancedFormula", "superlightDrift"])
        #expect(TireType.allCases.map(\.rawValue) ==
                ["standard", "slickRacing", "grippyOffroad"])
        #expect(PaintFinish.allCases.map(\.rawValue) == ["metallic", "glossy", "matte"])
        #expect(DeviceRole.iPad.rawValue == "iPad" && DeviceRole.tv.rawValue == "tv")
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
