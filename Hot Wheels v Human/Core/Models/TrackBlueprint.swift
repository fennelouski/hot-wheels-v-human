//
//  TrackBlueprint.swift
//  Hot Wheels v Human
//
//  The wire format for a track: an ordered list of piece types.
//  No rotations, no positions — TrackLayoutSolver derives all of that,
//  so invalid geometry data cannot exist (PRD §4).
//

import Foundation

nonisolated struct SegmentSpec: Codable, Equatable, Sendable {
    var index: Int
    var type: PieceType
    /// Where a `portalOut` piece lands (world ground coords) — the one
    /// place a position rides the wire, because a portal exit is the one
    /// piece that DOESN'T attach to the previous piece. Additive optional;
    /// nil on a portalOut means "continue the chain" (plain straight).
    var portalX: Float?
    var portalZ: Float?

    init(index: Int, type: PieceType, portalX: Float? = nil, portalZ: Float? = nil) {
        self.index = index
        self.type = type
        self.portalX = portalX
        self.portalZ = portalZ
    }
}

/// One hand-placed decoration: any prop model from any world, dropped at
/// (x, z) on the ground. Cosmetic only — no collision, no validation.
nonisolated struct SceneryItem: Codable, Equatable, Hashable, Sendable {
    var model: String
    var x: Float
    var z: Float
    var yaw: Float
}

nonisolated struct TrackBlueprint: Codable, Equatable, Sendable {
    var trackId: UUID
    var lanes: Int
    var segments: [SegmentSpec]
    /// Picked world (ArenaEnvironment theme name, e.g. "city"). Additive
    /// optional — old peers decode; nil = auto-pick from trackId hash.
    var worldTheme: String?
    /// Hand-placed decorations. Additive optional, same deal as worldTheme.
    var scenery: [SceneryItem]?
    /// Empty world: keep the theme's sky/ground/terrain, skip all the
    /// auto-placed stuff — the kid designs everything. Additive optional.
    var worldEmpty: Bool?

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
