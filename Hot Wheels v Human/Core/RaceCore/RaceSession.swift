//
//  RaceSession.swift
//  Hot Wheels v Human
//
//  Solo-arena race orchestration: countdown → racing → results.
//  Owns the per-car stats the HUD and Test Mode display. The networked
//  RaceCoordinator (Phase 3) will wrap this same logic behind GameTransport.
//

import Combine
import Foundation
import Observation
import RealityKit

@MainActor
@Observable
final class RaceSession {

    struct Racer: Identifiable {
        let id: UUID
        let design: CarDesign
        var entity: ModelEntity?
        var livesLeft: Int
        var boostMeter: Float = 0
        /// Burning right now (audio + reaction cam read this).
        var boosting = false
        var speed: Float = 0
        var topSpeed: Float = 0
        var progress: Float = 0
        var crashes = 0
        var finishTime: TimeInterval?
        var isOut = false
        /// Fastest single-piece traversal (piece index, seconds).
        var bestSegment: (piece: Int, seconds: Float)?
        var segmentStartClock: TimeInterval = 0
        var lastPieceIndex = 0
        var isAI: Bool { id == AIRoster.playerID }
    }

    private(set) var phase: RacePhase = .lobby
    /// Which track is (about to be) built — ArenaView themes the
    /// environment from this, so a TV series re-themes per race.
    private(set) var trackID: UUID?
    /// Ground-plane bounds of the whole track — ArenaEnvironment keeps
    /// its scattered props out of this rect.
    private(set) var trackFootprint: FootprintRect?
    private(set) var countdownValue = 3
    private(set) var raceClock: TimeInterval = 0
    private(set) var racers: [Racer] = []
    var allDone: Bool {
        !racers.isEmpty && racers.allSatisfy { $0.finishTime != nil || $0.isOut }
    }

    private var updateSubscription: (any Cancellable)?
    private var trackEntity: Entity?
    private var config = MatchConfig(mode: .solo)
    /// Piece types in track order + where each starts on the spline —
    /// the AI policy and best-segment stat both read these.
    private var pieceTypes: [PieceType] = []
    private var pieceStartIndices: [Int] = []
    private var aiRNG = SystemRandomNumberGenerator()

    /// Forwarded discrete events (countdown, crash, respawn, finish) —
    /// RaceCoordinator relays these onto the transport.
    var onEvent: ((RaceEvent) -> Void)?

    /// CLI drill breadcrumbs: print AND append to Documents/drill-log.txt —
    /// `simctl launch --console-pty` drops output often enough that sim
    /// drills need the file (read via `simctl get_app_container … data`).
    ///
    /// Debug builds only. This is dev tooling: a shipped app has no business
    /// writing a race trace into a kid's Documents folder on every frame.
    /// Drills run debug builds, so nothing is lost. Callers stay unguarded —
    /// one `#if` here beats one at each of the eight call sites.
    nonisolated static func drillLog(_ line: String, reset: Bool = false) {
        #if DEBUG
        print(line)
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("drill-log.txt")
        let data = Data((line + "\n").utf8)
        if !reset, let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url)
        }
        #endif
    }
    private var lastTraceSecond = -1
    @MainActor private static var drillLogStarted = false
    /// Last known good pose per racer — restored after a hitch frame.
    private var lastPoses: [UUID: (position: SIMD3<Float>, velocity: SIMD3<Float>)] = [:]

    /// Builds the whole arena scene into `root` and starts the countdown.
    /// `entries` pair each design with the owning player's stable ID.
    func start(blueprint: TrackBlueprint, entries: [(playerID: UUID, design: CarDesign)],
               config: MatchConfig, root: Entity) async throws {
        phase = .buildingTrack
        // Append across a TV series' races; fresh file per app launch.
        Self.drillLog("[race] building \(blueprint.trackId)",
                      reset: !Self.drillLogStarted)
        Self.drillLogStarted = true
        self.config = config
        trackID = blueprint.trackId
        let layout = TrackLayoutSolver.solve(blueprint)
        let rects = layout.pieces.map(\.worldFootprint)
        trackFootprint = FootprintRect(
            minX: rects.map(\.minX).min() ?? 0, minZ: rects.map(\.minZ).min() ?? 0,
            maxX: rects.map(\.maxX).max() ?? 0, maxZ: rects.map(\.maxZ).max() ?? 0)
        pieceTypes = layout.pieces.map(\.definition.type)
        pieceStartIndices = layout.lanes.pieceStartIndices
        let track = try await TrackSpawner.spawn(layout: layout)
        trackEntity = track
        await DebrisPool.shared.warmUp()
        track.components.set(RaceTrackComponent(lanes: layout.lanes, laps: config.laps))
        root.addChild(track)
        // ponytail: scene default gravity (-9.81) for now — a custom
        // PhysicsSimulationComponent on the root stopped simulation dead in
        // the Simulator. Revisit RaceTuning.gravityScale wiring in tuning.

        let lives = config.mode == .test ? Int.max : config.lives
        racers = []
        lastPoses = [:]   // stale poses must not survive into a new track
        // Waypoint ranges covering loop pieces, for the loop motor.
        let starts = layout.lanes.pieceStartIndices
        let loopRanges: [ClosedRange<Int>] = layout.pieces.enumerated().compactMap { pi, piece in
            guard case .verticalLoop = piece.definition.shape else { return nil }
            let end = pi + 1 < starts.count ? starts[pi + 1] : layout.lanes.center.count - 1
            return starts[pi]...end
        }
        for (i, entry) in entries.enumerated() {
            let (playerID, design) = entry
            let lane = i % 2 == 0 ? layout.lanes.left : layout.lanes.right
            let car = try await CarFactory.makeCar(
                design: design, playerID: playerID, lane: lane,
                lives: lives, loopRanges: loopRanges,
                laterals: layout.lanes.laterals)
            // Staggered grid on the gate bed. Waypoint 1 (0.1 m in) is
            // proven solid; the gate's raised ramp geometry (~z 0.25–0.45)
            // and the piece seam (z 0.8) both wedge drop-spawned cars, so
            // keep every slot on flat gate bed (sim drills).
            let gridSlot = min(i * 4 + 1, max(lane.count - 1, 0))
            // Pinned (kinematic) cars sit exactly at ride height — they
            // never settle under gravity, so a drop allowance would hover.
            let lift = car.physicsBody?.mode == .kinematic
                ? (car.components[CarComponent.self]?.rideHeight ?? 0)
                : car.spawnLift
            car.position = lane[gridSlot] + [0, lift, 0]
            // Visible AND dynamic through the countdown: rendering compiles
            // the shaders and the physics world builds NOW — both stall for
            // seconds in the Simulator, and any stall after cars start
            // moving integrates one giant step that teleports them off the
            // lane. During the countdown DriveSystem/rules are inert
            // (RaceEventBus.raceActive) so the stalls land on parked cars.
            track.addChild(car)
            racers.append(Racer(id: playerID, design: design, entity: car, livesLeft: lives))
        }

        countdown(root: root)
    }

    private func countdown(root: Entity) {
        phase = .countdown
        countdownValue = 3
        Task { @MainActor in
            while countdownValue > 0 {
                onEvent?(.countdownTick(countdownValue))
                try? await Task.sleep(for: .seconds(1))
                countdownValue -= 1
            }
            onEvent?(.countdownTick(0))
            go(root: root)
        }
    }

    private func go(root: Entity) {
        phase = .racing
        raceClock = 0
        // Cars stay STATIC until the tick loop sees a normal-length frame:
        // the frames around GO stall for seconds in the Simulator (asset /
        // shader / audio warmup), one stalled frame integrates seconds of
        // physics in a single step, and a moving car teleports metres off
        // its lane. Static cars shrug stalls off; the green flag drops on
        // the first proven-fast frame.
        awaitingGreenFlag = true
        guard let scene = root.scene else { return }
        updateSubscription = scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
            self?.tick(dt: event.deltaTime)
        }
    }

    private var awaitingGreenFlag = false

    private func dropGreenFlag() {
        awaitingGreenFlag = false
        RaceEventBus.shared.raceActive = true
        for racer in racers {
            guard let car = racer.entity else { continue }
            // A dynamic body resting since the countdown may be ASLEEP and
            // DriveSystem's addForce never wakes it. An impulse does.
            // (Kinematic rail cars have no physicsMotion — nothing to wake.)
            if car.physicsMotion != nil {
                car.applyLinearImpulse([0, 0.001, 0], relativeTo: nil)
            }
            // Seed the hitch-rollback cache so even an immediate spike
            // frame has a pose to restore.
            lastPoses[racer.id] = (car.position(relativeTo: nil), .zero)
        }
    }

    private func tick(dt: TimeInterval) {
        guard phase == .racing else { return }

        if awaitingGreenFlag {
            if dt < 0.1 { dropGreenFlag() }
            return
        }

        // Hitch rollback: a stalled frame (asset/shader/audio warmup in the
        // Simulator) integrates seconds of physics in ONE step — a moving
        // car teleports metres off its lane, and no force-side guard can
        // prevent that. The screen was frozen through the stall anyway, so
        // restoring last frame's poses reads as nothing at all.
        if dt > RaceTuning.hitchRollbackThreshold, !lastPoses.isEmpty {
            for r in racers {
                guard let car = r.entity, let pose = lastPoses[r.id] else { continue }
                // Rail (kinematic) cars are EXEMPT. They can't be teleported
                // by a stall — DriveSystem clamps dt to 0.1 s and caps speed,
                // so one spike frame advances them a few cm at most. Rolling
                // one back moved the entity while its follower kept the
                // arc-length it had already integrated, so the next frame
                // snapped it forward again: the car visibly jittered backward
                // on every stalled frame, which in the Simulator is often.
                // Rail progress is monotonic; nothing may push it back.
                if car.physicsBody?.mode == .kinematic { continue }
                car.setPosition(pose.position, relativeTo: nil)
                car.physicsMotion?.linearVelocity = pose.velocity
                car.physicsMotion?.angularVelocity = .zero
            }
            return   // the spike contributes no race clock either
        }
        for r in racers {
            if let car = r.entity {
                lastPoses[r.id] = (car.position(relativeTo: nil),
                                   car.physicsMotion?.linearVelocity ?? .zero)
            }
        }

        raceClock += dt

        for event in RaceEventBus.shared.drain() {
            switch event {
            case .carDestroyed(let id):
                withRacer(id) {
                    $0.crashes += 1
                    Self.drillLog("[race] \($0.design.name) crashed at piece \($0.lastPieceIndex) (crash #\($0.crashes))")
                }
                onEvent?(event)
            case .finished(let id, _):
                withRacer(id) { $0.finishTime = self.raceClock }
                onEvent?(.finished(playerID: id, time: raceClock))
            default:
                onEvent?(event)
            }
        }

        // 1 Hz drill trace: where every car is, each second of the race.
        if Int(raceClock * 4) != lastTraceSecond {
            lastTraceSecond = Int(raceClock * 4)
            for r in racers {
                if let p = r.entity?.position(relativeTo: nil) {
                    Self.drillLog(String(format: "[race] t%.2f %@ (%.2f, %.2f, %.2f) %.1f m/s wp %d",
                                         Float(lastTraceSecond) / 4, r.design.name, p.x, p.y, p.z, r.speed,
                                         r.entity?.components[LaneFollowComponent.self]?.nextIndex ?? -1))
                }
            }
        }
        for i in racers.indices {
            guard let car = racers[i].entity,
                  let state = car.components[CarComponent.self],
                  let follow = car.components[LaneFollowComponent.self] else { continue }
            // Rail cars carry their speed on the follower; chaos cars on the body.
            let speed = car.physicsMotion.map { simd_length($0.linearVelocity) }
                ?? follow.speed
            racers[i].speed = speed
            racers[i].topSpeed = max(racers[i].topSpeed, speed)
            racers[i].livesLeft = state.livesLeft
            racers[i].boostMeter = state.boostMeter
            racers[i].boosting = state.boosting
            racers[i].isOut = state.livesLeft <= 0
            racers[i].progress = follow.waypoints.isEmpty ? 0
                : Float(follow.nextIndex) / Float(follow.waypoints.count - 1)

            // Best-segment stat: time each piece-to-piece traversal.
            let piece = pieceStartIndices.lastIndex { $0 <= follow.nextIndex } ?? 0
            if piece != racers[i].lastPieceIndex {
                let seconds = Float(raceClock - racers[i].segmentStartClock)
                if piece == racers[i].lastPieceIndex + 1,   // skip respawn jumps
                   seconds < (racers[i].bestSegment?.seconds ?? .infinity) {
                    racers[i].bestSegment = (racers[i].lastPieceIndex, seconds)
                }
                racers[i].lastPieceIndex = piece
                racers[i].segmentStartClock = raceClock
            }

            // AI boost decision — same meter rules as humans, fair by design.
            // Once it commits, it holds the button down until the bottle
            // runs dry, exactly like a kid who found the fun part.
            if racers[i].isAI, racers[i].boosting {
                requestBoost(playerID: racers[i].id)
            } else if racers[i].isAI, racers[i].boostMeter >= 1,
               let difficulty = config.aiDifficulty {
                let upcoming = Array(pieceTypes[min(piece + 1, pieceTypes.count)...])
                if AIBoostPolicy.shouldBoost(
                    difficulty: difficulty,
                    previous: piece > 0 ? pieceTypes[piece - 1] : nil,
                    current: piece < pieceTypes.count ? pieceTypes[piece] : nil,
                    upcoming: upcoming, dt: Float(dt), rng: &aiRNG) {
                    requestBoost(playerID: racers[i].id)
                }
            }
        }

        if allDone {
            phase = .results
            RaceEventBus.shared.raceActive = false
            for r in racers {
                let time = r.finishTime.map { String(format: "%.1fs", $0) } ?? "OUT"
                Self.drillLog("[race] result \(r.design.name): \(time), top \(String(format: "%.1f", r.topSpeed)) m/s, crashes \(r.crashes)")
            }
            updateSubscription?.cancel()
            updateSubscription = nil
        }
    }

    /// Tear down the finished race so start() can run again (REMATCH).
    func reset() {
        updateSubscription?.cancel()
        updateSubscription = nil
        trackEntity?.removeFromParent()
        trackEntity = nil
        racers = []
        RaceEventBus.shared.raceActive = false
        _ = RaceEventBus.shared.drain()   // stale events must not leak into the next race
        // .buildingTrack, NOT .lobby — the TV shows ArenaView for every
        // non-lobby phase; dropping to .lobby would tear down the
        // RealityView whose root the next race builds into.
        phase = .buildingTrack
    }

    /// Is a loop piece coming up within `seconds` at current speed?
    /// (ReactionDirector's "brace" input.)
    func loopAhead(for racerID: UUID, within seconds: Float) -> Bool {
        guard let racer = racers.first(where: { $0.id == racerID }),
              let follow = racer.entity?.components[LaneFollowComponent.self],
              racer.speed > 0.1 else { return false }
        for (piece, type) in pieceTypes.enumerated() where type == .loop {
            let start = pieceStartIndices[piece]
            guard start >= follow.nextIndex else { continue }
            let distance = Float(start - follow.nextIndex) * RaceTuning.waypointSpacing
            return distance / racer.speed < seconds
        }
        return false
    }

    /// "The boost button is down." The controller repeats this ~15 Hz while
    /// held; each call refreshes the hold window, and the first one with an
    /// armed meter starts the burn (server-side validation lives here so the
    /// networked path can reuse it). Idempotent on purpose — repeats are the
    /// hold signal, and a lost release packet just times the burn out.
    func requestBoost(playerID: UUID) {
        guard let car = racers.first(where: { $0.id == playerID })?.entity,
              var state = car.components[CarComponent.self] else { return }
        state.boostHoldGrace = RaceTuning.boostHoldGrace
        if !state.boosting, state.boostMeter >= 1 {
            state.boosting = true
            state.boostSeconds = 0
        }
        car.components.set(state)
    }

    private func withRacer(_ id: UUID, _ mutate: (inout Racer) -> Void) {
        if let i = racers.firstIndex(where: { $0.id == id }) {
            mutate(&racers[i])
        }
    }
}
