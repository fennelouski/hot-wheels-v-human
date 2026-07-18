//
//  TrackSpawner.swift
//  Hot Wheels v Human
//
//  Solved layout → RealityKit entity hierarchy with static collision.
//

import RealityKit

/// Tags gate pieces (and later, piece boundaries) for RaceRulesSystem.
struct CheckpointComponent: Component {
    let pieceIndex: Int
    let isFinish: Bool
}

@MainActor
enum TrackSpawner {

    /// Sink the leg stack this far so the bottom plants in the play-mat
    /// (ArenaEnvironment puts it at −0.03) instead of hovering 3 cm over it,
    /// with 0.01 spare against z-fighting. The top still hides inside the
    /// 0.06 m bed. Cosmetic, so it lives here rather than in RaceTuning —
    /// same as ArenaEnvironment's own ground/sky numbers.
    private static let legPlant: Float = -0.04

    /// Builds the whole track under one root entity. Caller adds it to the scene.
    static func spawn(layout: TrackLayout, assets: AssetStore? = nil) async throws -> Entity {
        let assets = assets ?? AssetStore.shared
        CheckpointComponent.registerComponent()

        let root = Entity()
        root.name = "track"

        for piece in layout.pieces {
            let model = try await assets.entity(named: piece.definition.modelName)
            model.name = "piece-\(piece.index)-\(piece.definition.type.rawValue)"
            model.position = piece.modelPosition
            model.orientation = simd_quatf(angle: piece.modelYaw, axis: [0, 1, 0])
            try await addStaticCollision(to: model)
            root.addChild(model)

            if let overlayName = piece.definition.overlayModelName {
                let overlay = try await assets.entity(named: overlayName)
                overlay.name = "overlay-\(piece.index)-\(overlayName)"
                overlay.position = piece.overlayPosition
                overlay.orientation = simd_quatf(angle: piece.entryYaw, axis: [0, 1, 0])
                overlay.components.set(CheckpointComponent(
                    pieceIndex: piece.index,
                    isFinish: piece.definition.type == .finishGate))
                root.addChild(overlay)
            }

            // Cosmetic legs under elevated pieces. The supports* models are
            // authored one elevation level tall (0.2 m) with their base at
            // the origin, so level N stacks N of them from the ground up —
            // no scaling. Hills are skipped: their bed slopes through the
            // piece, so a full-height post pokes through a hillDown, and the
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
                for level in 0..<piece.entryLevel {
                    let leg = try await assets.entity(named: legModel)
                    leg.name = "support-\(piece.index)-\(level)"
                    let y = Float(level) * RaceTuning.elevationLevelHeight + legPlant
                    leg.position = SIMD3<Float>(centerX, y, centerZ)
                    leg.orientation = simd_quatf(angle: piece.entryYaw, axis: [0, 1, 0])
                    root.addChild(leg)
                }
            }
        }
        return root
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
