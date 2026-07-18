//
//  DriveSystem.swift
//  Hot Wheels v Human
//
//  Slot-car propulsion: constant drive force along the lane spline,
//  PD steering toward it, soft magnet while near it. Cars can't leave
//  their lane except by physics accident — flying off IS the game.
//  All gains live in RaceTuning.
//

import RealityKit

struct DriveSystem: System {
    static let query = EntityQuery(where: .has(CarComponent.self) && .has(LaneFollowComponent.self))

    init(scene: Scene) {}

    func update(context: SceneUpdateContext) {
        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard let car = entity as? ModelEntity,
                  var follow = car.components[LaneFollowComponent.self],
                  var state = car.components[CarComponent.self],
                  !state.finished, !follow.waypoints.isEmpty else { continue }

            let position = car.position(relativeTo: nil)

            // Advance the target waypoint until it's ahead by the lookahead.
            while follow.nextIndex < follow.waypoints.count - 1,
                  simd_length(follow.waypoints[follow.nextIndex] - position) < RaceTuning.steeringLookahead {
                follow.nextIndex += 1
            }
            let target = follow.waypoints[follow.nextIndex]
            let previous = follow.waypoints[max(follow.nextIndex - 1, 0)]
            var tangent = target - previous
            let tangentLength = simd_length(tangent)
            guard tangentLength > 1e-5 else { continue }
            tangent /= tangentLength

            let velocity = car.physicsMotion?.linearVelocity ?? .zero
            let speed = simd_length(velocity)
            let chassis = state.design.chassis

            let toCar = position - previous
            let along = simd_dot(toCar, tangent)
            let lateral = toCar - tangent * along
            let offset = simd_length(lateral)

            // Off the rails → physics owns the car (destruction rules will
            // catch it). Drive/steer only while near the lane.
            var force = SIMD3<Float>.zero
            if offset < RaceTuning.offSplineCutoff {
                if speed < RaceTuning.maxSpeed[chassis]! {
                    force += tangent * RaceTuning.driveForce[chassis]!
                }
                // PD steering, clamped — unclamped PD catapults stray cars.
                let lateralSpeed = velocity - tangent * simd_dot(velocity, tangent)
                var steer = -(lateral * RaceTuning.steeringKp
                              + lateralSpeed * RaceTuning.steeringKd) * chassis.mass
                if offset < RaceTuning.laneMagnetRange {
                    steer -= lateral * RaceTuning.laneMagnetStrength
                }
                let magnitude = simd_length(steer)
                if magnitude > RaceTuning.steeringMaxForce {
                    steer *= RaceTuning.steeringMaxForce / magnitude
                }
                force += steer

                // Centripetal feedforward — the slot pushes the car around
                // the curve (PD alone can't: it needs metres of error to
                // reach cornering force). (t₂−t₁)/ds = κ·n̂ toward the curve
                // center. Vertical stays with track contact (loops work
                // today); capped at corneringGrip so boosted cars still fly.
                if follow.nextIndex + 1 < follow.waypoints.count {
                    var ahead = follow.waypoints[follow.nextIndex + 1] - target
                    let aheadLength = simd_length(ahead)
                    if aheadLength > 1e-5 {
                        ahead /= aheadLength
                        // Keep only the normal component: raw (t₂−t₁) has a
                        // small backward-tangential part that reads as brakes
                        // (~12 N at the loop entry — enough to stall the climb).
                        var turn = ahead - tangent
                        turn -= tangent * simd_dot(turn, tangent)
                        turn.y = 0
                        let ds = (tangentLength + aheadLength) / 2
                        var centripetal = turn * (chassis.mass * speed * speed / ds)
                        let need = simd_length(centripetal)
                        let grip = RaceTuning.corneringGrip(chassis)
                        if need > grip {
                            centripetal *= grip / need
                        }
                        force += centripetal
                    }
                }
            }
            force -= velocity * (chassis.dragCoefficient * speed)

            car.addForce(force, relativeTo: nil)

            if state.pendingBoost {
                car.applyLinearImpulse(tangent * RaceTuning.boostImpulse, relativeTo: nil)
                state.pendingBoost = false
            }

            // Keep the visual pointed along the travel direction (wheels are
            // decorative in v1 — the physics body is a box).
            if speed > 0.2 {
                let flat = simd_normalize(SIMD3<Float>(velocity.x, 0, velocity.z))
                let yaw = atan2(flat.x, flat.z)
                car.orientation = simd_slerp(car.orientation,
                                             simd_quatf(angle: yaw, axis: [0, 1, 0]),
                                             0.2)
            }

            car.components.set(follow)
            car.components.set(state)
        }
    }
}
