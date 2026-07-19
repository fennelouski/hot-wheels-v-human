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
                    state.pendingBoost = true
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
}
