//
//  TwoPlayerCoordinationTests.swift
//  Hot Wheels v HumanTests
//
//  Two-iPad 2P rules (TWO-IPAD-2P.md): ownerID pairing, host-derived
//  mode, the 2-player cap, and captain track gating — everything short of
//  actually spawning a RealityKit race.
//

import Foundation
import Testing
@testable import Hot_Wheels_v_Human

private func player(_ name: String) -> PlayerInfo {
    PlayerInfo(id: UUID(), name: name, deviceRole: .iPad)
}

private func car(_ name: String) -> CarDesign {
    CarDesign(id: UUID(), name: name, chassis: .balancedFormula, tires: .standard,
              paint: PaintSpec(colorHex: "#FF6600", finish: .glossy))
}

struct RaceEntryPairingTests {

    @Test func ownedDesignsPairByOwnerNotArrivalOrder() {
        let (ava, ben) = (player("Ava"), player("Ben"))
        // Ben's design arrived FIRST — arrival order would cross the wires.
        let designs: [(owner: UUID?, design: CarDesign)] = [
            (ben.id, car("Ben's Bolt")), (ava.id, car("Ava's Arrow")),
        ]
        let result = RaceCoordinator.raceEntries(
            players: [ava, ben], designs: designs,
            config: MatchConfig(mode: .onePlayer, aiDifficulty: .medium))
        #expect(result.entries.count == 2)
        #expect(result.entries[0].0 == ava.id)
        #expect(result.entries[0].1.name == "Ava's Arrow")
        #expect(result.entries[1].0 == ben.id)
        #expect(result.entries[1].1.name == "Ben's Bolt")
    }

    @Test func twoHumansMeansTwoPlayerModeAndNoRobot() {
        let (ava, ben) = (player("Ava"), player("Ben"))
        let designs: [(owner: UUID?, design: CarDesign)] = [
            (ava.id, car("A")), (ben.id, car("B")),
        ]
        let result = RaceCoordinator.raceEntries(
            players: [ava, ben], designs: designs,
            config: MatchConfig(mode: .onePlayer, aiDifficulty: .hard))
        #expect(result.config.mode == .twoPlayer)
        #expect(result.config.aiDifficulty == nil)
        #expect(result.entries.count == 2)   // no robot third wheel
    }

    @Test func soloKeepsArrivalOrderFallbackAndRobot() {
        let kid = player("Kid")
        // Unowned designs: today's solo/Test Mode path (old peers too).
        let designs: [(owner: UUID?, design: CarDesign)] = [
            (nil, car("Mine")), (nil, car("Test B")),
        ]
        let result = RaceCoordinator.raceEntries(
            players: [kid], designs: designs,
            config: MatchConfig(mode: .onePlayer, aiDifficulty: .medium))
        // Kid gets the first design, the B car races controller-less,
        // and the robot still joins a 1-human race.
        #expect(result.entries[0].0 == kid.id)
        #expect(result.entries[0].1.name == "Mine")
        #expect(result.entries[1].0 == result.entries[1].1.id)
        #expect(result.entries.count == 3)
        #expect(result.entries[2].0 == AIRoster.playerID)
    }
}

@MainActor
struct TwoPlayerLobbyTests {

    /// Bounded wait for the coordinator's event task to drain the stream.
    private func settle(until condition: @autoclosure () -> Bool) async {
        for _ in 0..<2000 where !condition() {
            await Task.yield()
        }
    }

    @Test func thirdIPadIsKindlyCapped() async {
        let hub = LoopbackTransport.hub(playerCount: 3)
        let coordinator = RaceCoordinator(transport: hub.host)
        coordinator.start()
        for (i, transport) in hub.players.enumerated() {
            transport.start(role: .player)
            transport.send(.hello(player("Kid \(i + 1)"), protocolVersion: gameProtocolVersion),
                           reliably: true)
        }
        await settle(until: coordinator.lastRejection != nil)
        #expect(coordinator.players.count == 2)
        #expect(coordinator.lastRejection == "Two racers max — grab the next race!")
        coordinator.stop()
    }

    @Test func secondTrackCannotStompTheCaptains() async {
        let hub = LoopbackTransport.hub(playerCount: 2)
        let coordinator = RaceCoordinator(transport: hub.host)
        coordinator.start()
        let captainTrack = TrackBlueprint.presets[0].blueprint
        let rivalTrack = TrackBlueprint.presets[1].blueprint

        hub.players[0].start(role: .player)
        hub.players[1].start(role: .player)
        hub.players[0].send(.hello(player("Captain"), protocolVersion: gameProtocolVersion), reliably: true)
        hub.players[1].send(.hello(player("Second"), protocolVersion: gameProtocolVersion), reliably: true)
        hub.players[0].send(.trackBlueprint(captainTrack), reliably: true)
        hub.players[1].send(.trackBlueprint(rivalTrack), reliably: true)

        await settle(until: coordinator.players.count == 2)
        // Both readiness messages force the lobby to have processed
        // everything before we assert (readyState arrives after tracks).
        hub.players[0].send(.readyState(playerID: UUID(), ready: false), reliably: true)
        await settle(until: coordinator.lobbyBlueprintID == captainTrack.trackId)
        #expect(coordinator.lobbyBlueprintID == captainTrack.trackId)
        coordinator.stop()
    }
}
