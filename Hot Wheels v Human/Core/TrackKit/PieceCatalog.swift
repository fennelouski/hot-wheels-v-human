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
    /// Symmetric hump — entry AND exit at y = 0, cresting `height` at the
    /// middle, so a crest piece stays swappable with `.straight`. The
    /// profile is a raised cosine, which is what the bump-up mesh actually
    /// is (measured off the OBJ: bed top 0.06 → 0.16 → 0.06 across the
    /// 0.8 m run). Convex crest = the launch: rail mode goes ballistic
    /// where the bed falls away faster than gravity.
    case crest(length: Float, height: Float)
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

        // Hill pieces: Kenney hill-COMPLETE is the flat→flat rise, 0.2 m
        // over the standard 0.8 m run with a level exit connector (measured
        // in Blender: surface −0.14 → +0.06). hill-beginning/-end are
        // slope-transition pieces with ANGLED connectors the yaw-only
        // solver can't mate — using -beginning here was why hills left a
        // 4 cm step at every seam. hillDown reuses the model traversed in
        // reverse (yaw 180°). Spline rise is linear; refine to the real
        // S-profile if cars stutter.
        TrackPieceDefinition(
            type: .hillUp, modelName: "track-wide-straight-hill-complete",
            modelOffset: bedLift,
            exitOffset: [0, RaceTuning.elevationLevelHeight, 0.8], elevationDelta: 1,
            footprint: straightRect,
            shape: .line(length: 0.8, rise: RaceTuning.elevationLevelHeight)),

        TrackPieceDefinition(
            type: .hillDown, modelName: "track-wide-straight-hill-complete",
            modelYaw: .pi, modelOffset: [0, 0.19 - RaceTuning.elevationLevelHeight, 0.8],
            exitOffset: [0, -RaceTuning.elevationLevelHeight, 0.8], elevationDelta: -1,
            footprint: straightRect,
            shape: .line(length: 0.8, rise: -RaceTuning.elevationLevelHeight)),

        // Same hump the ramp launches off, and now the same centreline. It
        // kept a flat `.line` while the mesh rose 0.10 m, so rail-mode cars
        // drove THROUGH the hump on every preset that has one. There is no
        // "ride it without air" middle ground: the bed out-falls gravity
        // above roughly a 2 cm crest at race speed, so any spline that sits
        // on this mesh launches. A bump that bumps is the intent anyway.
        // Now kinematically identical to .rampJump apart from its entry-speed
        // gate — kept as its own type because 7 locked presets and every
        // saved blueprint name it.
        TrackPieceDefinition(
            type: .bump, modelName: "track-wide-straight-bump-up",
            modelOffset: bedLift,
            exitOffset: [0, 0, 0.8],
            footprint: straightRect,
            shape: .crest(length: 0.8, height: RaceTuning.rampCrestHeight)),

        // Narrow loop: ground run only 0.18 m, exit shifted 0.2 m left,
        // vertical circle radius 0.4. Model's native travel is −Z → yaw 180°.
        TrackPieceDefinition(
            type: .loop, modelName: "track-narrow-looping",
            modelYaw: 0, modelOffset: [0.2, 0.19, 0.09],
            exitOffset: [0.2, 0, 0.18],
            footprint: FootprintRect(minX: -0.11, minZ: 0, maxX: 0.3, maxZ: 0.18),
            shape: .verticalLoop(radius: 0.4, advance: 0.18, lateralShift: 0.2),
            laneHalfWidth: RaceTuning.laneOffsetNarrow,
            minEntrySpeed: RaceTuning.loopMinEntrySpeed),

        // Straight-line jump. Was a corner-ramp — so the only "jump" was a
        // banked turn; a jump should launch you STRAIGHT. Kinematically a
        // plain straight (0.8 forward, no turn, level exit) so it drops into
        // any straightaway with no seam and no preset re-layout.
        //
        // The centreline CRESTS (see .crest) instead of running flat. That
        // is what makes it a jump in the mode we ship: rail mode launches a
        // car only where the bed falls away faster than gravity, and a flat
        // spline never does — the piece was a straight with a hump drawn on
        // it, and the car drove through the hump. The crest matches the
        // mesh, so the car now rides the model up and gets thrown off the
        // convex face. Chaos mode is unaffected: it keeps the exact mesh
        // collision (TrackSpawner) and was always launched by the real lip.
        //
        // bump-up is the launch lip: symmetric, so it exits level and never
        // opens a gap in the track. A taller dedicated ramp (OGA jump
        // geometry) is the upgrade if kids want bigger air.
        TrackPieceDefinition(
            type: .rampJump, modelName: "track-wide-straight-bump-up",
            modelOffset: bedLift,
            exitOffset: [0, 0, 0.8],
            footprint: straightRect,
            shape: .crest(length: 0.8, height: RaceTuning.rampCrestHeight),
            minEntrySpeed: RaceTuning.rampMinEntrySpeed),
    ]
}
