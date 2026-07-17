//
//  TrackBlueprint.swift
//  Hot Wheels v Human
//
//  The wire format for a track: an ordered list of piece types.
//  No rotations, no positions — TrackLayoutSolver derives all of that,
//  so invalid geometry data cannot exist (PRD §4).
//

import Foundation

struct SegmentSpec: Codable, Equatable, Sendable {
    var index: Int
    var type: PieceType
}

struct TrackBlueprint: Codable, Equatable, Sendable {
    var trackId: UUID
    var lanes: Int
    var segments: [SegmentSpec]

    /// Phase 1 hardcoded demo: straight–loop–curve–finish (BUILD-ORDER P1 DoD).
    static let demo = TrackBlueprint(
        trackId: UUID(uuidString: "DE300000-0000-0000-0000-000000000001")!,
        lanes: 2,
        segments: [
            SegmentSpec(index: 0, type: .startGate),
            SegmentSpec(index: 1, type: .straight),
            SegmentSpec(index: 2, type: .loop),
            SegmentSpec(index: 3, type: .curve90R),
            SegmentSpec(index: 4, type: .finishGate),
        ]
    )
}
