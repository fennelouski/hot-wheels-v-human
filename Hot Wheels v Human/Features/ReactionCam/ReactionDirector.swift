//
//  ReactionDirector.swift
//  Hot Wheels v Human
//
//  Race happenings → driver reaction state machine (README spec):
//  idle → steering(l/r) → braced (loop coming) → boosted / crashed /
//  celebrating. Continuous inputs come in every frame via update();
//  discrete events via fire(). Min state hold so the PiP never flickers.
//  Pure logic — unit-tested; no RealityKit, no SwiftUI.
//

import Foundation
import Observation

nonisolated enum ReactionState: String, CaseIterable, Sendable {
    case idle
    case steerLeft
    case steerRight
    case braced
    case boosted
    case crashed
    case celebrating
}

@MainActor
@Observable
final class ReactionDirector {

    private(set) var state: ReactionState = .idle
    /// Smoothed continuous readouts for the PiP. `lean` −1…1 (+ = leaning
    /// into a left turn), `speed01` = fraction of the chassis top speed.
    private(set) var lean: Float = 0
    private(set) var speed01: Float = 0
    private var clock: TimeInterval = 0
    private var stateSince: TimeInterval = 0

    /// Continuous per-frame inputs. `yawRate` rad/s (+ = turning left),
    /// `loopAhead` = loop within RaceTuning.loopBraceLookahead seconds.
    func update(dt: TimeInterval, yawRate: Float, loopAhead: Bool, speed01: Float = 0) {
        clock += dt
        let blend = min(1, Float(dt) * RaceTuning.reactionMotionSmoothing)
        let leanTarget = max(-1, min(1, yawRate / (2 * RaceTuning.reactionSteerThreshold)))
        lean += (leanTarget - lean) * blend
        self.speed01 += (speed01 - self.speed01) * blend
        let held = Float(clock - stateSince)

        switch state {
        case .celebrating:
            return                          // sticky until the next race
        case .crashed, .boosted:
            if held < RaceTuning.reactionOverrideHold { return }
        default:
            break
        }

        let target: ReactionState =
            loopAhead ? .braced
            : yawRate > RaceTuning.reactionSteerThreshold ? .steerLeft
            : yawRate < -RaceTuning.reactionSteerThreshold ? .steerRight
            : .idle
        if target != state, held >= RaceTuning.reactionMinHold {
            state = target
            stateSince = clock
        }
    }

    /// Discrete race events override immediately (no min-hold wait).
    func fire(_ event: ReactionState) {
        guard state != .celebrating else { return }
        state = event
        stateSince = clock
    }
}
