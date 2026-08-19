//
//  SceneryPlacer.swift
//  Hot Wheels v Human
//
//  Hand-placed decorations → entities. Shared by the builder preview and
//  the race arena so a placed prop looks identical in both. Decoration
//  only: no collision, flung cars sail through (same rule as the
//  scattered theme props).
//

import CoreGraphics
import RealityKit
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Placeable sky-stuff for the Space world (any world, really): planets,
/// a moon, nebulae. No kit ships these, so they're generated — spheres
/// with banded CG textures, a ring disc, soft billboarded gradient quads.
/// They float above the ground where placed and turn slowly.
@MainActor
enum SpaceStuff {
    static let models = ["space-planet-a", "space-planet-b", "space-planet-rings",
                         "space-moon", "space-nebula-pink", "space-nebula-teal"]

    static func isSpaceStuff(_ model: String) -> Bool { models.contains(model) }

    /// How high off the ground each floats when placed — sky-height for
    /// the TOY scale (a skyscraper is ~1.2 m), not real-sky height, so
    /// they hang in view of the builder camera and the chase cam.
    static func floatHeight(_ model: String) -> Float {
        if model.hasPrefix("space-nebula") { return 1.3 }
        if model == "space-moon" { return 0.7 }
        return 0.95
    }

    static func make(_ model: String) async -> Entity? {
        switch model {
        case "space-planet-a":
            return await planet(radius: 0.34,
                                colors: [(0.95, 0.55, 0.25), (0.85, 0.35, 0.20),
                                         (0.98, 0.75, 0.45)])
        case "space-planet-b":
            return await planet(radius: 0.28,
                                colors: [(0.25, 0.55, 0.90), (0.20, 0.35, 0.70),
                                         (0.55, 0.80, 0.95)])
        case "space-planet-rings":
            guard let body = await planet(
                radius: 0.26, colors: [(0.90, 0.80, 0.55), (0.80, 0.65, 0.40),
                                       (0.96, 0.90, 0.70)]) else { return nil }
            var ringMaterial = PhysicallyBasedMaterial()
            ringMaterial.baseColor = .init(tint: .init(red: 0.85, green: 0.78,
                                                       blue: 0.60, alpha: 1))
            ringMaterial.roughness = 0.8
            let ring = ModelEntity(
                mesh: .generateCylinder(height: 0.006, radius: 0.48),
                materials: [ringMaterial])
            ring.orientation = simd_quatf(angle: 0.35, axis: [1, 0, 0.3])
            body.addChild(ring)
            return body
        case "space-moon":
            return await planet(radius: 0.16,
                                colors: [(0.72, 0.72, 0.74), (0.55, 0.55, 0.58),
                                         (0.82, 0.82, 0.84)])
        case "space-nebula-pink":
            return await nebula(red: 0.95, green: 0.45, blue: 0.75)
        case "space-nebula-teal":
            return await nebula(red: 0.35, green: 0.85, blue: 0.85)
        default:
            return nil
        }
    }

    private static func planet(radius: Float,
                               colors: [(CGFloat, CGFloat, CGFloat)]) async -> Entity? {
        var material = PhysicallyBasedMaterial()
        material.roughness = 0.9
        if let image = bandedImage(colors: colors),
           let texture = try? await TextureResource(
               image: image, options: .init(semantic: .color)) {
            material.baseColor = .init(texture: .init(texture))
        } else {
            material.baseColor = .init(tint: .init(red: colors[0].0, green: colors[0].1,
                                                   blue: colors[0].2, alpha: 1))
        }
        return ModelEntity(mesh: .generateSphere(radius: radius),
                           materials: [material])
    }

    /// A soft gradient quad that always faces the camera.
    private static func nebula(red: CGFloat, green: CGFloat, blue: CGFloat) async -> Entity? {
        var material = UnlitMaterial()
        if let image = glowImage(red: red, green: green, blue: blue),
           let texture = try? await TextureResource(
               image: image, options: .init(semantic: .color)) {
            material.color = .init(texture: .init(texture))
        }
        material.blending = .transparent(opacity: 1.0)
        material.opacityThreshold = 0
        let quad = ModelEntity(mesh: .generatePlane(width: 1.5, height: 1.0),
                               materials: [material])
        quad.components.set(BillboardComponent())
        return quad
    }

    private static func bandedImage(colors: [(CGFloat, CGFloat, CGFloat)]) -> CGImage? {
        let w = 256, h = 128
        guard let ctx = CGContext(
            data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        for y in 0..<h {
            // Wobbly latitude bands — reads as a cartoon gas giant.
            let band = Int((Float(y) / 14 + 1.5 * sin(Float(y) * 0.35)).rounded())
            let color = colors[((band % colors.count) + colors.count) % colors.count]
            ctx.setFillColor(CGColor(red: color.0, green: color.1, blue: color.2, alpha: 1))
            ctx.fill(CGRect(x: 0, y: y, width: w, height: 1))
        }
        return ctx.makeImage()
    }

    private static func glowImage(red: CGFloat, green: CGFloat, blue: CGFloat) -> CGImage? {
        let size = 256
        guard let ctx = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let colors = [CGColor(red: red, green: green, blue: blue, alpha: 0.85),
                      CGColor(red: red, green: green, blue: blue, alpha: 0.35),
                      CGColor(red: red, green: green, blue: blue, alpha: 0)] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: colors,
                                        locations: [0, 0.45, 1]) else { return nil }
        let center = CGPoint(x: size / 2, y: size / 2)
        ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 0,
                               endCenter: center, endRadius: CGFloat(size) / 2,
                               options: [])
        return ctx.makeImage()
    }
}

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
    /// Placeable people (mini-characters with a baked walk clip) —
    /// they stroll a little patrol line from where the kid puts them.
    static func isPerson(_ model: String) -> Bool { model.hasPrefix("person-") }

    /// Placeable vehicles — placed on a road they join traffic; placed on
    /// the grass they drive to the nearest road first; no roads at all
    /// and they sit parked where the kid left them.
    static let vehicles: Set<String> = [
        "taxi", "police", "ambulance", "sedan-sports", "suv", "truck",
        "race-car-red", "race-car-green", "firetruck", "garbage-truck",
        "delivery", "van", "sedan", "suv-luxury", "hatchback-sports", "tractor",
    ]
    static func isVehicle(_ model: String) -> Bool { vehicles.contains(model) }

    /// Nearest CONNECTED pavement cell — a lone path stone is no
    /// sidewalk, just a stepping stone.
    static func nearestPavement(to position: SIMD3<Float>,
                                in cells: Set<SIMD2<Int32>>) -> SIMD2<Int32>? {
        let connected = cells.filter { cell in
            [SIMD2<Int32>(0, 1), SIMD2(0, -1), SIMD2(1, 0), SIMD2(-1, 0)]
                .contains { cells.contains(cell &+ $0) }
        }
        let p = SIMD2(position.x, position.z)
        return connected.min { a, b in
            simd_length_squared(SIMD2(Float(a.x), Float(a.y)) * 0.35 - p)
                < simd_length_squared(SIMD2(Float(b.x), Float(b.y)) * 0.35 - p)
        }
    }

    /// Sidewalk graph implied by hand-placed pavement (0.35 m cells):
    /// path stones map to their cell, the wide pavement square covers its
    /// cell plus the four around it, so adjacent squares connect.
    static func pavementCells(in items: [SceneryItem]) -> Set<SIMD2<Int32>> {
        var cells = Set<SIMD2<Int32>>()
        for item in items {
            let cell = SIMD2(Int32((item.x / 0.35).rounded()),
                             Int32((item.z / 0.35).rounded()))
            if item.model.hasPrefix("city-path") {
                cells.insert(cell)
            } else if item.model == "street-square" {
                cells.insert(cell)
                cells.formUnion([cell &+ SIMD2(0, 1), cell &- SIMD2(0, 1),
                                 cell &+ SIMD2(1, 0), cell &- SIMD2(1, 0)])
            }
        }
        return cells
    }

    /// Hand-placed buildings people can pop into (the 1-in-100 shop
    /// visit): anything with a door, mapped to its 0.7 m street-grid cell.
    static func isBuilding(_ model: String) -> Bool {
        model.hasPrefix("city-house") || model.hasPrefix("city-shop")
            || model.hasPrefix("city-skyscraper")
    }

    static func handBuildingCells(in items: [SceneryItem]) -> Set<SIMD2<Int32>> {
        var cells = Set<SIMD2<Int32>>()
        for item in items where isBuilding(item.model) {
            cells.insert(SIMD2(Int32((item.x / 0.7).rounded()),
                               Int32((item.z / 0.7).rounded())))
        }
        return cells
    }

    /// Street cells implied by hand-placed road tiles (street-* snap to
    /// the 0.7 m traffic grid) — unioned with a world's auto-laid grid so
    /// traffic drives the kid's roads too.
    static func handStreetCells(in items: [SceneryItem]) -> Set<SIMD2<Int32>> {
        var cells = Set<SIMD2<Int32>>()
        for item in items where item.model.hasPrefix("street-") {
            cells.insert(SIMD2(Int32((item.x / 0.7).rounded()),
                               Int32((item.z / 0.7).rounded())))
        }
        return cells
    }

    /// Barrier roads: a dead-end road tile with a roadblock standing on
    /// it. NPC traffic reaching one TURNS AROUND instead of fading out
    /// (TrafficComponent.barriers). Two looks; both are composed from
    /// pieces already in the bundle.
    static let barrierRoads: [String: String] = [
        "street-barrier-a": "build-barrier",    // construction roadblock
        "street-barrier-b": "city-fence",       // white picket roadblock
    ]

    static func isBarrierRoad(_ model: String) -> Bool {
        barrierRoads.keys.contains(model)
    }

    /// Cells of hand-placed barrier roads (0.7 m street grid).
    static func barrierCells(in items: [SceneryItem]) -> Set<SIMD2<Int32>> {
        var cells = Set<SIMD2<Int32>>()
        for item in items where isBarrierRoad(item.model) {
            cells.insert(SIMD2(Int32((item.x / 0.7).rounded()),
                               Int32((item.z / 0.7).rounded())))
        }
        return cells
    }

    /// One resolver for every placeable thing: kit models come from the
    /// AssetStore, sky-stuff is generated, barrier roads are composed.
    /// (Tests use this too — it is the definition of "this palette entry
    /// actually works".)
    static func entity(for model: String, assets: AssetStore? = nil) async -> Entity? {
        if SpaceStuff.isSpaceStuff(model) {
            return await SpaceStuff.make(model)
        }
        let store = assets ?? AssetStore.shared
        if let blockModel = barrierRoads[model] {
            // Dead-end tile (open side faces −z at yaw 0) with the
            // roadblock standing across its closed end.
            guard let tile = try? await store.entity(named: "street-end"),
                  let block = try? await store.entity(named: blockModel)
            else { return nil }
            block.position = [0, 0.005, 0.22]
            tile.addChild(block)
            return tile
        }
        return try? await store.entity(named: model)
    }

    /// `autoStreets` is the world's own road grid (empty for worlds
    /// without one); hand-laid street tiles in `items` extend it, and
    /// placed vehicles drive the union. Placed people walk ONE joined
    /// sidewalk network — the road edges plus hand-laid pavement — and
    /// `autoBuildings` (the world's block cells) joins their door list.
    static func spawn(_ items: [SceneryItem], tappable: Bool = false,
                      highlight: Int? = nil,
                      autoStreets: Set<SIMD2<Int32>> = [],
                      autoBuildings: Set<SIMD2<Int32>> = [],
                      assets: AssetStore? = nil) async -> Entity {
        let assets = assets ?? AssetStore.shared
        AmbientMotionComponent.registerComponent()
        AmbientMotionSystem.registerSystem()
        WalkerComponent.registerComponent()
        WalkerSystem.registerSystem()
        TrafficComponent.registerComponent()
        TrafficSystem.registerSystem()
        WanderComponent.registerComponent()
        WanderSystem.registerSystem()
        PedestrianComponent.registerComponent()
        PedestrianSystem.registerSystem()
        let streets = autoStreets.union(handStreetCells(in: items))
        let barriers = barrierCells(in: items)
        // People walk one network: the streets' sidewalk edges joined
        // with hand-laid pavement (same 0.35 m grid, so adjacent cells
        // connect and a hand path can lead off a city street).
        let roadside = ArenaEnvironment.sidewalkCells(from: streets)
        let pavement = pavementCells(in: items).union(roadside)
        let doors = autoBuildings.union(handBuildingCells(in: items))
        let root = Entity()
        root.name = name(for: items)
        for (index, item) in items.enumerated() {
            guard let entity = await entity(for: item.model, assets: assets) else { continue }
            entity.name = "decor-item-\(index)"
            // Sky-stuff floats where placed; everything else sits down.
            let height = SpaceStuff.isSpaceStuff(item.model)
                ? SpaceStuff.floatHeight(item.model) : 0
            entity.position = [item.x, height, item.z]
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
            } else if isPerson(item.model) {
                var seed = UInt64(truncatingIfNeeded: index &* 271) &+ 0x9ED
                // Near a sidewalk (path stones or pavement)? Walk the
                // network, turning around at its ends. Otherwise the
                // little back-and-forth patrol from the placement spot.
                if let target = nearestPavement(to: entity.position, in: pavement),
                   simd_length(SIMD3<Float>(Float(target.x) * 0.35, 0,
                                            Float(target.y) * 0.35)
                       - entity.position) < 1.5 {
                    entity.components.set(PedestrianComponent(
                        cells: pavement, cell: target, direction: SIMD2(0, 1),
                        sideOffset: index % 2 == 0 ? -0.26 : 0.26,
                        buildings: doors, roadside: roadside,
                        seeking: true, worldPos: entity.position, seed: seed))
                } else {
                    entity.components.set(WalkerComponent(
                        origin: entity.position, yaw: item.yaw))
                }
            } else if isVehicle(item.model) {
                var seed = UInt64(truncatingIfNeeded: item.model.hashValue)
                    &+ UInt64(index) &* 7919
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                if let target = TrafficSystem.nearestCell(to: entity.position,
                                                          in: streets) {
                    // Drive to the nearest road, then join traffic.
                    entity.components.set(TrafficComponent(
                        cells: streets, cell: target, direction: SIMD2(0, 1),
                        seeking: true, worldPos: entity.position,
                        barriers: barriers, seed: seed))
                    entity.components.set(OpacityComponent(opacity: 0))
                } else {
                    // No roads anywhere: wander near the placement spot.
                    entity.components.set(WanderComponent(
                        origin: entity.position, heading: item.yaw,
                        phase: Float(index % 5) * 1.3))
                }
            } else {
                AmbientMotion.apply(to: entity, model: item.model,
                                    vary: Float(index % 7) / 7)
            }
            if isPerson(item.model),
               let animation = entity.availableAnimations.first {
                entity.playAnimation(animation.repeat())
            }
            root.addChild(entity)
        }
        return root
    }
}
