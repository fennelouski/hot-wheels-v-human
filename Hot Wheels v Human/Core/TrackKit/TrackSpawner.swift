//
//  TrackSpawner.swift
//  Hot Wheels v Human
//
//  Solved layout → RealityKit entity hierarchy with static collision.
//

import Foundation
import RealityKit

/// Tags gate pieces (and later, piece boundaries) for RaceRulesSystem.
struct CheckpointComponent: Component {
    let pieceIndex: Int
    let isFinish: Bool
}

/// Tags a spawned track VISUAL — the piece model, its gate arch, its
/// support legs — so the arena's show/hide switch can find them. Collision
/// beds are deliberately untagged: they're invisible already and must never
/// change, which is what keeps a hidden piece fully drivable.
struct TrackVisualComponent: Component {
    let isGhost: Bool
}

/// The three-way track switch, in the order it steps. String-backed
/// because it rides the wire both ways — the iPad asks for a state, the
/// host's snapshots report the one that's actually on (GameMessage).
nonisolated enum TrackVisibility: String, Codable, CaseIterable, Sendable {
    case all, hideGhosts, hideAll

    var ghostOpacity: Float { self == .all ? 1 : 0 }
    var solidOpacity: Float { self == .hideAll ? 0 : 1 }
}

@MainActor
enum TrackSpawner {

    /// Plant the BOTTOM of a ground stack this far down so it meets the
    /// play-mat (ArenaEnvironment puts it at −0.03) instead of hovering 3 cm
    /// over it, with 0.01 spare against z-fighting. It stretches the bottom
    /// leg rather than sinking the whole stack: sinking dropped the TOP of
    /// the stack 4 cm clear of the bed it holds up, which read as legs
    /// floating under the track. Cosmetic, so it lives here rather than in
    /// RaceTuning — same as ArenaEnvironment's own ground/sky numbers.
    private static let legPlant: Float = -0.04

    /// Builds the whole track under one root entity. Caller adds it to the scene.
    static func spawn(layout: TrackLayout, assets: AssetStore? = nil) async throws -> Entity {
        let assets = assets ?? AssetStore.shared
        CheckpointComponent.registerComponent()
        TrackVisualComponent.registerComponent()

        let root = Entity()
        root.name = "track"

        for (pi, piece) in layout.pieces.enumerated() {
            let model = try await assets.entity(named: piece.definition.modelName)
            model.name = "piece-\(piece.index)-\(piece.definition.type.rawValue)"
            model.position = piece.modelPosition
            model.orientation = simd_quatf(angle: piece.modelYaw, axis: [0, 1, 0])
                * simd_quatf(angle: piece.definition.modelPitch, axis: [1, 0, 0])
            // Scale is applied before rotation (TRS), which is what the hill
            // meshes' Y stretch assumes — it has to act along the mesh's own
            // up axis, not the world's.
            model.scale = piece.definition.modelScale
            model.components.set(TrackVisualComponent(isGhost: piece.isGhost))
            // Cars collide with SOLVED geometry, not the visual meshes —
            // the models carry raised ramps/tabs/lead-ins beyond their
            // logical footprints, and cars hitting those exact meshes got
            // depenetration-launched at ~38 m/s (sim drills; the gate
            // ramps and the loop's lead-in lip were the worst). Flat
            // pieces get one bed slab; the loop gets a chain of boxes
            // riding its own centerline (the same spline DriveSystem
            // follows). Only the jump ramp keeps its exact mesh — the
            // ramp lip IS its gameplay.
            switch piece.definition.type {
            case .rampJump, .bump:
                // Both are the bump-up mesh and both crest — the lip IS the
                // gameplay, so chaos mode collides with the real hump rather
                // than a flat slab it would sink through.
                try await addStaticCollision(to: model)
            case .loop:
                root.addChild(splineCollision(for: piece, index: pi,
                                              lanes: layout.lanes, width: 0.2))
            case _ where isProfiled(piece.definition.shape):
                // A hill's bed is a measured curve that bows up to 7 cm
                // away from its own chord, so one pitched slab can't
                // describe it — it follows the spline like the loop does.
                // The pitched straights mid-run are `.line`, so they still
                // get the cheap slab.
                root.addChild(splineCollision(for: piece, index: pi,
                                              lanes: layout.lanes, width: 0.4))
            default:
                root.addChild(bedCollision(for: piece))
            }
            root.addChild(model)

            if let overlayName = piece.definition.overlayModelName {
                let overlay = try await assets.entity(named: overlayName)
                overlay.name = "overlay-\(piece.index)-\(overlayName)"
                overlay.position = piece.overlayPosition
                overlay.orientation = simd_quatf(angle: piece.entryYaw, axis: [0, 1, 0])
                overlay.components.set(CheckpointComponent(
                    pieceIndex: piece.index,
                    isFinish: piece.definition.type == .finishGate))
                overlay.components.set(TrackVisualComponent(isGhost: piece.isGhost))
                root.addChild(overlay)
            }

            // Cosmetic legs under elevated pieces. The supports* models are
            // authored one elevation level tall (0.2 m) with their base at
            // the origin, so the stack runs one per level from whatever is
            // underneath up to the bed. Hills are skipped: their bed slopes
            // through the piece, so a post pokes through a hillDown, and the
            // flat neighbours at each end carry the legs anyway.
            // No collision — a car that flies off must fall PAST these.
            if piece.entryLevel > 0, piece.definition.elevationDelta == 0 {
                let rect = piece.worldFootprint
                let legModel = piece.definition.modelName.contains("narrow")
                    ? "supports" : "supports-wide"
                // Split out: a SIMD3 literal with arithmetic in every slot
                // stalls the type-checker.
                let centerX: Float = (rect.minX + rect.maxX) / 2
                let centerZ: Float = (rect.minZ + rect.maxZ) / 2
                // Where track crosses over itself the lower deck IS the
                // support — a stack that starts at the ground stands its legs
                // on the orange track and runs up through it.
                let base = deckLevel(atX: centerX, z: centerZ,
                                     under: piece.entryLevel, in: layout.pieces)
                for level in base..<piece.entryLevel {
                    let leg = try await assets.entity(named: legModel)
                    leg.name = "support-\(piece.index)-\(level)"
                    // Exact level heights, so the top of the stack MEETS the
                    // bed it holds up (the models are one level tall, base at
                    // the origin). Only a ground stack reaches down further.
                    leg.position = SIMD3<Float>(
                        centerX, Float(level) * RaceTuning.elevationLevelHeight, centerZ)
                    if level == 0 {
                        leg.position.y = legPlant
                        leg.scale.y = (RaceTuning.elevationLevelHeight - legPlant)
                            / RaceTuning.elevationLevelHeight
                    }
                    leg.orientation = simd_quatf(angle: piece.entryYaw, axis: [0, 1, 0])
                    // A ghost's legs go with it — a piece you can't see
                    // held up by posts you can gives the trick away.
                    leg.components.set(TrackVisualComponent(isGhost: piece.isGhost))
                    root.addChild(leg)
                }
            }
        }
        return root
    }

    /// Repaint a spawned track's visuals. Ghost pieces get `ghosts`,
    /// everything else gets `solid` — the arena switch maps its three states
    /// onto 0/1 (`TrackVisibility`), the builder fades ghosts part-way so the
    /// kid can still see what they placed. Nothing else is touched, so the
    /// track drives exactly the same whatever you can see of it.
    static func setOpacity(on track: Entity, ghosts: Float, solid: Float = 1) {
        for child in track.children {
            guard let visual = child.components[TrackVisualComponent.self] else { continue }
            let opacity = visual.isGhost ? ghosts : solid
            if opacity >= 1 {
                child.components.remove(OpacityComponent.self)
            } else {
                child.components.set(OpacityComponent(opacity: opacity))
            }
        }
    }

    /// Which piece a hit entity belongs to — walks up to the named holder
    /// this spawner parented it under (`bed-3`, `piece-3-straight`,
    /// `support-3-1`, `overlay-3-…`). The builder taps pieces with it.
    static func pieceIndex(of entity: Entity) -> Int? {
        var node: Entity? = entity
        while let current = node {
            for prefix in ["bed-", "piece-", "overlay-", "support-"]
            where current.name.hasPrefix(prefix) {
                let digits = current.name.dropFirst(prefix.count).prefix(while: \.isNumber)
                if let index = Int(digits) { return index }
            }
            node = current.parent
        }
        return nil
    }

    /// Builder only: let taps hit the track. Targets the COLLISION, not the
    /// models — collision is where a ghost piece still exists, and it's the
    /// only hit test that stays honest at elevation (a ground-plane cast
    /// lands past a raised piece and picks the wrong one).
    static func makeTappable(_ track: Entity) {
        for entity in allDescendants(of: track)
        where entity.components[CollisionComponent.self] != nil {
            entity.components.set(InputTargetComponent())
        }
    }

    /// Lowest level a support stack may start at under (x, z): one above the
    /// highest deck already crossing that spot, or 0 over bare ground. The
    /// point test (not a rect overlap) is the question a leg actually asks —
    /// is there track directly under THIS post.
    static func deckLevel(atX x: Float, z: Float,
                          under level: Int, in pieces: [PlacedPiece]) -> Int {
        var base = 0
        for other in pieces {
            let top = max(other.entryLevel,
                          other.entryLevel + other.definition.elevationDelta)
            guard top < level else { continue }
            let rect = other.worldFootprint
            guard rect.minX < x, x < rect.maxX, rect.minZ < z, z < rect.maxZ else { continue }
            base = max(base, top + 1)
        }
        return base
    }

    /// Invisible drivable slab matching the piece's logical footprint,
    /// top at the bed surface. Hills pitch the slab along their rise.
    /// No side rails: the lane magnet holds cars on the bed, and flying
    /// off IS the game.
    private static func bedCollision(for piece: PlacedPiece) -> Entity {
        let rect = piece.definition.footprint
        let bedTop = RaceTuning.bedSurfaceHeight
        let thickness: Float = 0.1
        var size = SIMD3<Float>(rect.maxX - rect.minX, thickness, rect.maxZ - rect.minZ)
        var pitch: Float = 0
        var centerY = bedTop - thickness / 2
        if case .line(let length, let rise) = piece.definition.shape, rise != 0 {
            // NEGATIVE: a right-handed rotation about +X carries +Z toward
            // −Y, so `atan(rise/length)` tipped every hill's slab the
            // opposite way to its own spline. On a hillUp that stood the
            // slab's high end up at the ENTRY seam — a ~20 cm lip across
            // the track, exactly where cars arrive. That lip is the hill
            // wedge the stuck-rescue has been papering over; rail cars are
            // kinematic and float through it, so it went quiet rather than
            // away. Pinned by hillBedSlabsPitchAlongTheirOwnRise.
            pitch = -atan(rise / length)
            size.z = (length * length + rise * rise).squareRoot()
            centerY += rise / 2
        }
        let slab = Entity()
        slab.name = "bed-\(piece.index)"
        let local = SIMD3<Float>((rect.minX + rect.maxX) / 2, centerY,
                                 (rect.minZ + rect.maxZ) / 2)
        slab.position = piece.entryPosition + rotated(local, by: piece.entryYaw)
        slab.orientation = simd_quatf(angle: piece.entryYaw, axis: [0, 1, 0])
            * simd_quatf(angle: pitch, axis: [1, 0, 0])
        slab.components.set(CollisionComponent(
            shapes: [.generateBox(size: size)], isStatic: true))
        slab.components.set(PhysicsBodyComponent(
            massProperties: .default, material: nil, mode: .static))
        return slab
    }

    /// True where a flat slab can't stand in for the bed.
    private static func isProfiled(_ shape: CenterlineShape) -> Bool {
        if case .profiled = shape { true } else { false }
    }

    /// Bed collision that follows the piece's own centerline: a chain of
    /// short boxes, each oriented along the spline with its top face on the
    /// waypoints and its "up" taken from the track frame — the same
    /// `cross(tangent, lateral)` the rail follower rolls cars with. That
    /// makes the bed track the loop's ring all the way around (up points
    /// at the circle's centre, so it correctly flips to face the car at the
    /// top) and follow a hill's measured S, with none of the model mesh's
    /// stray lips either way.
    private static func splineCollision(for piece: PlacedPiece, index: Int,
                                        lanes: LaneSplines, width: Float) -> Entity {
        let start = lanes.pieceStartIndices[index]
        let end = index + 1 < lanes.pieceStartIndices.count
            ? lanes.pieceStartIndices[index + 1] : lanes.center.count - 1

        let holder = Entity()
        holder.name = "bed-\(piece.index)"
        let thickness: Float = 0.05
        for j in start..<end {
            let p0 = lanes.center[j], p1 = lanes.center[j + 1]
            let seg = p1 - p0
            let length = simd_length(seg)
            guard length > 1e-5 else { continue }
            let forward = seg / length
            var up = simd_cross(forward, lanes.laterals[j])
            // Orthogonalize against the tangent.
            up -= forward * simd_dot(up, forward)
            guard simd_length(up) > 1e-4 else { continue }
            up = simd_normalize(up)
            let right = simd_normalize(simd_cross(up, forward))
            let box = Entity()
            box.position = (p0 + p1) / 2 - up * (thickness / 2)
            box.orientation = simd_quatf(simd_float3x3(columns: (right, up, forward)))
            // 20% overlap hides the tiny angular steps between segments.
            box.components.set(CollisionComponent(
                shapes: [.generateBox(size: [width, thickness, length * 1.2])],
                isStatic: true))
            box.components.set(PhysicsBodyComponent(
                massProperties: .default, material: nil, mode: .static))
            holder.addChild(box)
        }
        return holder
    }

    /// Exact-mesh static collision on every model part (convex hulls would
    /// seal the loop's inside — cars must drive through it).
    private static func addStaticCollision(to entity: Entity) async throws {
        for part in allDescendants(of: entity) {
            guard let model = part.components[ModelComponent.self] else { continue }
            let shape = try await ShapeResource.generateStaticMesh(from: model.mesh)
            part.components.set(CollisionComponent(shapes: [shape], isStatic: true))
            part.components.set(PhysicsBodyComponent(
                massProperties: .default, material: nil, mode: .static))
        }
    }

    private static func allDescendants(of entity: Entity) -> [Entity] {
        entity.children.flatMap { [$0] + allDescendants(of: $0) } + [entity]
    }
}
