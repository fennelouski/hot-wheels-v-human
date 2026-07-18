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
