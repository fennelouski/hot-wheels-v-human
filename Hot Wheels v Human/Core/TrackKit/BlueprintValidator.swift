//
//  BlueprintValidator.swift
//  Hot Wheels v Human
//
//  Rules a track must pass before it gets built. Reasons are kid-readable —
//  the TrackBuilder UI (Phase 5) makes invalid moves impossible, so these
//  mostly guard the wire (PRD §6.5 blueprintRejected).
//

import Foundation
import simd

nonisolated struct ValidationResult: Equatable, Sendable {
    var isValid: Bool { reasons.isEmpty }
    var reasons: [String]
}

// Pure value-in/value-out, and RandomTrackGenerator is `nonisolated` — without
// this it inherits MainActor from SWIFT_DEFAULT_ACTOR_ISOLATION and the
// generator can't call it. Same reason RaceTuning is nonisolated.
nonisolated enum BlueprintValidator {

    /// `requireEnding: false` = mid-build structural check (TrackBuilder):
    /// everything except "has a finish or closes the circuit".
    static func validate(_ blueprint: TrackBlueprint, requireEnding: Bool = true) -> ValidationResult {
        var reasons: [String] = []

        guard !blueprint.segments.isEmpty else {
            return ValidationResult(reasons: ["The track is empty — add some pieces!"])
        }
        if blueprint.segments.count > RaceTuning.maxTrackPieces {
            reasons.append("Whoa, that's too many pieces! The max is \(RaceTuning.maxTrackPieces).")
        }
        if blueprint.segments.enumerated().contains(where: { $0.offset != $0.element.index }) {
            reasons.append("The track pieces are out of order.")
        }

        let starts = blueprint.segments.filter { $0.type == .startGate }
        if starts.count != 1 {
            reasons.append(starts.isEmpty ? "Every track needs a start gate."
                                          : "Only one start gate allowed.")
        } else if blueprint.segments.first?.type != .startGate {
            reasons.append("The start gate has to be the first piece.")
        }

        let finishes = blueprint.segments.filter { $0.type == .finishGate }
        if finishes.count > 1 {
            reasons.append("Only one finish gate allowed.")
        }

        let layout = TrackLayoutSolver.solve(blueprint)

        // A race ends at a finish gate (sprint) or back at the start (circuit).
        let endsAtFinish = blueprint.segments.last?.type == .finishGate
        if finishes.count == 1 && !endsAtFinish {
            reasons.append("The finish gate has to be the last piece.")
        }
        if requireEnding && finishes.isEmpty && !layout.isClosedCircuit {
            reasons.append("The track needs a finish gate, or to loop back to the start.")
        }

        // No "can't go underground" rule any more: the solver normalises
        // levels so the track's lowest point sits ON the ground, which makes
        // digging impossible by construction — and unblocks the downhill
        // start, which this rule used to reject as a track beginning below
        // the world (TrackLayoutSolver.solve).

        // Footprint overlap at the same elevation level. Rects are shrunk a
        // hair so touching edges (which is the whole point) don't count.
        //
        // The loop is skipped: it's an OVERPASS. Both its connect points sit
        // at the same spot (it corkscrews sideways without advancing), so the
        // straights it joins always sit under its ground plate, and its arc
        // bulges 0.4 m fore and aft over them. Real pieces still get checked
        // against each other — only the loop's own rect is exempt.
        let rects = layout.pieces
            .filter { $0.definition.type != .loop }
            .map { (level: $0.entryLevel, rect: $0.worldFootprint, number: $0.index + 1) }
        let epsilon: Float = 0.02
        outer: for i in 0..<rects.count {
            for j in (i + 1)..<rects.count where rects[i].level == rects[j].level {
                let a = rects[i].rect, b = rects[j].rect
                if a.minX + epsilon < b.maxX && b.minX + epsilon < a.maxX
                    && a.minZ + epsilon < b.maxZ && b.minZ + epsilon < a.maxZ {
                    reasons.append("Pieces \(rects[i].number) and \(rects[j].number) are on top of each other.")
                    break outer
                }
            }
        }

        return ValidationResult(reasons: reasons)
    }
}
