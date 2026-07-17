//
//  PieceCatalog.swift
//  Hot Wheels v Human
//
//  Geometry metadata for every piece, measured ONCE from the converted
//  USDZ/GLB sources (Blender vertex inspection, 0.2 scale; gates 0.3) and
//  hardcoded here — the models stay pristine Kenney assets.
//
//  Coordinate convention — the "traversal frame" of a piece:
//    • entry connect point at the origin, driving surface at y = 0
//    • travel direction +Z, +Y up; facing +Z, +X is the LEFT side
//    • exitOffset = where the next piece's entry lands
//    • headingChange = yaw delta (radians, + = left turn)
//  Blender Z-up sources land in RealityKit as (x, z, −y); all values
//  below are already in RealityKit metres at conversion scale.
//
//  Kenney pieces are NOT a uniform grid (straight = 0.8 m, small corner
//  radius = 0.4 m, loop ground run = 0.18 m), so footprints are real-valued
//  ground rects, not grid cells. ARCHITECTURE.md updated to match.
//

import simd

/// Axis-aligned ground rectangle in the piece's traversal frame.
/// Nominal (connector tabs excluded) — tabs slide under the next piece.
struct FootprintRect: Sendable, Equatable {
    var minX: Float
    var minZ: Float
    var maxX: Float
    var maxZ: Float
}

/// How the centerline runs through the piece, for spline generation.
enum CenterlineShape: Sendable, Equatable {
    case line(length: Float, rise: Float)
    case arc(radius: Float, leftTurn: Bool)
    /// Vertical circle: short entry/exit stubs, full loop between,
    /// exit shifted `lateralShift` to the left (corkscrew offset).
    case verticalLoop(radius: Float, advance: Float, lateralShift: Float)
}

struct TrackPieceDefinition: Sendable {
    let type: PieceType
    let modelName: String
    /// Second model spawned on top (gate arch over the start/finish straight).
    let overlayModelName: String?
    let overlayOffset: SIMD3<Float>
    /// Model placement inside the traversal frame.
    let modelYaw: Float               // radians about +Y
    let modelOffset: SIMD3<Float>
    let exitOffset: SIMD3<Float>
    let headingChange: Float          // radians about +Y, + = left
    let elevationDelta: Int
    let footprint: FootprintRect
    let shape: CenterlineShape
    /// Half-distance between the two lane centerlines.
    let laneHalfWidth: Float
    let minEntrySpeed: Float?

    init(type: PieceType, modelName: String,
         overlayModelName: String? = nil, overlayOffset: SIMD3<Float> = .zero,
         modelYaw: Float = 0, modelOffset: SIMD3<Float> = .zero,
         exitOffset: SIMD3<Float>, headingChange: Float = 0, elevationDelta: Int = 0,
         footprint: FootprintRect, shape: CenterlineShape,
         laneHalfWidth: Float = RaceTuning.laneOffsetWide, minEntrySpeed: Float? = nil) {
        self.type = type
        self.modelName = modelName
        self.overlayModelName = overlayModelName
        self.overlayOffset = overlayOffset
        self.modelYaw = modelYaw
        self.modelOffset = modelOffset
        self.exitOffset = exitOffset
        self.headingChange = headingChange
        self.elevationDelta = elevationDelta
        self.footprint = footprint
        self.shape = shape
        self.laneHalfWidth = laneHalfWidth
        self.minEntrySpeed = minEntrySpeed
    }
}

enum PieceCatalog {

    static func definition(for type: PieceType) -> TrackPieceDefinition {
        definitions[type]!
    }

    private static let halfPi = Float.pi / 2
    /// Track pieces have their bed surface 0.19 m below the model origin.
    private static let bedLift: SIMD3<Float> = [0, 0.19, 0]

    /// Wide straight: 0.4 m wide, 0.8 m connect-to-connect.
    private static let straightRect = FootprintRect(minX: -0.2, minZ: 0, maxX: 0.2, maxZ: 0.8)

    static let definitions: [PieceType: TrackPieceDefinition] =
        Dictionary(uniqueKeysWithValues: all.map { ($0.type, $0) })

    private static let all: [TrackPieceDefinition] = [
        // Gates = a straight with the gate arch standing over its entry.
        TrackPieceDefinition(
            type: .startGate, modelName: "track-wide-straight",
            overlayModelName: "gate", overlayOffset: [0, 0, 0.15],
            modelOffset: bedLift,
            exitOffset: [0, 0, 0.8],
            footprint: straightRect, shape: .line(length: 0.8, rise: 0)),

        TrackPieceDefinition(
            type: .finishGate, modelName: "track-wide-straight",
            overlayModelName: "gate-finish", overlayOffset: [0, 0, 0.15],
            modelOffset: bedLift,
            exitOffset: [0, 0, 0.8],
            footprint: straightRect, shape: .line(length: 0.8, rise: 0)),

        TrackPieceDefinition(
            type: .straight, modelName: "track-wide-straight",
            modelOffset: bedLift,
            exitOffset: [0, 0, 0.8],
            footprint: straightRect, shape: .line(length: 0.8, rise: 0)),

        // Small corner traversed forward = right turn (measured: entry at
        // origin heading +Z, exit at (−0.4, +0.4) heading −X, radius 0.4).
        TrackPieceDefinition(
            type: .curve90R, modelName: "track-wide-corner-small",
            modelOffset: bedLift,
            exitOffset: [-0.4, 0, 0.4], headingChange: -halfPi,
            footprint: FootprintRect(minX: -0.4, minZ: 0, maxX: 0.2, maxZ: 0.6),
            shape: .arc(radius: 0.4, leftTurn: false)),

        // Same model entered from its far end = left turn: yaw −90° and
        // shift so the model's exit connector sits at the traversal origin.
        TrackPieceDefinition(
            type: .curve90L, modelName: "track-wide-corner-small",
            modelYaw: -halfPi, modelOffset: [0.4, 0.19, 0.4],
            exitOffset: [0.4, 0, 0.4], headingChange: halfPi,
            footprint: FootprintRect(minX: -0.2, minZ: 0, maxX: 0.4, maxZ: 0.6),
            shape: .arc(radius: 0.4, leftTurn: true)),

        // Large sweeping corner, radius 0.8, right turn as modeled.
        TrackPieceDefinition(
            type: .curveLarge, modelName: "track-wide-corner-large",
            modelOffset: bedLift,
            exitOffset: [-0.8, 0, 0.8], headingChange: -halfPi,
            footprint: FootprintRect(minX: -0.8, minZ: 0, maxX: 0.2, maxZ: 1.0),
            shape: .arc(radius: 0.8, leftTurn: false)),

        // Hill pieces: Kenney hill-beginning rises 0.225 m over a 0.79 m run.
        // hillDown reuses the same model traversed in reverse (yaw 180°) —
        // identical ramp geometry, no extra asset. Spline rise is linear for
        // now; Phase 2 refines to the real S-profile if cars stutter.
        TrackPieceDefinition(
            type: .hillUp, modelName: "track-wide-straight-hill-beginning",
            modelOffset: bedLift,
            exitOffset: [0, 0.225, 0.79], elevationDelta: 1,
            footprint: straightRect, shape: .line(length: 0.79, rise: 0.225)),

        TrackPieceDefinition(
            type: .hillDown, modelName: "track-wide-straight-hill-beginning",
            modelYaw: .pi, modelOffset: [0, 0.19 - 0.225, 0.79],
            exitOffset: [0, -0.225, 0.79], elevationDelta: -1,
            footprint: straightRect, shape: .line(length: 0.79, rise: -0.225)),

        TrackPieceDefinition(
            type: .bump, modelName: "track-wide-straight-bump-up",
            modelOffset: bedLift,
            exitOffset: [0, 0, 0.8],
            footprint: straightRect, shape: .line(length: 0.8, rise: 0)),

        // Narrow loop: ground run only 0.18 m, exit shifted 0.2 m left,
        // vertical circle radius 0.4. Model's native travel is −Z → yaw 180°.
        TrackPieceDefinition(
            type: .loop, modelName: "track-narrow-looping",
            modelYaw: .pi, modelOffset: [0, 0.19, 0.09],
            exitOffset: [0.2, 0, 0.18],
            footprint: FootprintRect(minX: -0.11, minZ: 0, maxX: 0.3, maxZ: 0.18),
            shape: .verticalLoop(radius: 0.4, advance: 0.18, lateralShift: 0.2),
            laneHalfWidth: RaceTuning.laneOffsetNarrow,
            minEntrySpeed: RaceTuning.loopMinEntrySpeed),

        // Corner ramp doubles as the v1 jump; real gap-jump geometry is a
        // Phase 2 concern (PRD lists OGA jump models as the alternative).
        TrackPieceDefinition(
            type: .rampJump, modelName: "track-wide-corner-small-ramp",
            modelOffset: bedLift,
            exitOffset: [-0.4, 0, 0.4], headingChange: -halfPi,
            footprint: FootprintRect(minX: -0.4, minZ: 0, maxX: 0.2, maxZ: 0.6),
            shape: .arc(radius: 0.4, leftTurn: false),
            minEntrySpeed: RaceTuning.rampMinEntrySpeed),
    ]
}
