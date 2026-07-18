//
//  RaceCoordinator.swift
//  Hot Wheels v Human
//
//  Host-side brain (TV, or the host half of Solo Arena's loopback pair).
//  Collects players/designs/blueprint over the transport, runs RaceSession,
//  broadcasts snapshots @10 Hz, validates boosts server-side.
//
//  State flow (PRD §6.1): lobby → collectingDesigns → buildingTrack →
//  countdown → racing → results (RaceSession owns the last three).
//

import Foundation
import Observation
import RealityKit

@MainActor
@Observable
final class RaceCoordinator {

    let session = RaceSession()
    private(set) var players: [PlayerInfo] = []
    private(set) var transportState: TransportState = .idle
    private(set) var lastRejection: String?
    /// Players currently holding their Reaction Cam button (ArenaView PiPs).
    private(set) var reactionCamsOn: Set<UUID> = []

    private let transport: any GameTransport
    private var designs: [(owner: UUID?, design: CarDesign)] = []
    private var readiness: [UUID: Bool] = [:]
    private var blueprint: TrackBlueprint?
    private var config = MatchConfig(mode: .onePlayer)
    private let boostDedupe = TokenDeduper()
    private var arenaRoot: Entity?
    private var raceRunning = false

    init(transport: any GameTransport) {
        self.transport = transport
        session.onEvent = { [weak self] event in
            self?.transport.send(.raceEvent(event), reliably: true)
        }
    }

    /// ArenaView hands over the RealityKit root once the scene exists.
    func attach(root: Entity) {
        arenaRoot = root
        startRaceIfReady()
    }

    func start() {
        transport.start(role: .host)
        Task { [weak self] in
            guard let events = self?.transport.events else { return }
            for await event in events {
                self?.handle(event)
            }
        }
    }

    func stop() {
        transport.stop()
    }

    private func handle(_ event: TransportEvent) {
        switch event {
        case .stateChanged(let state):
            transportState = state
        case .peerConnected, .peerDropped:
            break   // lobby UI reads `players`, which tracks hellos
        case .message(let message):
            handle(message)
        }
    }

    /// v1 rule: two lanes, two racers max (TWO-IPAD-2P.md).
    static let maxPlayers = 2

    private func handle(_ message: GameMessage) {
        switch message {
        case .hello(let player, _):
            guard !players.contains(where: { $0.id == player.id }) else { break }
            if raceRunning {
                lastRejection = "Race in progress — hop in the next one!"
            } else if players.count >= Self.maxPlayers {
                lastRejection = "Two racers max — grab the next race!"
            } else {
                players.append(player)
            }
        case .carDesign(let design, let ownerID):
            if !designs.contains(where: { $0.design.id == design.id }) {
                designs.append((owner: ownerID, design: design))
            }
        case .trackBlueprint(let bp):
            // Solo keeps last-track-wins (rebuild → resubmit). With two
            // iPads the first valid track sticks — the captain (first iPad
            // in) submits on connect, so this is "captain picks" without a
            // wire change to attribute senders.
            guard blueprint == nil || players.count <= 1 else { break }
            let result = BlueprintValidator.validate(bp)
            if result.isValid {
                blueprint = bp
            } else {
                let reason = result.reasons.joined(separator: " ")
                lastRejection = reason
                transport.send(.raceEvent(.blueprintRejected(reason: reason)), reliably: true)
            }
        case .matchConfig(let cfg):
            if players.count <= 1 { config = cfg }   // captain's config; 2P is host-derived
        case .readyState(let playerID, let ready):
            readiness[playerID] = ready
            rematchIfReady()
            startRaceIfReady()
        case .boost(let playerID, let token):
            if boostDedupe.firstSighting(token) {
                session.requestBoost(playerID: playerID)
            }
        case .reactionCam(let playerID, let on):
            if on { reactionCamsOn.insert(playerID) } else { reactionCamsOn.remove(playerID) }
        case .raceEvent, .raceSnapshot:
            break   // host-authored, never inbound
        }
    }

    /// Is this player readied up? (TV lobby checkmarks.)
    func isReady(_ playerID: UUID) -> Bool { readiness[playerID] == true }

    /// The track the lobby will race (captain gating tests).
    var lobbyBlueprintID: UUID? { blueprint?.trackId }

    /// Pure pairing rules, unit-tested in TwoPlayerCoordinationTests:
    /// owned designs go to their player (two-iPad 2P), unowned fill in by
    /// arrival order (solo/1P/Test Mode), leftovers race controller-less,
    /// and the robot only joins a 1-human race. Two humans = two lanes,
    /// no robot, mode `.twoPlayer` regardless of what the iPads sent.
    nonisolated static func raceEntries(
        players: [PlayerInfo], designs: [(owner: UUID?, design: CarDesign)],
        config: MatchConfig
    ) -> (entries: [(UUID, CarDesign)], config: MatchConfig) {
        var unowned = designs.filter { $0.owner == nil }.map(\.design)
        var entries: [(UUID, CarDesign)] = players.compactMap { player in
            if let owned = designs.first(where: { $0.owner == player.id }) {
                return (player.id, owned.design)
            }
            return unowned.isEmpty ? nil : (player.id, unowned.removeFirst())
        }
        entries += unowned.map { ($0.id, $0) }

        var config = config
        if players.count >= 2 {
            config.mode = .twoPlayer
            config.aiDifficulty = nil
        } else if config.mode == .onePlayer, let difficulty = config.aiDifficulty {
            entries.append((AIRoster.playerID, AIRoster.bot(for: difficulty)))
        }
        return (entries, config)
    }

    private func startRaceIfReady() {
        guard !raceRunning,
              let blueprint, let root = arenaRoot,
              !players.isEmpty,
              players.allSatisfy({ readiness[$0.id] == true }),
              !designs.isEmpty else { return }
        raceRunning = true

        let (entries, effectiveConfig) = Self.raceEntries(
            players: players, designs: designs, config: config)
        config = effectiveConfig
        Task { @MainActor in
            do {
                try await session.start(blueprint: blueprint, entries: entries,
                                        config: config, root: root)
                broadcastSnapshots()
            } catch {
                lastRejection = "Arena build failed: \(error)"
                raceRunning = false
            }
        }
    }

    private func broadcastSnapshots() {
        Task { @MainActor [weak self] in
            while let self, self.session.phase != .results {
                self.transport.send(.raceSnapshot(self.currentSnapshot()), reliably: false)
                try? await Task.sleep(for: .seconds(Double(1 / RaceTuning.snapshotRate)))
            }
            // One final reliable snapshot so dashboards land on results,
            // then require fresh READYs so a stale one can't auto-rematch.
            if let self {
                self.transport.send(.raceSnapshot(self.currentSnapshot()), reliably: true)
                self.readiness = self.readiness.mapValues { _ in false }
            }
        }
    }

    /// On the results screen, everyone pressing READY again = rematch:
    /// tear the old race down and let startRaceIfReady rebuild (same
    /// designs, same track).
    private func rematchIfReady() {
        guard raceRunning, session.phase == .results,
              !players.isEmpty,
              players.allSatisfy({ readiness[$0.id] == true }) else { return }
        session.reset()
        raceRunning = false
    }

    private func currentSnapshot() -> RaceSnapshot {
        RaceSnapshot(
            raceClock: session.raceClock,
            phase: session.phase,
            cars: session.racers.enumerated().map { i, racer in
                CarSnapshot(playerID: racer.id, progress: racer.progress,
                            speed: racer.speed, boostMeter: racer.boostMeter,
                            livesLeft: racer.livesLeft, lane: i % 2)
            })
    }
}
