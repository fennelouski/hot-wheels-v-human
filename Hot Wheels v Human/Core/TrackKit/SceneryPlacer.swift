//
//  SceneryPlacer.swift
//  Hot Wheels v Human
//
//  Hand-placed decorations → entities. Shared by the builder preview and
//  the race arena so a placed prop looks identical in both. Decoration
//  only: no collision, flung cars sail through (same rule as the
//  scattered theme props).
//

import RealityKit

@MainActor
enum SceneryPlacer {

    /// Entity name doubles as the change-detection key (ArenaView /
    /// builder holder-name dedupe pattern). Hashes are process-stable,
    /// which is all change detection needs.
    static func name(for items: [SceneryItem]) -> String {
        "scenery-\(items.hashValue)"
    }

    /// The scenery index a tapped entity stands for, if it is one.
    static func itemIndex(of entity: Entity) -> Int? {
        guard entity.name.hasPrefix("decor-item-") else { return nil }
        return Int(entity.name.dropFirst("decor-item-".count))
    }

    /// `tappable` (builder only) makes each prop a tap target so the kid
    /// can pick it up and move it; the arena spawns plain visuals — no
    /// collision, flung cars sail through. `highlight` lifts the item
    /// currently being moved so it reads as "picked up".
    static func spawn(_ items: [SceneryItem], tappable: Bool = false,
                      highlight: Int? = nil,
                      assets: AssetStore? = nil) async -> Entity {
        let assets = assets ?? AssetStore.shared
        let root = Entity()
        root.name = name(for: items)
        for (index, item) in items.enumerated() {
            guard let entity = try? await assets.entity(named: item.model) else { continue }
            entity.name = "decor-item-\(index)"
            entity.position = [item.x, 0, item.z]
            entity.orientation = simd_quatf(angle: item.yaw, axis: [0, 1, 0])
            if tappable {
                let bounds = entity.visualBounds(relativeTo: entity)
                entity.components.set(CollisionComponent(
                    shapes: [.generateBox(size: bounds.extents)
                        .offsetBy(translation: bounds.center)]))
                entity.components.set(InputTargetComponent())
            }
            if index == highlight {
                entity.position.y += 0.15
                entity.scale *= 1.15
            }
            root.addChild(entity)
        }
        return root
    }
}
