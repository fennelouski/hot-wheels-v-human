//
//  AIBoostPolicyTests.swift
//  Hot Wheels v HumanTests
//
//  PRD §6.4: easy = random, medium = straights, hard = out of curves and
//  never before a loop. Deterministic RNG so easy is testable.
//

import Testing
@testable import Hot_Wheels_v_Human

/// Fixed-sequence RNG: emits the values you hand it.
private struct FixedRNG: RandomNumberGenerator {
    var values: [UInt64]
    mutating func next() -> UInt64 { values.isEmpty ? 0 : values.removeFirst() }
}

struct AIBoostPolicyTests {

    private func decide(_ difficulty: AIDifficulty,
                        previous: PieceType? = nil,
                        current: PieceType?,
                        upcoming: [PieceType] = [],
                        rng: inout some RandomNumberGenerator) -> Bool {
        AIBoostPolicy.shouldBoost(difficulty: difficulty, previous: previous,
                                  current: current, upcoming: upcoming,
                                  dt: 0.1, rng: &rng)
    }

    @Test func easyIsRandomTiming() {
        var always = FixedRNG(values: [0])           // random() → 0.0 < chance
        #expect(decide(.easy, current: .loop, rng: &always))

        var never = FixedRNG(values: [.max, .max, .max])   // random() → ~1.0
        #expect(!decide(.easy, current: .straight, rng: &never))
    }

    @Test func mediumBoostsOnlyOnStraights() {
        var rng = SystemRandomNumberGenerator()
        #expect(decide(.medium, current: .straight, rng: &rng))
        #expect(!decide(.medium, current: .curve90L, rng: &rng))
        #expect(!decide(.medium, current: .loop, rng: &rng))
        #expect(!decide(.medium, current: nil, rng: &rng))
    }

    @Test func hardBoostsOutOfCurves() {
        var rng = SystemRandomNumberGenerator()
        #expect(decide(.hard, previous: .curve90R, current: .straight, rng: &rng))
        #expect(decide(.hard, previous: .curveLarge, current: .hillUp, rng: &rng))
        // Not exiting a curve → hold the boost.
        #expect(!decide(.hard, previous: .straight, current: .straight, rng: &rng))
        // Still inside the curve → hold.
        #expect(!decide(.hard, previous: .curve90L, current: .curve90R, rng: &rng))
    }

    // MARK: Rubber band (the kid's win rate)

    @Test func paceChasesWhenBehindAndEasesWhenAhead() {
        // Way back → floor it. Way ahead → back off. Never outside the clamp.
        #expect(AIBoostPolicy.pace(gap: 0.5, botMayWin: false)
                == RaceTuning.aiPaceRange.upperBound)
        #expect(AIBoostPolicy.pace(gap: -0.5, botMayWin: false)
                == RaceTuning.aiPaceRange.lowerBound)
    }

    @Test func paceHoldsTheBotJustBehindOnRacesItMustLose() {
        // Sitting exactly on its target gap → cruise, no correction.
        #expect(AIBoostPolicy.pace(gap: RaceTuning.aiTrailMargin, botMayWin: false) == 1)
        // Level with the kid is too far forward → ease off.
        #expect(AIBoostPolicy.pace(gap: 0, botMayWin: false) < 1)
        // Slipping further back than the target → push.
        #expect(AIBoostPolicy.pace(gap: RaceTuning.aiTrailMargin + 0.02,
                                   botMayWin: false) > 1)
    }

    @Test func paceLetsTheBotLeadOnTheRacesItWon() {
        // Same gap, opposite verdict: the winning bot pushes where the
        // losing one would coast. That flip IS the win rate.
        let gap: Float = 0
        #expect(AIBoostPolicy.pace(gap: gap, botMayWin: true) > 1)
        #expect(AIBoostPolicy.pace(gap: gap, botMayWin: false) < 1)
        // Already ahead by its lead margin → cruise there.
        #expect(AIBoostPolicy.pace(gap: -RaceTuning.aiLeadMargin, botMayWin: true) == 1)
    }

    @Test func winChanceMatchesWhatTheKidAskedFor() {
        #expect(RaceTuning.aiWinChance[.easy] == 0.01)     // kid wins 99%
        #expect(RaceTuning.aiWinChance[.medium] == 0.10)   // kid wins 90%
        #expect(RaceTuning.aiWinChance[.hard] == 0.10)
    }

    @Test func hardNeverBoostsIntoALoop() {
        var rng = SystemRandomNumberGenerator()
        #expect(!decide(.hard, previous: .curve90R, current: .straight,
                        upcoming: [.loop], rng: &rng))
        #expect(!decide(.hard, previous: .curve90R, current: .straight,
                        upcoming: [.straight, .loop], rng: &rng))
        #expect(!decide(.hard, previous: .curve90R, current: .loop, rng: &rng))
        // Loop far enough away (beyond lookahead) is fine.
        #expect(decide(.hard, previous: .curve90R, current: .straight,
                       upcoming: [.straight, .straight, .loop], rng: &rng))
    }

    @Test func rosterCoversEveryDifficulty() {
        for difficulty in [AIDifficulty.easy, .medium, .hard] {
            let bot = AIRoster.bot(for: difficulty)
            #expect(bot.modelOverride?.hasPrefix("kart-") == true)
        }
    }
}
