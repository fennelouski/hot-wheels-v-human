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
}

struct TrackLayout: Sendable {
    let pieces: [PlacedPiece]
    let lanes: LaneSplines
    let exitPosition: SIMD3<Float>
    let exitYaw: Float
    let exitLevel: Int
    /// Exit meets the start again (position + heading) → circuit.
    var isClosedCircuit: Bool {
        simd_length(exitPosition) < 0.05 && abs(remainderYaw(exitYaw)) < 0.01
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
        var left: [SIMD3<Float>] = []
        var right: [SIMD3<Float>] = []
        var pieceStarts: [Int] = []

        for piece in pieces {
            pieceStarts.append(center.count)
            let (localCenter, localLateral) = localCenterline(piece.definition)
            for (p, lat) in zip(localCenter, localLateral) {
                let world = piece.entryPosition + rotated(p, by: piece.entryYaw)
                // Skip duplicate joint points between consecutive pieces.
                if let last = center.last, simd_length(last - world) < 0.01 { continue }
                let latWorld = rotated(lat, by: piece.entryYaw)
                center.append(world)
                left.append(world + latWorld * piece.definition.laneHalfWidth)
                right.append(world - latWorld * piece.definition.laneHalfWidth)
            }
        }
        return LaneSplines(center: center, left: left, right: right,
                           pieceStartIndices: pieceStarts)
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

        case .arc(let radius, let leftTurn):
            let n = max(2, Int((radius * .pi / 2 / spacing).rounded(.up)))
            let sign: Float = leftTurn ? 1 : -1
            for i in 0...n {
                let a = Float(i) / Float(n) * .pi / 2
                // Right turn: center at (−r, 0, 0); mirrored in x for left.
                points.append([sign * (radius - radius * cos(a)), 0, radius * sin(a)])
                // Lateral rotates with the heading.
                lateral.append([cos(a), 0, sign * sin(a)])
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
