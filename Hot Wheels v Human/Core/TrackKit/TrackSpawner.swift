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

    /// Builds the whole track under one root entity. Caller adds it to the scene.
    static func spawn(layout: TrackLayout, assets: AssetStore = .shared) async throws -> Entity {
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
        }
        // ponytail: cosmetic supports* under elevated pieces arrive with the
        // first elevated track in Phase 2 — the demo track is flat.
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
