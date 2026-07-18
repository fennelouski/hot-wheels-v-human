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
        // Old-peer style: unranked, unowned tracks. First valid one wins.
        hub.players[0].send(.trackBlueprint(captainTrack, rank: nil, ownerID: nil), reliably: true)
        hub.players[1].send(.trackBlueprint(rivalTrack, rank: nil, ownerID: nil), reliably: true)

        await settle(until: coordinator.players.count == 2)
        // Both readiness messages force the lobby to have processed
        // everything before we assert (readyState arrives after tracks).
        hub.players[0].send(.readyState(playerID: UUID(), ready: false), reliably: true)
        await settle(until: coordinator.lobbyBlueprintID == captainTrack.trackId)
        #expect(coordinator.lobbyBlueprintID == captainTrack.trackId)
        coordinator.stop()
    }

    @Test func rankedDraftsFromBothPlayersLandInTheLobby() async {
        let hub = LoopbackTransport.hub(playerCount: 2)
        let coordinator = RaceCoordinator(transport: hub.host)
        coordinator.start()
        let (ava, ben) = (player("Ava"), player("Ben"))

        hub.players[0].start(role: .player)
        hub.players[1].start(role: .player)
        hub.players[0].send(.hello(ava, protocolVersion: gameProtocolVersion), reliably: true)
        hub.players[1].send(.hello(ben, protocolVersion: gameProtocolVersion), reliably: true)
        let avaPick = TrackBlueprint.presets[0].blueprint
        let benPick = TrackBlueprint.presets[1].blueprint
        hub.players[0].send(.trackBlueprint(avaPick, rank: 0, ownerID: ava.id), reliably: true)
        hub.players[1].send(.trackBlueprint(benPick, rank: 0, ownerID: ben.id), reliably: true)

        await settle(until: coordinator.pickCount(ava.id) == 1
                        && coordinator.pickCount(ben.id) == 1)
        #expect(coordinator.pickCount(ava.id) == 1)
        #expect(coordinator.pickCount(ben.id) == 1)
        // Captain (first hello) leads the draft.
        #expect(coordinator.lobbyBlueprintID == avaPick.trackId)
        coordinator.stop()
    }
}

struct TrackPlaylistTests {

    private func pick(_ owner: PlayerInfo?, _ rank: Int, _ presetIndex: Int)
        -> (owner: UUID?, rank: Int, blueprint: TrackBlueprint) {
        (owner: owner?.id, rank: rank, blueprint: TrackBlueprint.presets[presetIndex].blueprint)
    }

    @Test func draftAlternatesCaptainFirst() {
        let (ava, ben) = (player("Ava"), player("Ben"))
        // Deliberately shuffled arrival order; ranks decide, not arrival.
        let picks = [pick(ben, 1, 3), pick(ava, 0, 0), pick(ben, 0, 2),
                     pick(ava, 1, 1), pick(ava, 2, 4)]
        let series = RaceCoordinator.trackPlaylist(players: [ava, ben], picks: picks)
        // A1 B1 A2 B2 A3
        #expect(series.map(\.trackId) == [0, 2, 1, 3, 4].map {
            TrackBlueprint.presets[$0].blueprint.trackId
        })
    }

    @Test func duplicatePicksRaceOnce() {
        let (ava, ben) = (player("Ava"), player("Ben"))
        // Both kids love preset 0; Ben's next pick fills the slot instead.
        let picks = [pick(ava, 0, 0), pick(ben, 0, 0), pick(ben, 1, 1)]
        let series = RaceCoordinator.trackPlaylist(players: [ava, ben], picks: picks)
        #expect(series.map(\.trackId) == [0, 1].map {
            TrackBlueprint.presets[$0].blueprint.trackId
        })
    }

    @Test func draftCapsAtSeriesLength() {
        let ava = player("Ava")
        let picks = (0..<6).map { pick(ava, $0, $0) }
        let series = RaceCoordinator.trackPlaylist(players: [ava], picks: picks)
        #expect(series.count == RaceTuning.raceSeriesLength)
        #expect(series.first?.trackId == TrackBlueprint.presets[0].blueprint.trackId)
    }

    @Test func unownedOldPeerPicksStillDraft() {
        let series = RaceCoordinator.trackPlaylist(players: [player("Old iPad")],
                                                   picks: [pick(nil, 0, 0)])
        #expect(series.map(\.trackId) == [TrackBlueprint.presets[0].blueprint.trackId])
    }

    @Test func noPicksMeansNoSeries() {
        #expect(RaceCoordinator.trackPlaylist(players: [player("Kid")], picks: []).isEmpty)
    }
}
