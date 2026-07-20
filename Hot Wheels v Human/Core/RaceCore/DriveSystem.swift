//
//  DriveSystem.swift
//  Hot Wheels v Human
//
//  Two propulsion modes, picked per car by its physics body mode (set at
//  spawn from RaceTuning.railPinned):
//
//  RAIL (kinematic, default): the car is pinned to its lane spline and can
//  never leave the track. One scalar speed integrates drive/drag/slope/loop
//  motor; the car is PLACED at spline(d) each frame, oriented by the track
//  frame (so loops roll it upside down correctly). Corners read as
//  stat-driven drift (lateral offset + slip-angle yaw); crests and ramp
//  lips launch a ballistic arc that stays above the lane line and lands
//  when the arc meets the bed — jump length falls out of speed/boost/stats.
//
//  CHAOS (dynamic): the original slot-car force model — constant drive
//  force along the spline, PD steering, soft magnet, recovery reel-in,
//  unstick shove. Kept as the Test Mode A/B alternative.
//
//  All gains live in RaceTuning.
//

import RealityKit

struct DriveSystem: System {
    static let query = EntityQuery(where: .has(CarComponent.self) && .has(LaneFollowComponent.self))

    init(scene: Scene) {}

    func update(context: SceneUpdateContext) {
        guard RaceEventBus.shared.raceActive else { return }
        // Clamped: an asset-load hitch delivers a multi-second frame; raw dt
        // would teleport a rail car metres ahead (or burn chaos mode's whole
        // recovery grace window) in one step.
        let dt = min(Float(context.deltaTime), 0.1)
        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard let car = entity as? ModelEntity,
                  var follow = car.components[LaneFollowComponent.self],
                  var state = car.components[CarComponent.self],
                  !state.finished, follow.waypoints.count > 1 else { continue }

            if car.physicsBody?.mode == .kinematic {
                let pose = Self.railStep(follow: &follow, state: &state, dt: dt)
                car.setPosition(pose.position, relativeTo: nil)
                car.orientation = simd_slerp(car.orientation, pose.orientation,
                                             RaceTuning.railOrientationBlend)
            } else {
                chaoticStep(car: car, follow: &follow, state: &state, dt: dt)
            }

            car.components.set(follow)
            car.components.set(state)
        }
    }

    // MARK: Boost

    /// Charge / burn / release, one frame. Returns the boost acceleration
    /// to add this frame, m/s² (0 when not boosting). Pure — both drive
    /// modes call it, so the meter behaves identically on rails and in chaos.
    static func stepBoost(_ state: inout CarComponent, dt: Float) -> Float {
        state.boostHoldGrace = max(0, state.boostHoldGrace - dt)

        guard state.boosting else {
            // Overcharge past 1 at half rate — waiting is the trade.
            let rate = state.boostMeter < 1 ? 1 : RaceTuning.boostOverchargeRate
            state.boostMeter = min(RaceTuning.boostMaxCharge,
                                   state.boostMeter + rate * dt / RaceTuning.boostChargeTime)
            return 0
        }

        state.boostMeter = max(0, state.boostMeter - dt / RaceTuning.boostDrainTime)
        state.boostSeconds += dt
        // Thrust builds over the hold: a stab kicks, a long hold pulls.
        let ramp = 0.5 + 0.5 * min(1, state.boostSeconds / RaceTuning.boostRampTime)
        let accel = (RaceTuning.boostAccel[state.design.chassis] ?? 0) * ramp

        let owed = state.boostSeconds < RaceTuning.boostMinDuration
        if state.boostMeter <= 0 || (state.boostHoldGrace <= 0 && !owed) {
            state.boosting = false
            state.boostSeconds = 0
        }
        return accel
    }

    // MARK: Rail mode

    /// Pure spline-pinned integration step — no scene access, unit-testable.
    /// Advances `follow` by dt and returns where the car body belongs.
    static func railStep(follow: inout LaneFollowComponent, state: inout CarComponent,
                         dt: Float) -> (position: SIMD3<Float>, orientation: simd_quatf) {
        let wp = follow.waypoints
        let chassis = state.design.chassis
        let tires = state.design.tires
        let g: Float = 9.81 * RaceTuning.gravityScale
        // Segment is [nextIndex−1, nextIndex]; index 0 has no previous.
        if follow.nextIndex < 1 { follow.nextIndex = 1 }

        func tangent(at i: Int) -> SIMD3<Float> {
            let d = wp[min(i, wp.count - 1)] - wp[max(i - 1, 0)]
            let l = simd_length(d)
            return l > 1e-6 ? d / l : [0, 0, 1]
        }
        var t = tangent(at: follow.nextIndex)
        var inLoop = follow.loopRanges.contains { $0.contains(follow.nextIndex) }
        let scale = RaceTuning.railSpeedScale
        let top = RaceTuning.maxSpeed[chassis]! * RaceTuning.tireSpeedFactor[tires]! * scale

        // ── Scalar speed: target-speed model. Terrain shapes an effective
        // cruise target — uphill/ramps lower it, downhill raises it,
        // corners (via last frame's drift) ease it — drive pushes toward
        // it from below, the return bleed settles overshoot back onto it
        // on the straights. One mechanism, all the pacing behaviors.
        var accel: Float = 0
        if follow.airborne {
            // No drive in the air; the arc owns the pacing.
        } else if inLoop {
            // The slot owns the loop: band control, no terrain shaping.
            if follow.speed < RaceTuning.loopCarrySpeed * scale {
                accel += RaceTuning.loopMotorAccel
            } else if follow.speed > RaceTuning.loopSpeedCap * scale {
                accel -= RaceTuning.loopMotorAccel
            }
        } else {
            let terrain = 1 - RaceTuning.railSlopeSpeedFactor * t.y
                - RaceTuning.railCornerSlowFactor * min(1, abs(follow.drift) / RaceTuning.driftMax)
            let cruise = top * max(0.3, terrain)
            if follow.speed < cruise {
                accel += RaceTuning.driveForce[chassis]! / chassis.mass * scale
            } else {
                accel -= (follow.speed - cruise) * RaceTuning.railReturnRate
            }
        }
        accel -= chassis.dragCoefficient * follow.speed * follow.speed / chassis.mass
        // Boost pushes even in the air and inside a loop — it's the one
        // thing the kid controls, so it always does something.
        accel += Self.stepBoost(&state, dt: dt)
        follow.speed += accel * dt
        if follow.airborne {
            // Never negative: a steep climb's drag can out-pull the drive
            // mid-jump, and a negative speed would walk the car back down
            // its own lane. Rail progress only ever goes forward.
            follow.speed = max(0, follow.speed)
        } else {
            // Kid-first floor: no seam or slope ever strands a pinned car.
            follow.speed = max(follow.speed, RaceTuning.minCrawlSpeed)
        }
        follow.speed = min(follow.speed,
                           RaceTuning.maxSpeed[chassis]! * RaceTuning.speedCeilingFactor * scale)

        // ── Advance along the spline (airborne too: the "imaginary line"
        // above the lane is the lane's own path, so jumps always land on it).
        var travel = follow.speed * dt
        while travel > 0 {
            let len = max(simd_length(wp[follow.nextIndex] - wp[follow.nextIndex - 1]), 1e-6)
            let remaining = (1 - follow.fraction) * len
            if travel < remaining {
                follow.fraction += travel / len
                break
            }
            travel -= remaining
            if follow.nextIndex < wp.count - 1 {
                follow.nextIndex += 1
                follow.fraction = 0
            } else {
                follow.fraction = 1   // end of lane — rules catch the finish
                break
            }
        }

        // ── Track frame at the new position.
        let a = wp[follow.nextIndex - 1], b = wp[follow.nextIndex]
        var position = simd_mix(a, b, SIMD3(repeating: follow.fraction))
        t = tangent(at: follow.nextIndex)
        var lateral: SIMD3<Float>
        if follow.laterals.count == wp.count {
            lateral = simd_mix(follow.laterals[follow.nextIndex - 1],
                               follow.laterals[follow.nextIndex],
                               SIMD3(repeating: follow.fraction))
        } else {
            lateral = [t.z, 0, -t.x]   // horizontal left of the tangent
        }
        let lateralLength = simd_length(lateral)
        lateral = lateralLength > 1e-5 ? lateral / lateralLength : [1, 0, 0]
        var up = simd_cross(t, lateral)
        let upLength = simd_length(up)
        up = upLength > 1e-5 ? up / upLength : [0, 1, 0]

        // ── Vertical: ballistic arc vs the bed. Grounded cars inherit the
        // bed height; when a gravity-only arc would clear the bed (crest,
        // ramp lip — the track falling away faster than gravity) the car
        // flies it, and lands where the arc meets the bed again.
        inLoop = follow.loopRanges.contains { $0.contains(follow.nextIndex) }
        let bedY = position.y
        if inLoop {
            // The slot owns the loop — no air on the ring.
            follow.airborne = false
            follow.height = bedY
            follow.verticalVelocity = follow.speed * t.y
        } else if follow.airborne {
            follow.verticalVelocity -= g * dt
            follow.height += follow.verticalVelocity * dt
            if follow.height <= bedY {   // touchdown
                follow.height = bedY
                follow.airborne = false
                follow.verticalVelocity = follow.speed * t.y
            }
        } else {
            let ballisticVY = follow.verticalVelocity - g * dt
            if ballisticVY > follow.speed * t.y + RaceTuning.launchThreshold {
                // Gravity can't pull the car down as fast as the bed falls
                // away — crest or ramp lip. Comparing VELOCITIES is frame-
                // phase independent; a height check only sampled the one
                // frame that crossed the lip and missed at slow speeds.
                follow.airborne = true
                follow.verticalVelocity = ballisticVY
                follow.height += ballisticVY * dt
                if follow.height <= bedY {   // micro-hop resolved in-frame
                    follow.airborne = false
                    follow.height = bedY
                    follow.verticalVelocity = follow.speed * t.y
                }
            } else {
                follow.height = bedY
                follow.verticalVelocity = follow.speed * t.y
            }
        }

        // ── Drift: corners demand v²·κ of grip; what the stats can't hold
        // becomes a lateral slide (capped inside the rails) + slip yaw.
        var driftTarget: Float = 0
        if !follow.airborne, !inLoop, follow.nextIndex + 1 < wp.count {
            let ahead = wp[follow.nextIndex + 1] - b
            let aheadLength = simd_length(ahead)
            let segLength = simd_length(b - a)
            if aheadLength > 1e-5, segLength > 1e-5 {
                let turn = ahead / aheadLength - t
                let signedCurvature = simd_dot(turn, lateral) / ((segLength + aheadLength) / 2)
                let response = follow.speed * follow.speed * signedCurvature
                    * RaceTuning.driftFactor[chassis]! / RaceTuning.tireGripFactor[tires]!
                    / RaceTuning.driftSaturationAccel
                // Turning left (+response) slides the car right (−lateral).
                driftTarget = -RaceTuning.driftMax * max(-1, min(1, response))
            }
        }
        follow.drift += (driftTarget - follow.drift) * min(1, RaceTuning.driftResponse * dt)

        // ── Pose.
        if follow.airborne { position.y = follow.height }
        position += lateral * follow.drift + up * state.rideHeight

        var forward = t
        if follow.airborne {
            // Nose follows the arc: up over the lip, down into the landing.
            let flat = SIMD3<Float>(t.x, 0, t.z)
            let flatLength = simd_length(flat)
            if flatLength > 1e-5 {
                forward = simd_normalize(flat / flatLength * follow.speed
                                         + SIMD3<Float>(0, follow.verticalVelocity, 0))
            }
            up = [0, 1, 0]
        }
        var right = simd_cross(up, forward)
        let rightLength = simd_length(right)
        right = rightLength > 1e-5 ? right / rightLength : [1, 0, 0]
        up = simd_cross(forward, right)
        var orientation = simd_quatf(simd_float3x3(columns: (right, up, forward)))
        if abs(follow.drift) > 0.001 {
            // Oversteer look: nose points into the turn while sliding out.
            let slip = RaceTuning.driftSlipAngle * (-follow.drift / RaceTuning.driftMax)
            orientation = simd_quatf(angle: slip, axis: up) * orientation
        }
        return (position, orientation)
    }

    // MARK: Chaos mode (the original force-based physics, unchanged)

    private func chaoticStep(car: ModelEntity, follow: inout LaneFollowComponent,
                             state: inout CarComponent, dt: Float) {
        // Burn the post-GO dt spike with zero force (see CarComponent).
        if state.warmupFrames > 0 {
            state.warmupFrames -= 1
            return
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
        guard tangentLength > 1e-5 else { return }
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

        let boostAccel = Self.stepBoost(&state, dt: dt)
        if boostAccel > 0 {
            car.addForce(tangent * (chassis.mass * boostAccel), relativeTo: nil)
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
    }
}
