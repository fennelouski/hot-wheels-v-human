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
        var speed: Float = 0
        var topSpeed: Float = 0
        var progress: Float = 0
        var crashes = 0
        var finishTime: TimeInterval?
        var isOut = false
    }

    private(set) var phase: RacePhase = .lobby
    private(set) var countdownValue = 3
    private(set) var raceClock: TimeInterval = 0
    private(set) var racers: [Racer] = []
    var allDone: Bool {
        !racers.isEmpty && racers.allSatisfy { $0.finishTime != nil || $0.isOut }
    }

    private var updateSubscription: (any Cancellable)?

    /// Forwarded discrete events (countdown, crash, respawn, finish) —
    /// RaceCoordinator relays these onto the transport.
    var onEvent: ((RaceEvent) -> Void)?

    /// Builds the whole arena scene into `root` and starts the countdown.
    /// `entries` pair each design with the owning player's stable ID.
    func start(blueprint: TrackBlueprint, entries: [(playerID: UUID, design: CarDesign)],
               config: MatchConfig, root: Entity) async throws {
        phase = .buildingTrack
        let layout = TrackLayoutSolver.solve(blueprint)
        let track = try await TrackSpawner.spawn(layout: layout)
        track.components.set(RaceTrackComponent(lanes: layout.lanes, laps: config.laps))
        root.addChild(track)
        // ponytail: scene default gravity (-9.81) for now — a custom
        // PhysicsSimulationComponent on the root stopped simulation dead in
        // the Simulator. Revisit RaceTuning.gravityScale wiring in tuning.

        let lives = config.mode == .test ? Int.max : config.lives
        racers = []
        for (i, entry) in entries.enumerated() {
            let (playerID, design) = entry
            let lane = i % 2 == 0 ? layout.lanes.left : layout.lanes.right
            let car = try await CarFactory.makeCar(
                design: design, playerID: playerID, lane: lane,
                lives: lives)
            // Staggered grid: lane 1 starts a nose behind lane 0 so the
            // pair doesn't wedge at single-file merges (the loop).
            let gridSlot = min(i * 4, max(lane.count - 1, 0))
            car.position = lane[gridSlot] + [0, 0.05, 0]
            car.isEnabled = false     // frozen until GO
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
        for racer in racers { racer.entity?.isEnabled = true }
        guard let scene = root.scene else { return }
        updateSubscription = scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
            self?.tick(dt: event.deltaTime)
        }
    }

    private func tick(dt: TimeInterval) {
        guard phase == .racing else { return }
        raceClock += dt

        for event in RaceEventBus.shared.drain() {
            switch event {
            case .carDestroyed(let id):
                withRacer(id) { $0.crashes += 1 }
                onEvent?(event)
            case .finished(let id, _):
                withRacer(id) { $0.finishTime = self.raceClock }
                onEvent?(.finished(playerID: id, time: raceClock))
            default:
                onEvent?(event)
            }
        }

        for i in racers.indices {
            guard let car = racers[i].entity,
                  let state = car.components[CarComponent.self],
                  let follow = car.components[LaneFollowComponent.self] else { continue }
            let speed = simd_length(car.physicsMotion?.linearVelocity ?? .zero)
            racers[i].speed = speed
            racers[i].topSpeed = max(racers[i].topSpeed, speed)
            racers[i].livesLeft = state.livesLeft
            racers[i].boostMeter = state.boostMeter
            racers[i].isOut = state.livesLeft <= 0
            racers[i].progress = follow.waypoints.isEmpty ? 0
                : Float(follow.nextIndex) / Float(follow.waypoints.count - 1)
        }

        if allDone {
            phase = .results
            updateSubscription?.cancel()
            updateSubscription = nil
        }
    }

    /// Fires the boost if the meter is full (server-side validation lives
    /// here so the networked path can reuse it).
    func requestBoost(playerID: UUID) {
        guard let car = racers.first(where: { $0.id == playerID })?.entity,
              var state = car.components[CarComponent.self],
              state.boostMeter >= 1 else { return }
        state.boostMeter = 0
        state.pendingBoost = true
        car.components.set(state)
    }

    private func withRacer(_ id: UUID, _ mutate: (inout Racer) -> Void) {
        if let i = racers.firstIndex(where: { $0.id == id }) {
            mutate(&racers[i])
        }
    }
}
