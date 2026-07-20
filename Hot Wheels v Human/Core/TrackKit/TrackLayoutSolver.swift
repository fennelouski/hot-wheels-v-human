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

struct PlacedPiece: Sendable {
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

struct LaneSplines: Sendable {
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

struct TrackLayout: Sendable {
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

func rotated(_ v: SIMD3<Float>, by yaw: Float) -> SIMD3<Float> {
    let c = cos(yaw), s = sin(yaw)
    return [v.x * c + v.z * s, v.y, -v.x * s + v.z * c]
}

/// Yaw wrapped to (−π, π] so full turns compare equal.
func remainderYaw(_ yaw: Float) -> Float {
    remainder(yaw, 2 * .pi)
}

enum TrackLayoutSolver {

    /// Places every segment. Does NOT validate — BlueprintValidator uses this
    /// same placement to check overlaps/closure, so they can never disagree.
    static func solve(_ blueprint: TrackBlueprint) -> TrackLayout {
        var pieces: [PlacedPiece] = []
        var position = SIMD3<Float>.zero
        var yaw: Float = 0
        var level = 0

        for segment in blueprint.segments {
            let def = PieceCatalog.definition(for: segment.type)
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
            exitPosition: position, exitYaw: yaw, exitLevel: level)
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
