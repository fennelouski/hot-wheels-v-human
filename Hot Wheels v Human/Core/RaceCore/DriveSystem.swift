//
//  DriveSystem.swift
//  Hot Wheels v Human
//
//  Slot-car propulsion: constant drive force along the lane spline,
//  PD steering toward it, soft magnet while near it. Straying far enough
//  to leave the lane is recovered from, not surrendered to — a car only
//  gets real air deliberately (ramp, boost), and the track reels back
//  anything still out there after the grace window.
//  All gains live in RaceTuning.
//

import RealityKit

struct DriveSystem: System {
    static let query = EntityQuery(where: .has(CarComponent.self) && .has(LaneFollowComponent.self))

    init(scene: Scene) {}

    func update(context: SceneUpdateContext) {
        guard RaceEventBus.shared.raceActive else { return }
        // Clamped like RaceRulesSystem's: an asset-load hitch delivers a
        // multi-second frame, and raw dt would burn the whole recovery
        // grace window in one step.
        let dt = min(Float(context.deltaTime), 0.1)
        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard let car = entity as? ModelEntity,
                  var follow = car.components[LaneFollowComponent.self],
                  var state = car.components[CarComponent.self],
                  !state.finished, !follow.waypoints.isEmpty else { continue }

            // Burn the post-GO dt spike with zero force (see CarComponent).
            if state.warmupFrames > 0 {
                state.warmupFrames -= 1
                car.components.set(state)
                continue
            }

            let position = car.position(relativeTo: nil)

            // Never target waypoint 0: previous == target there, the tangent
            // degenerates to zero, and the guard below skips the car — a car
            // spawned ≥ lookahead from waypoint 0 parked forever (sim drills).
            if follow.nextIndex == 0, follow.waypoints.count > 1 {
                follow.nextIndex = 1
            }

            // Re-acquire the lane: jump to the nearest UPCOMING waypoint
            // within a short window. A physics hitch can integrate ~0.1 s
            // in one frame and move the car past its target; a follower
            // that only advances within the lookahead then strands and
            // drives the car dead-straight forever (sim drills). The
            // window stays SMALL (1 m of lane) so a car at the loop's
            // base can never re-acquire the ground-level lane that passes
            // beside the ring and skip the climb.
            var nearest = follow.nextIndex
            var nearestDistance = simd_length(follow.waypoints[nearest] - position)
            for j in follow.nextIndex..<min(follow.nextIndex + 10, follow.waypoints.count) {
                let d = simd_length(follow.waypoints[j] - position)
                if d < nearestDistance { nearest = j; nearestDistance = d }
            }
            follow.nextIndex = nearest

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

            var velocity = car.physicsMotion?.linearVelocity ?? .zero
            var speed = simd_length(velocity)
            let chassis = state.design.chassis
            let tires = state.design.tires

            // Clamp the velocity itself, not just the forces: depenetration
            // hands back speeds no force-side guard can undo afterwards, and
            // that single frame is what launches a car off the map.
            let ceiling = RaceTuning.maxSpeed[chassis]! * RaceTuning.speedCeilingFactor
            if speed > ceiling, var motion = car.physicsMotion {
                velocity *= ceiling / speed
                speed = ceiling
                motion.linearVelocity = velocity
                car.components.set(motion)
            }

            let toCar = position - previous
            let along = simd_dot(toCar, tangent)
            let lateral = toCar - tangent * along
            let offset = simd_length(lateral)

            // Drive/steer only while near the lane — and never past its
            // END: lateral offset is measured against an infinite line, so
            // a car that overshot the finish would be driven dead-straight
            // to the edge of the world (sim drills).
            let pastEnd = follow.nextIndex >= follow.waypoints.count - 1
                && along > tangentLength + 0.1
            var force = SIMD3<Float>.zero
            if offset < RaceTuning.offSplineCutoff, !pastEnd {
                state.offLaneSeconds = 0
                if speed < RaceTuning.maxSpeed[chassis]! * RaceTuning.tireSpeedFactor[tires]! {
                    force += tangent * RaceTuning.driveForce[chassis]!
                }
                // Loop motor: on a loop piece the slot grips the car like
                // the booster wheels in a real Hot Wheels set — slow cars
                // get pushed (every car makes the loop), hot cars get
                // braked (cruise entry flung them off the ring top).
                if follow.loopRanges.contains(where: { $0.contains(follow.nextIndex) }) {
                    let alongSpeed = simd_dot(velocity, tangent)
                    if alongSpeed < RaceTuning.loopCarrySpeed {
                        force += tangent * (chassis.mass * RaceTuning.loopMotorAccel)
                    } else if alongSpeed > RaceTuning.loopSpeedCap {
                        force -= tangent * (chassis.mass * RaceTuning.loopMotorAccel)
                    }
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
                        let grip = RaceTuning.corneringGrip(chassis, tires)
                        if need > grip {
                            centripetal *= grip / need
                        }
                        force += centripetal
                    }
                }
            } else if !pastEnd {
                // Off the rails. The track reels the car back rather than
                // surrendering it — losing a car to a physics accident is a
                // kid watching it disappear for no reason, not a skill
                // check. Same bargain as the loop motor.
                //
                // The grace window is what keeps jumps: deliberate air (a
                // ramp, a boosted lip) is over long before it elapses, so
                // this never fights a jump — only a flight that has clearly
                // stopped being one.
                state.offLaneSeconds += dt
                if state.offLaneSeconds > RaceTuning.laneRecoveryGrace {
                    let lateralSpeed = velocity - tangent * simd_dot(velocity, tangent)
                    var recover = -(lateral * RaceTuning.laneRecoveryKp
                                    + lateralSpeed * RaceTuning.laneRecoveryKd) * chassis.mass
                    let magnitude = simd_length(recover)
                    if magnitude > RaceTuning.laneRecoveryMaxForce {
                        recover *= RaceTuning.laneRecoveryMaxForce / magnitude
                    }
                    force += recover
                }
            }

            // Unstick. Escalating shove along the lane for a car that has
            // stopped making progress, wherever it is — the loop motor's
            // bargain applied to every seam. Without it the heavy chassis
            // burned all five lives on one spot and DNF'd every race (sim
            // drills: every death "stuck", near-identical coordinate).
            //
            // Reads the rules system's anchor-based counter rather than raw
            // speed, so a car jittering or spinning in place still counts as
            // stuck; it runs one frame behind (DriveSystem registers first),
            // which is nothing at these timescales.
            if state.stuckSeconds > RaceTuning.unstickDelay {
                let over = state.stuckSeconds - RaceTuning.unstickDelay
                let accel = min(over * RaceTuning.unstickRamp,
                                RaceTuning.unstickMaxAccel)
                force += tangent * (chassis.mass * accel)
                force.y += chassis.mass * accel * RaceTuning.unstickLift
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
