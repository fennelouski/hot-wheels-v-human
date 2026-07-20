//
//  TrackLayoutSolver.swift
//  Hot Wheels v Human
//
//  Blueprint → world transforms + lane splines. Pure math, no RealityKit.
//  Walks the segment list accumulating (position, yaw); orientation is
//  always derived, never stored (PRD §4).
//

import Foundation
import simd

nonisolated struct PlacedPiece: Sendable {
    let index: Int
    let definition: TrackPieceDefinition
    /// Entry connect point, world.
    let entryPosition: SIMD3<Float>
    /// Traversal-frame yaw at entry, world radians about +Y.
    let entryYaw: Float
    /// Elevation level at entry (integer, level 0 = ground).
    let entryLevel: Int

    /// Where the model itself goes.
    var modelPosition: SIMD3<Float> { entryPosition + rotated(definition.modelOffset, by: entryYaw) }
    var modelYaw: Float { entryYaw + definition.modelYaw }
    var overlayPosition: SIMD3<Float> { entryPosition + rotated(definition.overlayOffset, by: entryYaw) }

    /// Piece footprint as a world axis-aligned rect (yaws are 90° multiples).
    var worldFootprint: FootprintRect {
        let f = definition.footprint
        let corners = [
            SIMD3<Float>(f.minX, 0, f.minZ), SIMD3<Float>(f.maxX, 0, f.minZ),
            SIMD3<Float>(f.minX, 0, f.maxZ), SIMD3<Float>(f.maxX, 0, f.maxZ),
        ].map { entryPosition + rotated($0, by: entryYaw) }
        return FootprintRect(
            minX: corners.map(\.x).min()!, minZ: corners.map(\.z).min()!,
            maxX: corners.map(\.x).max()!, maxZ: corners.map(\.z).max()!)
    }
}

nonisolated struct LaneSplines: Sendable {
    var center: [SIMD3<Float>]
    var left: [SIMD3<Float>]
    var right: [SIMD3<Float>]
    /// Waypoint index where each piece begins — checkpoint/respawn anchors.
    var pieceStartIndices: [Int] = []
    /// Unit "left" vector per waypoint (world). With the tangent this gives
    /// the full track frame — the rail follower derives its up vector from
    /// `cross(tangent, lateral)` so cars roll correctly through the loop.
    var laterals: [SIMD3<Float>] = []
}

nonisolated struct TrackLayout: Sendable {
    let pieces: [PlacedPiece]
    let lanes: LaneSplines
    /// Where the first piece's entry sits. No longer always the origin: a
    /// track that descends from its start gate is lifted so its LOWEST
    /// point rests on the ground (see `solve`), which puts the start above
    /// it. Everything else is measured against this, not against zero.
    let startPosition: SIMD3<Float>
    let exitPosition: SIMD3<Float>
    let exitYaw: Float
    let exitLevel: Int
    /// Exit meets the start again (position + heading) → circuit.
    var isClosedCircuit: Bool {
        simd_length(exitPosition - startPosition) < 0.05
            && abs(remainderYaw(exitYaw)) < 0.01
    }
}

nonisolated func rotated(_ v: SIMD3<Float>, by yaw: Float) -> SIMD3<Float> {
    let c = cos(yaw), s = sin(yaw)
    return [v.x * c + v.z * s, v.y, -v.x * s + v.z * c]
}

/// Yaw wrapped to (−π, π] so full turns compare equal.
nonisolated func remainderYaw(_ yaw: Float) -> Float {
    remainder(yaw, 2 * .pi)
}

nonisolated enum TrackLayoutSolver {

    /// Places every segment. Does NOT validate — BlueprintValidator uses this
    /// same placement to check overlaps/closure, so they can never disagree.
    static func solve(_ blueprint: TrackBlueprint) -> TrackLayout {
        var pieces: [PlacedPiece] = []
        // Levels are RELATIVE until we know how far the track digs, then the
        // whole thing is lifted so its lowest point rests on the ground.
        // That is what lets a track start on a descent: the start gate ends
        // up above ground and the finish at level 0, instead of the first
        // hillDown reading as "underground" and being rejected. It also
        // makes underground impossible by construction — the validator used
        // to carry a rule for it and no longer needs one.
        let defs = definitions(for: blueprint)
        let startLevel = -min(0, runningLevels(defs).min() ?? 0)
        var position = SIMD3<Float>(0, Float(startLevel) * RaceTuning.elevationLevelHeight, 0)
        let startPosition = position
        var yaw: Float = 0
        var level = startLevel

        for (segment, def) in zip(blueprint.segments, defs) {
            pieces.append(PlacedPiece(
                index: segment.index, definition: def,
                entryPosition: position, entryYaw: yaw, entryLevel: level))
            position += rotated(def.exitOffset, by: yaw)
            yaw += def.headingChange
            level += def.elevationDelta
        }

        return TrackLayout(
            pieces: pieces,
            lanes: splines(for: pieces),
            startPosition: startPosition,
            exitPosition: position, exitYaw: yaw, exitLevel: level)
    }

    /// Elevation level at every piece's ENTRY plus the final exit, measured
    /// from a level-0 start. Only the minimum is interesting — it says how
    /// far the track would dig below ground if it started there.
    private static func runningLevels(_ defs: [TrackPieceDefinition]) -> [Int] {
        var level = 0
        return [0] + defs.map {
            level += $0.elevationDelta
            return level
        }
    }

    /// One definition per segment, with each hill resolved against its
    /// neighbours (see `HillRole`).
    ///
    /// A "run" is consecutive segments of the SAME hill type, so `hillUp`
    /// straight into `hillDown` is a peak — two solo pieces — not a run of
    /// two. Runs of one keep the one-piece `hill-complete`; longer runs get
    /// a transition at each end with pitched straight track between, which
    /// is how the toy is actually assembled. Before this, every hill was
    /// the level-in/level-out piece, so a chain of them climbed in a
    /// staircase of humps instead of one continuous slope.
    private static func definitions(for blueprint: TrackBlueprint) -> [TrackPieceDefinition] {
        let types = blueprint.segments.map(\.type)
        return types.indices.map { i in
            let type = types[i]
            guard type == .hillUp || type == .hillDown else {
                return PieceCatalog.definition(for: type)
            }
            let opensRun = i == 0 || types[i - 1] != type
            let closesRun = i == types.count - 1 || types[i + 1] != type
            let role: HillRole = switch (opensRun, closesRun) {
            case (true, true):   .solo
            case (true, false):  .entry
            case (false, true):  .exit
            case (false, false): .middle
            }
            return PieceCatalog.definition(for: type, role: role)
        }
    }

    // MARK: Splines

    private static func splines(for pieces: [PlacedPiece]) -> LaneSplines {
        var center: [SIMD3<Float>] = []
        var laterals: [SIMD3<Float>] = []
        var widths: [Float] = []
        var pieceStarts: [Int] = []

        for piece in pieces {
            pieceStarts.append(center.count)
            let (localCenter, localLateral) = localCenterline(piece.definition)
            for (p, lat) in zip(localCenter, localLateral) {
                let world = piece.entryPosition + rotated(p, by: piece.entryYaw)
                // Skip duplicate joint points between consecutive pieces.
                if let last = center.last, simd_length(last - world) < 0.01 { continue }
                center.append(world)
                laterals.append(rotated(lat, by: piece.entryYaw))
                widths.append(piece.definition.laneHalfWidth)
            }
        }

        // Taper lane width across wide↔narrow piece transitions (the loop,
        // the gates). A hard step jogs the lane sideways between adjacent
        // waypoints; DriveSystem's centripetal feedforward reads that jog as
        // an impossibly tight curve and catapults the car off the track
        // (sim drills: 30 m/s ejections at the seams). Real Hot Wheels
        // merge guides taper too.
        // ±0.8 m at 0.1 m spacing: the loop MODEL's narrow lead-in rails
        // reach ~0.5 m back over the neighbouring piece (sim drills: the
        // wide monster truck clipped them at the wide-lane offset), so the
        // lanes must be near centre well before the loop piece itself.
        let window = 8
        let smoothed = widths.indices.map { i -> Float in
            let lo = max(0, i - window), hi = min(widths.count - 1, i + window)
            return widths[lo...hi].reduce(0, +) / Float(hi - lo + 1)
        }
        var left: [SIMD3<Float>] = []
        var right: [SIMD3<Float>] = []
        for i in center.indices {
            left.append(center[i] + laterals[i] * smoothed[i])
            right.append(center[i] - laterals[i] * smoothed[i])
        }
        return LaneSplines(center: center, left: left, right: right,
                           pieceStartIndices: pieceStarts, laterals: laterals)
    }

    /// Fraction of the rise reached at `t` along a measured bed profile.
    /// Samples are sorted on t and always span 0…1, so a linear walk is
    /// enough — there are eleven of them.
    private static func height(of samples: [SIMD2<Float>], at t: Float) -> Float {
        guard let after = samples.firstIndex(where: { $0.x >= t }) else {
            return samples.last?.y ?? 0
        }
        guard after > 0 else { return samples[0].y }
        let a = samples[after - 1], b = samples[after]
        let span = b.x - a.x
        return span > 1e-6 ? a.y + (b.y - a.y) * (t - a.x) / span : a.y
    }

    /// Centerline waypoints + unit "left" lateral vector per waypoint,
    /// both in the piece's traversal frame.
    private static func localCenterline(_ def: TrackPieceDefinition)
        -> (points: [SIMD3<Float>], lateral: [SIMD3<Float>]) {
        let spacing = RaceTuning.waypointSpacing
        var points: [SIMD3<Float>] = []
        var lateral: [SIMD3<Float>] = []

        switch def.shape {
        case .line(let length, let rise):
            let n = max(1, Int((length / spacing).rounded(.up)))
            for i in 0...n {
                let t = Float(i) / Float(n)
                points.append([0, rise * t, length * t])
                lateral.append([1, 0, 0])  // +X = left when heading +Z
            }

        case .profiled(let length, let rise, let samples):
            // Walk the measured bed: the piece advances evenly along the
            // run and takes its height from the profile, so the spline IS
            // the drawn surface rather than a chord across it.
            let n = max(2, Int((length / spacing).rounded(.up)))
            for i in 0...n {
                let t = Float(i) / Float(n)
                points.append([0, rise * height(of: samples, at: t), length * t])
                lateral.append([1, 0, 0])
            }

        case .crest(let length, let height):
            // Raised cosine: y = h/2·(1 − cos 2πt). Zero at both ends (so
            // the piece swaps with a straight), zero SLOPE at both ends
            // (so neither seam kinks), convex over the top — which is the
            // whole point, since the rail follower launches exactly where
            // the bed's downward slope beats gravity.
            let n = max(2, Int((length / spacing).rounded(.up)))
            for i in 0...n {
                let t = Float(i) / Float(n)
                points.append([0, height / 2 * (1 - cos(2 * .pi * t)), length * t])
                lateral.append([1, 0, 0])
            }

        case .arc(let radius, let leftTurn):
            let n = max(2, Int((radius * .pi / 2 / spacing).rounded(.up)))
            let sign: Float = leftTurn ? 1 : -1
            for i in 0...n {
                let a = Float(i) / Float(n) * .pi / 2
                // Right turn: center at (−r, 0, 0); mirrored in x for left.
                points.append([sign * (radius - radius * cos(a)), 0, radius * sin(a)])
                // Lateral rotates with the heading: left = up × tangent.
                // (The z sign was mirrored here for a long time, which swept
                // the "left" lane across to the right through every curve and
                // jogged it 0.1 m back at the exit seam — the rail follower's
                // up vector, cross(tangent, lateral), exposed it by planting
                // cars under the bed mid-curve.)
                lateral.append([cos(a), 0, -sign * sin(a)])
            }

        case .verticalLoop(let radius, let advance, let lateralShift):
            let stub = advance / 2
            points.append([0, 0, 0]); lateral.append([1, 0, 0])
            let n = max(8, Int((2 * .pi * radius / spacing).rounded(.up)))
            for i in 0...n {
                let t = Float(i) / Float(n)
                let a = t * 2 * .pi
                points.append([lateralShift * t,
                               radius * (1 - cos(a)),
                               stub + radius * sin(a)])
                // Lateral is the loop's axis — constant through the circle.
                lateral.append([1, 0, 0])
            }
            points.append([lateralShift, 0, advance]); lateral.append([1, 0, 0])
        }
        return (points, lateral)
    }
}
