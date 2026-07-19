//
//  RaceTuningTests.swift
//  Hot Wheels v HumanTests
//
//  Pins the tire tradeoff: the tables cover every case (DriveSystem
//  force-unwraps them) and the loop-gating math that makes wheel choice
//  a real decision keeps holding as numbers get tuned.
//

import Testing
@testable import Hot_Wheels_v_Human

struct RaceTuningTests {

    @Test func tireTablesCoverEveryCase() {
        for tire in TireType.allCases {
            #expect(RaceTuning.tireSpeedFactor[tire] != nil)
            #expect(RaceTuning.tireGripFactor[tire] != nil)
        }
    }

    /// Standard is the untouched baseline; slicks add top speed, grippy adds
    /// cornering grip, and neither factor may dip below 1 — sim drills showed
    /// a sub-1 speed factor sinks loop entry and a sub-1 grip factor flirts
    /// with the "flies off without boosting" bug. The tires' costs are
    /// physical (friction bleed), not numeric.
    @Test func tireTradeoffOrdering() {
        #expect(RaceTuning.tireSpeedFactor[.standard] == 1.0)
        #expect(RaceTuning.tireGripFactor[.standard] == 1.0)
        #expect(RaceTuning.tireSpeedFactor[.slickRacing]! > 1.0)
        #expect(RaceTuning.tireGripFactor[.grippyOffroad]! > 1.0)
        for tires in TireType.allCases {
            #expect(RaceTuning.tireSpeedFactor[tires]! >= 1.0)
            #expect(RaceTuning.tireGripFactor[tires]! >= 1.0)
        }
        // The physical spread the picker's stat bars are built on.
        #expect(RaceTuning.tireStaticFriction[.slickRacing]!
                < RaceTuning.tireStaticFriction[.standard]!)
        #expect(RaceTuning.tireStaticFriction[.standard]!
                < RaceTuning.tireStaticFriction[.grippyOffroad]!)
    }

    /// Loop entry needs loopMinEntrySpeed. The designed outcomes:
    /// Balanced + Standard just makes it (RaceCore README invariant),
    /// slicks lift the light chassis over the bar, and heavy clears it on
    /// any tires — a 0.93 grippy factor once sent heavy+grippy under the
    /// PRACTICAL entry speed (grippy friction bleeds speed inside the loop)
    /// and it lost all five lives on the demo track, so heavy keeps real
    /// headroom above the theoretical bar.
    @Test func tiresGateTheLoop() {
        func top(_ c: ChassisClass, _ t: TireType) -> Float {
            RaceTuning.maxSpeed[c]! * RaceTuning.tireSpeedFactor[t]!
        }
        let loop = RaceTuning.loopMinEntrySpeed
        #expect(top(.balancedFormula, .standard) >= loop)
        #expect(top(.balancedFormula, .slickRacing) >= loop)
        #expect(top(.superlightDrift, .standard) < loop)
        #expect(top(.superlightDrift, .slickRacing) >= loop)
        for tires in TireType.allCases {
            #expect(top(.heavyMuscle, tires) >= loop * 1.1)
        }
    }

    /// The loop motor's guarantee: it feeds force around the whole circle,
    /// so its carry speed doesn't need the free-flight entry bar — but it
    /// MUST clear the ring-top minimum √(g·r) with margin, sit below the
    /// brake cap, and out-pull gravity on a vertical climb.
    @Test func loopMotorActuallyCarries() {
        let ringTopMinimum = (9.81 * RaceTuning.smallCurveRadius).squareRoot()
        #expect(RaceTuning.loopCarrySpeed > ringTopMinimum * 1.2)
        #expect(RaceTuning.loopCarrySpeed < RaceTuning.loopSpeedCap)
        #expect(RaceTuning.loopMotorAccel > 9.81 * 1.5)
    }

    /// Plain (unboosted) driving must corner the small curve clean on every
    /// build — flying off without touching boost is a bug, not the game.
    @Test func cruiseSpeedNeverExceedsGrip() {
        for chassis in ChassisClass.allCases {
            for tires in TireType.allCases {
                let top = RaceTuning.maxSpeed[chassis]! * RaceTuning.tireSpeedFactor[tires]!
                let need = RaceTuning.chassisMass[chassis]! * top * top
                    / RaceTuning.smallCurveRadius
                #expect(RaceTuning.corneringGrip(chassis, tires) >= need)
            }
        }
    }

    /// The anti-fling speed clamp exists to kill depenetration spikes, and
    /// it must never touch a legitimate boost — clip that and boosting just
    /// silently stops working, which reads as a dead button.
    @Test func speedClampNeverClipsABoost() {
        for chassis in ChassisClass.allCases {
            let ceiling = RaceTuning.maxSpeed[chassis]! * RaceTuning.speedCeilingFactor
            for tires in TireType.allCases {
                let top = RaceTuning.maxSpeed[chassis]! * RaceTuning.tireSpeedFactor[tires]!
                let boosted = top + RaceTuning.boostImpulse / RaceTuning.chassisMass[chassis]!
                #expect(ceiling > boosted)
            }
        }
    }

    /// Recovery is a rule, not steering feel: it has to outmuscle the
    /// in-lane gains, and it has to leave a grace window or ramp jumps and
    /// boosted lips get yanked out of the air.
    @Test func laneRecoveryOutmusclesSteeringButLeavesRoomToJump() {
        #expect(RaceTuning.laneRecoveryKp > RaceTuning.steeringKp)
        #expect(RaceTuning.laneRecoveryKd > RaceTuning.steeringKd)
        #expect(RaceTuning.laneRecoveryMaxForce > RaceTuning.steeringMaxForce)
        #expect(RaceTuning.laneRecoveryGrace > 0.25)
        // Recovery starts outside the band the normal magnet already covers.
        #expect(RaceTuning.offSplineCutoff > RaceTuning.laneMagnetRange)
    }

    /// The unstick shove has to get a real run at a wedged car before the
    /// rescue fires, or it never gets the chance to free it gently — and
    /// it has to comfortably beat gravity to be worth applying at all.
    @Test func unstickShovesWellBeforeTheRescue() {
        #expect(RaceTuning.unstickDelay < RaceTuning.stuckTime)
        // Enough runway left to reach full strength before the rescue.
        let rampSeconds = (RaceTuning.stuckTime - RaceTuning.unstickDelay)
        #expect(rampSeconds * RaceTuning.unstickRamp >= RaceTuning.unstickMaxAccel)
        #expect(RaceTuning.unstickMaxAccel > 9.81 * 4)
        // Some of the shove goes upward: a dead-stopped car is usually
        // interpenetrating, and pure tangent force just presses it in.
        #expect(RaceTuning.unstickLift > 0)
    }
}
