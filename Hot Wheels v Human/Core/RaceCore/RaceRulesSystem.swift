//
//  RaceRulesSystem.swift
//  Hot Wheels v Human
//
//  The 5-chance system (PRD §3.3): destruction on fall / stuck / flipped,
//  debris explosion, respawn at the last piece boundary, finish detection.
//  Emits RaceEvents through RaceEventBus for RaceSession/RaceCoordinator.
//

import Foundation
import RealityKit

/// Frame-to-frame collector; whoever orchestrates the race drains it.
@MainActor
final class RaceEventBus {
    static let shared = RaceEventBus()
    private(set) var pending: [RaceEvent] = []
    /// The green flag: DriveSystem and the destruction rules are inert
    /// until RaceSession raises this. Cars sit dynamic-but-undriven at the
    /// grid through the countdown, so the physics world (and its multi-
    /// second Simulator warmup stall) builds while nothing can be hurt.
    var raceActive = false
    func emit(_ event: RaceEvent) { pending.append(event) }
    func drain() -> [RaceEvent] {
        defer { pending.removeAll() }
        return pending
    }
}

/// Marks debris chunks for cleanup.
struct DebrisComponent: Component {
    var secondsLeft: Float
}

/// Fixed pool of physics-wrapped debris chunks (P7 hardening): crashes on a
/// 40-piece track must not allocate entities forever. Warmed once per app
/// run; explosions borrow, expiry returns. Pool empty = crash renders fewer
/// chunks — bounded memory beats bonus confetti.
@MainActor
final class DebrisPool {
    static let shared = DebrisPool()

    private var free: [ModelEntity] = []
    private var warmed = false

    func warmUp() async {
        guard !warmed else { return }
        warmed = true
        let names = ["debris-tire", "debris-bumper", "debris-door", "debris-nut",
                     "debris-bolt", "debris-plate-small-a"]
        for i in 0..<RaceTuning.debrisPoolSize {
            guard let chunk = try? await AssetStore.shared.entity(named: names[i % names.count]),
                  let model = ModelEntity.wrappingForPhysics(chunk) else { continue }
            model.isEnabled = false
            free.append(model)
        }
    }

    func take() -> ModelEntity? { free.popLast() }

    func give(_ chunk: ModelEntity) {
        chunk.removeFromParent()
        chunk.isEnabled = false
        chunk.physicsMotion?.linearVelocity = .zero
        chunk.physicsMotion?.angularVelocity = .zero
        free.append(chunk)
    }
}

/// Set on the track root by the spawner/session so rules can find spline data.
struct RaceTrackComponent: Component {
    var lanes: LaneSplines
    var laps: Int
}

struct RaceRulesSystem: System {
    static let carQuery = EntityQuery(where: .has(CarComponent.self) && .has(LaneFollowComponent.self))
    static let debrisQuery = EntityQuery(where: .has(DebrisComponent.self))

    init(scene: Scene) {
        DebrisComponent.registerComponent()
        RaceTrackComponent.registerComponent()
    }

    func update(context: SceneUpdateContext) {
        // Clamped: an asset-load hitch can deliver a multi-second frame, and
        // raw dt would count it all as "stuck" time — destroying a healthy
        // car at the start gate (seen in CLI drills as a piece-0 crash).
        let dt = min(Float(context.deltaTime), 0.1)

        for entity in context.entities(matching: Self.debrisQuery, updatingSystemWhen: .rendering) {
            guard var debris = entity.components[DebrisComponent.self] else { continue }
            debris.secondsLeft -= dt
            if debris.secondsLeft <= 0 {
                if let model = entity as? ModelEntity {
                    DebrisPool.shared.give(model)
                } else {
                    entity.removeFromParent()
                }
            } else {
                entity.components.set(debris)
            }
        }

        guard RaceEventBus.shared.raceActive else { return }
        for entity in context.entities(matching: Self.carQuery, updatingSystemWhen: .rendering) {
            guard let car = entity as? ModelEntity,
                  var state = car.components[CarComponent.self],
                  var follow = car.components[LaneFollowComponent.self],
                  !state.finished, state.livesLeft > 0, car.isEnabled,
                  // Static = parked at the finish — nothing left to check.
                  car.physicsBody?.mode != .static else { continue }

            let position = car.position(relativeTo: nil)
            let speed = car.physicsMotion.map { simd_length($0.linearVelocity) }
                ?? follow.speed

            // Boost meter charges over time (validated/consumed elsewhere).
            state.boostMeter = min(1, state.boostMeter + dt / RaceTuning.boostChargeTime)

            // ── Finish: last waypoint reached.
            if follow.nextIndex >= follow.waypoints.count - 1,
               simd_length(follow.waypoints.last! - position) < RaceTuning.finishCatchRadius {
                RaceSession.drillLog(String(format: "[race] %@ finished at (%.2f, %.2f, %.2f) wp %d",
                                            state.design.name, position.x, position.y, position.z,
                                            follow.nextIndex))
                state.finished = true
                car.components.set(state)
                // Park it — an unfrozen finisher coasts off the edge of the
                // world and drags the chase camera into the void.
                car.physicsMotion?.linearVelocity = .zero
                car.physicsMotion?.angularVelocity = .zero
                car.physicsBody?.mode = .static
                RaceEventBus.shared.emit(.finished(playerID: state.playerID, time: 0))
                continue
            }

            // Rail-pinned (kinematic) cars can't fall, wedge, or flip — the
            // follower owns their pose. Meter charge + finish are all they need.
            if car.physicsBody?.mode == .kinematic {
                car.components.set(state)
                car.components.set(follow)
                continue
            }

            // ── Destruction checks.
            var reason: String?
            if position.y < -RaceTuning.destructionFallDepth {
                reason = "fell"
            }
            if let anchor = state.stuckAnchor,
               simd_length(position - anchor) < RaceTuning.stuckRadius {
                state.stuckSeconds += dt
            } else {
                state.stuckAnchor = position
                state.stuckSeconds = 0
            }
            let up = car.convert(direction: [0, 1, 0], to: nil)
            state.flippedSeconds = up.y < 0 ? state.flippedSeconds + dt : 0
            if state.flippedSeconds > RaceTuning.flippedTime { reason = "flipped" }

            // Being stuck is a RESCUE, not a crash. Two reasons it can't be
            // a destruction: a car wedged in track geometry can't be freed
            // by force (traced still pinned under DriveSystem's full 80 m/s²
            // unstick shove), and the old path — charge a life, respawn TWO
            // PIECES BACK — drove it into the very same wedge again. The
            // heavy chassis burned all five lives on one hill seam and DNF'd
            // every race that way.
            //
            // Lifting the car to the START OF THE NEXT PIECE puts it past
            // the snag, so every rescue makes forward progress and the car
            // reaches the finish in finite steps however bad the geometry
            // is. No life charged: catching on a seam isn't a mistake the
            // kid made, and every car is meant to finish.
            if reason == nil, state.stuckSeconds > RaceTuning.stuckTime {
                let anchors = car.parent?.components[RaceTrackComponent.self]?.lanes.pieceStartIndices
                    ?? [0]
                let wedged = anchors.lastIndex(where: { $0 <= follow.nextIndex }) ?? 0
                let ahead = min(anchors[min(wedged + 1, anchors.count - 1)],
                                follow.waypoints.count - 1)
                RaceSession.drillLog("[race] \(state.design.name) rescued: stuck at "
                    + String(format: "(%.2f, %.2f, %.2f)", position.x, position.y, position.z)
                    + " → piece \(min(wedged + 1, anchors.count - 1))")
                state.stuckSeconds = 0
                state.stuckAnchor = nil
                follow.nextIndex = ahead
                respawn(car, at: follow.waypoints[ahead],
                        toward: follow.waypoints[min(ahead + 1, follow.waypoints.count - 1)])
                RaceEventBus.shared.emit(.respawned(playerID: state.playerID))
            }

            if let reason {
                // Drill breadcrumb — pairs with the [race] lines RaceSession logs.
                RaceSession.drillLog("[race] \(state.design.name) destroyed: \(reason) at "
                      + String(format: "(%.2f, %.2f, %.2f), %.1f m/s",
                               position.x, position.y, position.z, speed))
                state.livesLeft -= 1
                state.stuckSeconds = 0
                state.stuckAnchor = nil
                state.flippedSeconds = 0
                RaceEventBus.shared.emit(.carDestroyed(playerID: state.playerID))
                explodeDebris(at: position, in: car.parent)

                if state.livesLeft > 0 {
                    // Respawn two pieces BEFORE the one the car died on — a
                    // loop with no run-up would just eat the car again, and
                    // one piece (0.8 m) isn't enough for the heavy chassis
                    // to reach loop entry speed (sim drills: a loop death
                    // became an unwinnable respawn-fail loop).
                    let anchors = car.parent?.components[RaceTrackComponent.self]?.lanes.pieceStartIndices
                        ?? [0]
                    let died = anchors.lastIndex(where: { $0 <= follow.nextIndex }) ?? 0
                    let checkpoint = anchors[max(died - 2, 0)]
                    follow.nextIndex = checkpoint
                    respawn(car, at: follow.waypoints[min(checkpoint + 1, follow.waypoints.count - 1)],
                            toward: follow.waypoints[min(checkpoint + 2, follow.waypoints.count - 1)])
                    RaceEventBus.shared.emit(.respawned(playerID: state.playerID))
                } else {
                    car.isEnabled = false   // out of cars — race over for them
                }
            }

            car.components.set(state)
            car.components.set(follow)
        }
    }

    private func respawn(_ car: ModelEntity, at point: SIMD3<Float>, toward next: SIMD3<Float>) {
        car.setPosition(point + [0, car.spawnLift, 0], relativeTo: nil)
        let dir = next - point
        car.orientation = simd_quatf(angle: atan2(dir.x, dir.z), axis: [0, 1, 0])
        car.physicsMotion?.linearVelocity = .zero
        car.physicsMotion?.angularVelocity = .zero
        // ponytail: instant respawn; RaceTuning.respawnDelay pause + VFX come
        // with RaceCoordinator polish once the loop is proven fun.
    }

    /// Pooled Kenney debris chunks flung outward; expiry returns them.
    private func explodeDebris(at position: SIMD3<Float>, in parent: Entity?) {
        guard let parent else { return }
        Task { @MainActor in
            for _ in 0..<RaceTuning.debrisCount {
                guard let model = DebrisPool.shared.take() else { break }
                model.setPosition(position + [Float.random(in: -0.05...0.05), 0.05,
                                              Float.random(in: -0.05...0.05)],
                                  relativeTo: nil)
                model.components.set(DebrisComponent(secondsLeft: RaceTuning.debrisLifetime))
                parent.addChild(model)
                model.isEnabled = true
                let impulse = SIMD3<Float>(Float.random(in: -1...1),
                                           Float.random(in: 0.5...1.5),
                                           Float.random(in: -1...1))
                    * Float.random(in: RaceTuning.debrisImpulse)
                model.applyLinearImpulse(impulse, relativeTo: nil)
            }
        }
    }
}

extension ModelEntity {
    /// Wraps a loaded visual in a small dynamic physics body.
    static func wrappingForPhysics(_ visual: Entity) -> ModelEntity? {
        let body = ModelEntity()
        body.addChild(visual)
        let bounds = visual.visualBounds(relativeTo: body)
        visual.position -= bounds.center
        let shape = ShapeResource.generateBox(size: max(bounds.extents, [0.01, 0.01, 0.01]))
        body.collision = CollisionComponent(shapes: [shape])
        body.physicsBody = PhysicsBodyComponent(
            massProperties: .init(shape: shape, mass: 0.02),
            material: .generate(friction: 0.6, restitution: 0.4),
            mode: .dynamic)
        return body
    }
}
