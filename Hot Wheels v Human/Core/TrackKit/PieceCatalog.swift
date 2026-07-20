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
//  radius = 0.4 m, and the loop advances 0 m — it corkscrews sideways), so
//  footprints are real-valued ground rects, not grid cells. Some pieces
//  reach outside their footprint: the loop's arc passes OVER its neighbours.
//  ARCHITECTURE.md updated to match.
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

/// Where a hill piece sits inside a RUN of consecutive hills of the same
/// direction. Real Hot Wheels track doesn't climb in steps: one piece bends
/// into the slope, plain straights ride down the middle of it, and one
/// piece flattens out at the far end. Kenney ships exactly those parts —
/// hill-beginning and hill-end have ANGLED connectors for it — and a
/// one-piece hill-complete that is both transitions at once.
///
/// The role is a property of the piece's NEIGHBOURS, so it can't live in
/// the catalog dictionary; `TrackLayoutSolver` reads the run off the
/// blueprint and asks for `definition(for:role:)`.
enum HillRole: Sendable, Equatable {
    /// A hill on its own: S-curve, level at both ends, one level gained.
    case solo
    /// First of a run — level in, sloped out.
    case entry
    /// Straight track pitched down the run's steady slope.
    case middle
    /// Last of a run — sloped in, level out.
    case exit
}

/// How the centerline runs through the piece, for spline generation.
enum CenterlineShape: Sendable, Equatable {
    case line(length: Float, rise: Float)
    case arc(radius: Float, leftTurn: Bool)
    /// Bed profile measured off a Kenney hill mesh and normalised to
    /// (t, u) ∈ [0,1]², t along the run and u up the rise, linearly
    /// interpolated between samples. `rise` carries the sign, so the same
    /// table drives a climb and a descent.
    ///
    /// Sampled rather than fitted: the two transition beds are asymmetric
    /// curves with no tidy closed form, and the nearest cheap fit (t³) sat
    /// 8 mm off the mesh at mid-piece — the same class of defect this
    /// replaces, just smaller. A straight chord, which is what hills used
    /// to get, is 70 mm off.
    case profiled(length: Float, rise: Float, samples: [SIMD2<Float>])
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
    /// Radians about +X, applied AFTER the yaw. Only the pitched straights
    /// in the middle of a hill run use it — a right-handed rotation about
    /// +X carries +Z toward −Y, so a climb wants a NEGATIVE pitch.
    let modelPitch: Float
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
         modelYaw: Float = 0, modelPitch: Float = 0, modelOffset: SIMD3<Float> = .zero,
         exitOffset: SIMD3<Float>, headingChange: Float = 0, elevationDelta: Int = 0,
         footprint: FootprintRect, shape: CenterlineShape,
         laneHalfWidth: Float = RaceTuning.laneOffsetWide, minEntrySpeed: Float? = nil) {
        self.type = type
        self.modelName = modelName
        self.overlayModelName = overlayModelName
        self.overlayOffset = overlayOffset
        self.modelYaw = modelYaw
        self.modelPitch = modelPitch
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

    // MARK: Hill bed geometry (measured)

    /// The HILL meshes carry a 0.01 m recessed tongue at each connector, so
    /// their drivable bed sits 0.18 m below the origin, not the flat
    /// pieces' 0.19 m — the tongue is the part that slides under the
    /// neighbour, and it is not what you drive on. Lifting hills by the
    /// flat 0.19 stood every hill 1 cm proud of the straights it joined
    /// and put the spline 1 cm under its own bed at the entry seam.
    /// (Blender: hill-complete's bed runs −0.18 → +0.02, midpoint −0.08.)
    private static let hillBedLift: Float = 0.18
    /// hill-end's bed starts 0.1755 m below the origin — it is the one
    /// transition whose entry is an ANGLED connector, so it doesn't share
    /// the others' flat-tongue depth.
    private static let hillEndBedLift: Float = 0.1755

    /// What each hill mesh's bed ACTUALLY rises, measured. Only
    /// hill-complete lands on a round elevation level; the two transitions
    /// miss it by a few millimetres, and the layout uses the round number
    /// so that heights stay whole support legs.
    ///
    /// ponytail: the models are placed to be exact at the piece's ENTRY —
    /// where the spline starts and where the car arrives — which leaves the
    /// difference (≤ 6 mm) as a step at the far seam. Scaling each mesh's Y
    /// by level/meshRise would zero it out; not worth a transform and a
    /// re-derived bed offset for a third of a wheel's height.
    private static let completeMeshRise: Float = 0.2000
    private static let beginningMeshRise: Float = 0.2056
    private static let endMeshRise: Float = 0.1955

    private static let level = RaceTuning.elevationLevelHeight

    /// Normalised bed profiles, (t, u) with t along the run and u up the
    /// rise. Sampled off the Kenney meshes in Blender at 0.2 scale, from
    /// the up-facing bed faces in the drivable channel, then linearly
    /// resampled onto a t = 0, 0.1, … 1.0 grid — finer than the 0.1 m
    /// waypoint spacing that reads them, so interpolation never invents a
    /// bump the mesh doesn't have.

    /// hill-complete: a symmetric S, level at BOTH ends. Fits smootherstep
    /// (6t⁵ − 15t⁴ + 10t³) to within 2.5 mm, so it's generated rather than
    /// tabulated — the two transitions below have no such luck.
    private static let completeProfile: [SIMD2<Float>] = (0...10).map {
        let t = Float($0) / 10
        return SIMD2(t, t * t * t * (t * (t * 6 - 15) + 10))
    }

    /// hill-beginning: level in, ~37° out. Holds flat a long time, then
    /// bends hard — nothing like a chord, which is why this piece could
    /// never be swapped in under the old straight-line spline.
    private static let beginningProfile: [SIMD2<Float>] = [
        [0.0, 0.0000], [0.1, 0.0056], [0.2, 0.0191], [0.3, 0.0436],
        [0.4, 0.0819], [0.5, 0.1376], [0.6, 0.2157], [0.7, 0.3236],
        [0.8, 0.4761], [0.9, 0.6953], [1.0, 1.0000],
    ]

    /// hill-end: ~34° in, level out. NOT the mirror of hill-beginning —
    /// its tail flattens much more gently (checked; the mirror is off by
    /// 7% of the rise at mid-piece), so it gets its own table.
    private static let endProfile: [SIMD2<Float>] = [
        [0.0, 0.0000], [0.1, 0.2697], [0.2, 0.4508], [0.3, 0.5862],
        [0.4, 0.6940], [0.5, 0.7819], [0.6, 0.8534], [0.7, 0.9107],
        [0.8, 0.9548], [0.9, 0.9842], [1.0, 1.0000],
    ]

    /// The same bed driven the other way: reverse the samples and flip
    /// them, so a descent reads its transition off the ascent's table.
    private static func reversed(_ profile: [SIMD2<Float>]) -> [SIMD2<Float>] {
        profile.reversed().map { SIMD2(1 - $0.x, 1 - $0.y) }
    }

    // MARK: Role-aware lookup

    /// A hill's geometry depends on its neighbours (see `HillRole`), so the
    /// solver resolves the run first and asks for the piece it actually
    /// needs. Everything else ignores the role and gets its one definition.
    static func definition(for type: PieceType, role: HillRole) -> TrackPieceDefinition {
        switch type {
        case .hillUp:   hill(climbing: true, role: role)
        case .hillDown: hill(climbing: false, role: role)
        default:        definition(for: type)
        }
    }

    /// Both hill directions off one builder: a descent is the same meshes
    /// driven backwards, so every sign flips together and the two can't
    /// drift apart the way two hand-written entries did.
    private static func hill(climbing up: Bool, role: HillRole) -> TrackPieceDefinition {
        let type: PieceType = up ? .hillUp : .hillDown
        let sign: Float = up ? 1 : -1
        // A descent runs the meshes in reverse: yaw 180° and shift the
        // model so its HIGH connector lands on the traversal entry.
        let yaw: Float = up ? 0 : .pi
        /// Places a hill mesh so its bed meets the traversal entry at y = 0.
        /// Climbing, that's the mesh's low end and the lift is all it takes;
        /// descending, the entry is the mesh's high end, one true rise up.
        func offset(_ lift: Float, _ meshRise: Float) -> SIMD3<Float> {
            up ? [0, lift, 0] : [0, lift - meshRise, 0.8]
        }

        switch role {
        case .solo:
            // hill-complete: both transitions in one piece, level at each
            // end, one level gained. What every hill used to be — only the
            // spline was a straight chord across an S-curved bed, so cars
            // floated 26 mm over the first third and sank 29 mm through
            // the last third.
            return TrackPieceDefinition(
                type: type, modelName: "track-wide-straight-hill-complete",
                modelYaw: yaw, modelOffset: offset(hillBedLift, completeMeshRise),
                exitOffset: [0, sign * level, 0.8], elevationDelta: up ? 1 : -1,
                footprint: straightRect,
                shape: .profiled(length: 0.8, rise: sign * level,
                                 samples: completeProfile))

        case .entry:
            // Level in, sloped out. Climbing that's hill-beginning;
            // descending it's hill-end run backwards.
            return TrackPieceDefinition(
                type: type,
                modelName: up ? "track-wide-straight-hill-beginning"
                              : "track-wide-straight-hill-end",
                modelYaw: yaw,
                modelOffset: up ? offset(hillBedLift, beginningMeshRise)
                               : offset(hillEndBedLift, endMeshRise),
                exitOffset: [0, sign * level, 0.8], elevationDelta: up ? 1 : -1,
                footprint: straightRect,
                shape: .profiled(length: 0.8, rise: sign * level,
                                 samples: up ? beginningProfile
                                             : reversed(endProfile)))

        case .middle:
            // A plain straight, pitched. sin 30° = ½ ⇒ two levels gained
            // over the 0.8 m of track, advancing 0.8·cos 30°. Rotating a
            // flat piece about its own origin swings the bed off the
            // entry, so the offset walks it back: the bed sits `bedDepth`
            // under the origin and the rotation carries that offset into
            // both axes.
            let slope = RaceTuning.hillRunSlope
            let bedDepth = bedLift.y     // a FLAT straight's bed, not a hill's
            let advance = 0.8 * cos(slope)
            return TrackPieceDefinition(
                type: type, modelName: "track-wide-straight",
                modelPitch: -sign * slope,
                modelOffset: [0, bedDepth * cos(slope), -sign * bedDepth * sin(slope)],
                exitOffset: [0, sign * 2 * level, advance],
                elevationDelta: up ? 2 : -2,
                footprint: FootprintRect(minX: -0.2, minZ: 0, maxX: 0.2, maxZ: advance),
                shape: .line(length: advance, rise: sign * 2 * level))

        case .exit:
            // Sloped in, level out — the mirror of `.entry`.
            return TrackPieceDefinition(
                type: type,
                modelName: up ? "track-wide-straight-hill-end"
                              : "track-wide-straight-hill-beginning",
                modelYaw: yaw,
                modelOffset: up ? offset(hillEndBedLift, endMeshRise)
                               : offset(hillBedLift, beginningMeshRise),
                exitOffset: [0, sign * level, 0.8], elevationDelta: up ? 1 : -1,
                footprint: straightRect,
                shape: .profiled(length: 0.8, rise: sign * level,
                                 samples: up ? endProfile
                                             : reversed(beginningProfile)))
        }
    }

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

        // Hills are role-dependent — see `hill(climbing:role:)`. The
        // catalog dictionary carries their SOLO form, which is what a lone
        // hill is and what everything outside the solver (builder UI,
        // wire, tests) means by "a hill".
        hill(climbing: true, role: .solo),
        hill(climbing: false, role: .solo),

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

        // Narrow loop — a CORKSCREW, not a straight with a circle on it.
        // Measured off the GLB (POSITION accessor bounds + connector-tab
        // vertices, ×0.2): both connect points sit at z = 0, one at x = 0
        // and one at x = −0.2. It climbs, crosses over, and sets you down
        // one bed width to the RIGHT having advanced nothing — the toy.
        //
        // It used to claim `advance: 0.18` (that's the ground PLATE's depth,
        // not a run) shifting LEFT, with modelOffset.x = 0.2 — which put the
        // mesh's exit tab on the layout's entry, so cars drove the loop
        // backwards through its own lead-in ramps, corkscrewing against the
        // drawn bed with the spline 0.09 m off the mesh at both seams.
        //
        // Footprint is the ground plate: 0.4 m across, i.e. the entry lane
        // plus the exit lane. The arc bulges ±0.4 m in z over the straights
        // either side, so BlueprintValidator skips this rect — overpass.
        TrackPieceDefinition(
            type: .loop, modelName: "track-narrow-looping",
            modelYaw: 0, modelOffset: bedLift,
            exitOffset: [-0.2, 0, 0],
            footprint: FootprintRect(minX: -0.3, minZ: -0.09, maxX: 0.1, maxZ: 0.09),
            shape: .verticalLoop(radius: 0.4, advance: 0, lateralShift: -0.2),
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
