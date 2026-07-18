//
//  ReactionDirectorTests.swift
//  Hot Wheels v HumanTests
//
//  The no-flicker guarantee (min hold), event overrides, and sticky win.
//

import Testing
@testable import Hot_Wheels_v_Human

@MainActor
struct ReactionDirectorTests {

    @Test func steeringNeedsMinHoldSoItNeverFlickers() {
        let director = ReactionDirector()
        // A hard turn immediately after start: still inside min hold.
        director.update(dt: 0.1, yawRate: 5, loopAhead: false)
        #expect(director.state == .idle)
        // After the hold elapses, the lean lands.
        director.update(dt: Double(RaceTuning.reactionMinHold), yawRate: 5, loopAhead: false)
        #expect(director.state == .steerLeft)
    }

    @Test func braceBeatsSteering() {
        let director = ReactionDirector()
        director.update(dt: 1, yawRate: 5, loopAhead: true)
        #expect(director.state == .braced)
    }

    @Test func crashOverridesImmediatelyThenExpires() {
        let director = ReactionDirector()
        director.fire(.crashed)
        #expect(director.state == .crashed)
        // Still held during the override window.
        director.update(dt: 0.5, yawRate: 0, loopAhead: false)
        #expect(director.state == .crashed)
        // Expired → back to continuous states.
        director.update(dt: Double(RaceTuning.reactionOverrideHold), yawRate: 0, loopAhead: false)
        #expect(director.state == .idle)
    }

    @Test func celebrationIsSticky() {
        let director = ReactionDirector()
        director.fire(.celebrating)
        director.update(dt: 10, yawRate: 5, loopAhead: true)
        #expect(director.state == .celebrating)
        director.fire(.crashed)   // nothing tops winning
        #expect(director.state == .celebrating)
    }

    @Test @MainActor func everyStateHasAFace() {
        // DriverFaceView's switch is exhaustive (compile-checked); this
        // guards that every state constructs a renderable face view.
        for state in ReactionState.allCases {
            _ = DriverFaceView(state: state).body
        }
    }
}
