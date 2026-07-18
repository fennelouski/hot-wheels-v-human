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
    private var designs: [CarDesign] = []
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

    private func handle(_ message: GameMessage) {
        switch message {
        case .hello(let player, _):
            if !players.contains(where: { $0.id == player.id }) {
                players.append(player)
            }
        case .carDesign(let design):
            if !designs.contains(where: { $0.id == design.id }) {
                designs.append(design)
            }
        case .trackBlueprint(let bp):
            let result = BlueprintValidator.validate(bp)
            if result.isValid {
                blueprint = bp
            } else {
                let reason = result.reasons.joined(separator: " ")
                lastRejection = reason
                transport.send(.raceEvent(.blueprintRejected(reason: reason)), reliably: true)
            }
        case .matchConfig(let cfg):
            config = cfg
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

    /// Designs are keyed by CarDesign.id; each player declares theirs via
    /// carDesign messages. v1 pairs players to designs by arrival order.
    private func startRaceIfReady() {
        guard !raceRunning,
              let blueprint, let root = arenaRoot,
              !players.isEmpty,
              players.allSatisfy({ readiness[$0.id] == true }),
              !designs.isEmpty else { return }
        raceRunning = true

        // Designs pair to players by arrival order; extras (Test Mode's B
        // car, demo opponents) get the design's own id — no controller.
        var entries = designs.enumerated().map { i, design in
            (i < players.count ? players[i].id : design.id, design)
        }
        // 1P mode: the Hot Wheels robot joins with a roster car. Same
        // physics as humans — difficulty is boost-decision quality only.
        if config.mode == .onePlayer, let difficulty = config.aiDifficulty {
            entries.append((AIRoster.playerID, AIRoster.bot(for: difficulty)))
        }
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
