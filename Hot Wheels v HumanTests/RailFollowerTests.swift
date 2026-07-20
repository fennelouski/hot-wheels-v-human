//
//  RailFollowerTests.swift
//  Hot Wheels v HumanTests
//
//  Pins the rail-mode contract: cars advance monotonically along the
//  spline, never leave it laterally, go ballistic off a cliff lip and
//  land back ON the lane line, and stay glued through loop ranges.
//  DriveSystem.railStep is pure (no scene), so this drives it directly.
//

import Foundation
import RealityKit
import Testing
@testable import Hot_Wheels_v_Human

struct RailFollowerTests {

    private func makeState(design: CarDesign = .demoPair[0]) -> CarComponent {
        CarComponent(playerID: UUID(), design: design, livesLeft: 5, rideHeight: 0.05)
    }

    /// Flat 3 m straight, waypoints every 0.1 m.
    private func flatLane() -> LaneFollowComponent {
        let wp = (0...30).map { SIMD3<Float>(0, 0, Float($0) * 0.1) }
        return LaneFollowComponent(waypoints: wp)
    }

    @Test func advancesMonotonicallyAndStaysOnLane() {
        var follow = flatLane()
        var state = makeState()
        var lastZ: Float = -1
        for _ in 0..<300 {
            let pose = DriveSystem.railStep(follow: &follow, state: &state, dt: 1 / 60)
            #expect(pose.position.z >= lastZ)
            lastZ = pose.position.z
            #expect(abs(pose.position.x) <= RaceTuning.driftMax + 0.001)
            #expect(!follow.airborne)   // flats never launch
        }
        #expect(follow.speed > 1)                    // it actually drives
        #expect(follow.nextIndex == follow.waypoints.count - 1)
        #expect(follow.fraction == 1)                // parked at the line
    }

    @Test func cliffLipGoesBallisticAndLandsOnTheLane() {
        // 1.5 m of flat run-up, then the lane drops 0.5 m over one segment
        // (a ramp lip), then continues flat below.
        var wp = (0...15).map { SIMD3<Float>(0, 0.5, Float($0) * 0.1) }
        wp += (16...40).map { SIMD3<Float>(0, 0, Float($0) * 0.1) }
        var follow = LaneFollowComponent(waypoints: wp)
        follow.height = 0.5
        var state = makeState()

        var flew = false
        for _ in 0..<600 {
            let pose = DriveSystem.railStep(follow: &follow, state: &state, dt: 1 / 60)
            if follow.airborne {
                flew = true
                // The arc stays on the imaginary line above the lane —
                // never below the bed, never off to the side.
                #expect(pose.position.x == 0)
                #expect(follow.height >= -0.001)
            }
        }
        #expect(flew)                                 // the lip launched it
        #expect(!follow.airborne)                     // ...and it landed
        #expect(follow.nextIndex == follow.waypoints.count - 1)
    }

    @Test func loopStaysGluedAndUpsideDownAtTheTop() {
        // Quarter-circle climb into a full 0.4 m loop, like the real piece.
        let r: Float = 0.4
        var wp: [SIMD3<Float>] = (0...10).map { [0, 0, Float($0) * 0.1] }
        let n = 26
        for i in 1...n {
            let a = Float(i) / Float(n) * 2 * .pi
            wp.append([0, r * (1 - cos(a)), 1 + r * sin(a)])
        }
        wp += (1...10).map { [0, 0, 1 + Float($0) * 0.1] }
        var follow = LaneFollowComponent(waypoints: wp,
                                         loopRanges: [10...(10 + n)],
                                         laterals: wp.map { _ in [1, 0, 0] })
        var state = makeState()

        var sawInverted = false
        for _ in 0..<600 {
            let pose = DriveSystem.railStep(follow: &follow, state: &state, dt: 1 / 60)
            #expect(!follow.airborne)                 // the slot owns the ring
            let up = pose.orientation.act(SIMD3<Float>(0, 1, 0))
            if up.y < -0.7 { sawInverted = true }
        }
        #expect(sawInverted)                          // rolled through the top
        #expect(follow.nextIndex == follow.waypoints.count - 1)
    }

    /// The wheels ride ON the bed, all the way round the loop. The follower
    /// floats a car `rideHeight` off the lane along the track's up vector,
    /// and `CarFactory.rideHeight` is what makes that land on the drawn
    /// surface rather than inside it — 0.4 × car height (the slim collision
    /// box's bottom, well above the tyres) measured against a lane line that
    /// itself sits 13 mm under the bed put every wheel through the track,
    /// most visibly on the ring where "down" faces the camera.
    @Test func wheelsRideOnTheBedThroughTheLoop() {
        /// Distance from `p` to the segment ab — the lane is a polyline, and
        /// nearest-waypoint would be off by up to half the 0.1 m spacing.
        func distance(_ p: SIMD3<Float>, _ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
            let ab = b - a
            let l2 = simd_length_squared(ab)
            guard l2 > 1e-12 else { return simd_length(p - a) }
            let t = max(0, min(1, simd_dot(p - a, ab) / l2))
            return simd_length(p - (a + ab * t))
        }

        let lanes = TrackLayoutSolver.solve(.demo).lanes   // .demo carries a loop
        let carHeight: Float = 0.09                        // a chunky toy car
        // Independent of the helper on purpose: the origin has to clear the
        // lane by the car's own half-height (visual centred → that IS the
        // tyres) plus the bed's own offset, or the wheels are in the track.
        let needed = carHeight / 2 + RaceTuning.bedSurfaceHeight
        var follow = LaneFollowComponent(waypoints: lanes.left, laterals: lanes.laterals)
        var state = CarComponent(playerID: UUID(), design: .demoPair[0], livesLeft: 5,
                                 rideHeight: CarFactory.rideHeight(visualHeight: carHeight))

        var checked = 0
        for _ in 0..<3000 {
            let pose = DriveSystem.railStep(follow: &follow, state: &state, dt: 1 / 60)
            guard !follow.airborne else { continue }   // air is allowed to leave the bed
            let clearance = follow.waypoints.indices.dropLast().map {
                distance(pose.position, follow.waypoints[$0], follow.waypoints[$0 + 1])
            }.min()!
            #expect(clearance >= needed - 0.002)
            // ...and no hovering: at most a drift's worth of sideways slide
            // on top, which stays in the bed plane.
            #expect(clearance <= (needed * needed + RaceTuning.driftMax * RaceTuning.driftMax)
                        .squareRoot() + 0.002)
            checked += 1
        }
        #expect(checked > 1000)
        #expect(follow.nextIndex == follow.waypoints.count - 1)   // it got round
    }

    @Test func boostExtendsAJump() {
        func jumpDistance(boost: Bool) -> Float {
            var wp = (0...29).map { SIMD3<Float>(0, 1, Float($0) * 0.1) }
            wp += (30...120).map { SIMD3<Float>(0, 0, Float($0) * 0.1) }
            var follow = LaneFollowComponent(waypoints: wp)
            follow.height = 1
            var state = makeState()
            var launch: Float?
            for _ in 0..<600 {
                if boost, follow.nextIndex > 20, !follow.airborne, launch == nil {
                    state.boostMeter = 1
                    state.boosting = true
                    state.boostHoldGrace = RaceTuning.boostHoldGrace
                }
                let pose = DriveSystem.railStep(follow: &follow, state: &state, dt: 1 / 60)
                if follow.airborne, launch == nil { launch = pose.position.z }
                if let launch, !follow.airborne { return pose.position.z - launch }
            }
            return 0
        }
        let plain = jumpDistance(boost: false)
        let boosted = jumpDistance(boost: true)
        #expect(plain > 0)
        #expect(boosted > plain + 0.1)   // boost status shapes the arc
    }

    // MARK: Boost state machine (DriveSystem.stepBoost)

    private let step: Float = 1 / 60

    /// Runs the boost machine for up to `seconds`, holding the button (or
    /// not), and STOPS the moment a running burn ends — otherwise the meter
    /// starts recharging and hides what the burn actually cost.
    /// Returns total thrust·seconds, so "was that boost bigger?" has a number.
    @discardableResult
    private func burn(_ state: inout CarComponent, seconds: Float,
                      holding: Bool) -> Float {
        var impulse: Float = 0
        for _ in 0..<Int(seconds / step) {
            if holding { state.boostHoldGrace = RaceTuning.boostHoldGrace }
            let wasBoosting = state.boosting
            impulse += DriveSystem.stepBoost(&state, dt: step) * step
            if wasBoosting && !state.boosting { break }
        }
        return impulse
    }

    @Test func meterArmsAtOneThenOverchargesToTwoAtHalfSpeed() {
        var state = makeState()
        burn(&state, seconds: RaceTuning.boostChargeTime, holding: false)
        #expect(abs(state.boostMeter - 1) < 0.02)          // armed on schedule

        // Overcharge costs double the track: another full charge time only
        // buys half a bottle.
        burn(&state, seconds: RaceTuning.boostChargeTime, holding: false)
        #expect(abs(state.boostMeter - 1.5) < 0.02)

        burn(&state, seconds: RaceTuning.boostChargeTime * 2, holding: false)
        #expect(state.boostMeter == RaceTuning.boostMaxCharge)   // and it caps
    }

    /// A stab of the button is still a real boost, and holding pulls harder
    /// for longer — the whole point of the hold mechanic.
    @Test func tapBurnsTheMinimumAndHoldingBurnsBiggerAndLonger() {
        var tapped = makeState()
        tapped.boostMeter = 1
        tapped.boosting = true
        let tapImpulse = burn(&tapped, seconds: 2, holding: false)

        // Released instantly, but the minimum duration still ran.
        #expect(!tapped.boosting)
        let spent = 1 - tapped.boostMeter
        #expect(abs(spent - RaceTuning.boostMinDuration / RaceTuning.boostDrainTime) < 0.02)

        var held = makeState()
        held.boostMeter = 1
        held.boosting = true
        let holdImpulse = burn(&held, seconds: 5, holding: true)

        #expect(!held.boosting)              // ran the bottle dry and stopped
        #expect(held.boostMeter == 0)
        #expect(holdImpulse > tapImpulse * 3)   // longer hold, far more push
    }

    /// A full overcharged hold must never reach the anti-fling velocity
    /// clamp: clip that and boost silently stops working, which reads as a
    /// dead button.
    @Test func boostStaysUnderTheSpeedClamp() {
        for chassis in ChassisClass.allCases {
            for tires in TireType.allCases {
                var design = CarDesign.demoPair[0]
                design.chassis = chassis
                design.tires = tires
                var follow = LaneFollowComponent(
                    waypoints: (0...4000).map { SIMD3<Float>(0, 0, Float($0) * 0.1) })
                var state = makeState(design: design)
                state.boostMeter = RaceTuning.boostMaxCharge
                state.boosting = true
                var top: Float = 0
                for _ in 0..<Int(20 / step) {
                    state.boostHoldGrace = RaceTuning.boostHoldGrace
                    _ = DriveSystem.railStep(follow: &follow, state: &state, dt: step)
                    top = max(top, follow.speed)
                }
                let ceiling = RaceTuning.maxSpeed[chassis]! * RaceTuning.speedCeilingFactor
                    * RaceTuning.railSpeedScale
                #expect(top < ceiling)
                // …and it was a real boost, not a rounding error.
                #expect(top > RaceTuning.maxSpeed[chassis]! * RaceTuning.railSpeedScale * 1.2)
            }
        }
    }
}
