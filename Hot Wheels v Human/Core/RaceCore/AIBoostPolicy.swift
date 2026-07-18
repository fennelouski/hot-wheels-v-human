//
//  AIBoostPolicy.swift
//  Hot Wheels v Human
//
//  The Hot Wheels opponent's brain (PRD §6.4). Same car physics as humans —
//  difficulty is purely boost-decision quality:
//    easy   = random timing
//    medium = boosts on straights
//    hard   = boosts out of curves, never before a loop it could get flung off
//  Pure functions; RaceSession feeds it piece context each tick.
//

import Foundation

nonisolated enum AIBoostPolicy {

    /// Should the AI fire its (already full) boost right now?
    /// - Parameters:
    ///   - previous: piece the car just left (nil at the start gate)
    ///   - current: piece the car is on
    ///   - upcoming: pieces ahead, nearest first
    ///   - dt: seconds since the last evaluation (scales easy's randomness)
    static func shouldBoost(difficulty: AIDifficulty,
                            previous: PieceType?,
                            current: PieceType?,
                            upcoming: [PieceType],
                            dt: Float,
                            rng: inout some RandomNumberGenerator) -> Bool {
        switch difficulty {
        case .easy:
            return Float.random(in: 0..<1, using: &rng) < RaceTuning.aiEasyBoostChancePerSecond * dt
        case .medium:
            return current == .straight
        case .hard:
            // Never boost into (or on) a loop — the impulse flings light cars.
            let ahead = upcoming.prefix(RaceTuning.aiLoopLookaheadPieces)
            guard current != .loop, !ahead.contains(.loop) else { return false }
            // Optimal: punch it coming out of a corner onto open track.
            let curves: Set<PieceType> = [.curve90L, .curve90R, .curveLarge]
            guard let previous, curves.contains(previous),
                  let current, !curves.contains(current) else { return false }
            return true
        }
    }
}

/// Pre-built robotic cars for 1P mode — Kenney karts, factory liveries.
/// Same physics tables as everyone else (PRD: AI never gets stat bonuses).
nonisolated enum AIRoster {
    /// Stable identity for the AI racer on the wire and in results.
    static let playerID = UUID(uuidString: "A1000000-0000-0000-0000-000000000001")!

    static let bots: [CarDesign] = [
        CarDesign(id: UUID(uuidString: "B0700000-0000-0000-0000-000000000001")!,
                  name: "Oobi-Bot", chassis: .balancedFormula, tires: .standard,
                  paint: PaintSpec(colorHex: "#22CC88", finish: .metallic),
                  modelOverride: "kart-oobi"),
        CarDesign(id: UUID(uuidString: "B0700000-0000-0000-0000-000000000002")!,
                  name: "Zapp", chassis: .superlightDrift, tires: .slickRacing,
                  paint: PaintSpec(colorHex: "#CC22CC", finish: .metallic),
                  modelOverride: "kart-oozi"),
        CarDesign(id: UUID(uuidString: "B0700000-0000-0000-0000-000000000003")!,
                  name: "Crusher", chassis: .heavyMuscle, tires: .grippyOffroad,
                  paint: PaintSpec(colorHex: "#CC4422", finish: .metallic),
                  modelOverride: "kart-oodi"),
    ]

    static func bot(for difficulty: AIDifficulty) -> CarDesign {
        switch difficulty {
        case .easy: bots[0]
        case .medium: bots[1]
        case .hard: bots[2]
        }
    }
}
