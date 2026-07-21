//
//  RaceCoordinator.swift
//  Hot Wheels v Human
//
//  Host-side brain (TV, or the host half of Solo Arena's loopback pair).
//  Collects players/designs/track drafts over the transport, interleaves
//  the drafts into a race series, runs RaceSession, broadcasts snapshots
//  @10 Hz, validates boosts server-side.
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
    /// Every valid track pick received, tagged with who ranked it where.
    private var trackPicks: [(owner: UUID?, rank: Int, blueprint: TrackBlueprint)] = []
    /// The drafted series (built at first race start) and how far we are in it.
    private var playlist: [TrackBlueprint] = []
    private var raceIndex = 0
    private var config = MatchConfig(mode: .onePlayer)
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
        case .trackBlueprint(let bp, let rank, let ownerID):
            let result = BlueprintValidator.validate(bp)
            guard result.isValid else {
                let reason = result.reasons.joined(separator: " ")
                lastRejection = reason
                transport.send(.raceEvent(.blueprintRejected(reason: reason)), reliably: true)
                break
            }
            if let ownerID {
                // Ranked draft pick. Replacing by slot and by track keeps a
                // reconnect resubmit (same list, same owner) idempotent.
                trackPicks.removeAll {
                    $0.owner == ownerID
                        && ($0.rank == rank || $0.blueprint.trackId == bp.trackId)
                }
                trackPicks.append((owner: ownerID, rank: rank ?? 0, blueprint: bp))
            } else {
                // Old peers send one unowned track: solo keeps
                // last-track-wins (rebuild → resubmit), two old iPads keep
                // first-valid-wins so the captain's track sticks.
                guard players.count <= 1 || trackPicks.allSatisfy({ $0.owner != nil })
                else { break }
                trackPicks.removeAll { $0.owner == nil }
                trackPicks.append((owner: nil, rank: rank ?? 0, blueprint: bp))
            }
        case .matchConfig(let cfg):
            if players.count <= 1 { config = cfg }   // captain's config; 2P is host-derived
        case .readyState(let playerID, let ready):
            readiness[playerID] = ready
            rematchIfReady()
            startRaceIfReady()
        case .boost(let playerID, _):
            // No dedupe: boost packets are a hold heartbeat now, and
            // requestBoost is idempotent — every repeat is meant to land.
            session.requestBoost(playerID: playerID)
        case .reactionCam(let playerID, let on):
            if on { reactionCamsOn.insert(playerID) } else { reactionCamsOn.remove(playerID) }
        case .raceEvent, .raceSnapshot:
            break   // host-authored, never inbound
        }
    }

    /// Is this player readied up? (TV lobby checkmarks.)
    func isReady(_ playerID: UUID) -> Bool { readiness[playerID] == true }

    /// TV-side override: mark every connected player ready and try to
    /// start, for a couch that's one iPad short of everyone tapping READY
    /// (or just doesn't want to wait). startRaceIfReady() still no-ops
    /// quietly if a player hasn't submitted a car/track yet, same as the
    /// normal per-player ready flow.
    func hostStartRace() {
        for player in players { readiness[player.id] = true }
        startRaceIfReady()
    }

    /// The track racing next (draft gating tests, TV lobby).
    var lobbyBlueprintID: UUID? { nextBlueprint()?.trackId }

    /// 1-based position in the series, for "Race 2 of 5" labels.
    var raceNumber: Int { playlist.isEmpty ? 1 : raceIndex % playlist.count + 1 }
    var raceCount: Int { max(playlist.count, 1) }

    /// How many tracks this player has drafted (TV lobby card).
    func pickCount(_ playerID: UUID) -> Int {
        trackPicks.count { $0.owner == playerID }
    }

    /// This player's submitted car, for the TV lobby's swatch (nil until
    /// their `.carDesign` arrives — briefly, right after they join).
    func design(for playerID: UUID) -> CarDesign? {
        designs.first { $0.owner == playerID }?.design
    }

    /// The playlist freezes at first race start; until then picks are
    /// still arriving, so peek at a fresh draft without caching it.
    private func nextBlueprint() -> TrackBlueprint? {
        let series = playlist.isEmpty
            ? Self.trackPlaylist(players: players, picks: trackPicks) : playlist
        return series.isEmpty ? nil : series[raceIndex % series.count]
    }

    /// Draft order, pure and unit-tested: players alternate turns in
    /// arrival order (captain first), each contributing their next-ranked
    /// pick; unowned picks (old peers) draft as one extra shared player;
    /// a track already in the series is skipped; capped at `length`.
    nonisolated static func trackPlaylist(
        players: [PlayerInfo],
        picks: [(owner: UUID?, rank: Int, blueprint: TrackBlueprint)],
        length: Int = RaceTuning.raceSeriesLength
    ) -> [TrackBlueprint] {
        let owners: [UUID?] = players.map { $0.id } + [nil]
        var buckets: [[TrackBlueprint]] = owners.map { owner in
            picks.filter { $0.owner == owner }.sorted { $0.rank < $1.rank }
                .map(\.blueprint)
        }
        var series: [TrackBlueprint] = []
        while series.count < length, buckets.contains(where: { !$0.isEmpty }) {
            for i in buckets.indices where series.count < length {
                while let pick = buckets[i].first {
                    buckets[i].removeFirst()
                    if !series.contains(where: { $0.trackId == pick.trackId }) {
                        series.append(pick)
                        break
                    }
                }
            }
        }
        return series
    }

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
              let root = arenaRoot,
              !players.isEmpty,
              players.allSatisfy({ readiness[$0.id] == true }),
              !designs.isEmpty else { return }
        if playlist.isEmpty {
            playlist = Self.trackPlaylist(players: players, picks: trackPicks)
        }
        guard let blueprint = nextBlueprint() else { return }
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

    /// On the results screen, everyone pressing READY again = next race:
    /// tear down and let startRaceIfReady rebuild with the next track in
    /// the drafted series (same designs; wraps to track 1 after the last).
    private func rematchIfReady() {
        guard raceRunning, session.phase == .results,
              !players.isEmpty,
              players.allSatisfy({ readiness[$0.id] == true }) else { return }
        raceIndex += 1
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
