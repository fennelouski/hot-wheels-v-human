//
//  RandomTrackGenerator.swift
//  Hot Wheels v Human
//
//  The "shuffle" button: a random track that always validates.
//  Greedy append with validation at every step, whole-track retries on
//  dead ends. Guarantees ≥1 loop for tracks of 8+ pieces.
//

import Foundation

nonisolated enum RandomTrackGenerator {

    /// Pieces the generator may sprinkle between the gates.
    private static let middlePieces: [PieceType] = [
        .straight, .straight, .curve90L, .curve90R,   // straights/curves weighted up
        .straight, .curve90L, .curve90R, .curveLarge, .loop, .bump,
    ]

    static func generate(pieceCount: Int = 10) -> TrackBlueprint {
        let target = max(3, min(pieceCount, RaceTuning.maxTrackPieces))
        for _ in 0..<64 {
            if let track = attempt(target: target) {
                return track
            }
        }
        return .demo   // statistically unreachable; never strand the kid
    }

    private static func attempt(target: Int) -> TrackBlueprint? {
        var types: [PieceType] = [.startGate]
        let wantLoop = target >= 8
        var hasLoop = false

        while types.count < target - 1 {
            // Force the loop in while there's room, otherwise roll the dice.
            let mustLoop = wantLoop && !hasLoop && types.count >= target - 3
            let candidates = (mustLoop ? [.loop] : middlePieces).shuffled()
            guard let pick = candidates.first(where: { validates(types + [$0]) }) else {
                return nil   // dead end — caller retries fresh
            }
            types.append(pick)
            hasLoop = hasLoop || pick == .loop
        }
        if wantLoop && !hasLoop { return nil }

        let finished = blueprint(types + [.finishGate])
        guard BlueprintValidator.validate(finished).isValid else { return nil }
        return finished
    }

    /// Mid-build prefixes have no finish yet — only structural rules apply.
    private static func validates(_ types: [PieceType]) -> Bool {
        BlueprintValidator.validate(blueprint(types), requireEnding: false).isValid
    }

    private static func blueprint(_ types: [PieceType]) -> TrackBlueprint {
        TrackBlueprint(trackId: UUID(), lanes: 2,
                       segments: types.enumerated().map { SegmentSpec(index: $0.offset, type: $0.element) })
    }
}
