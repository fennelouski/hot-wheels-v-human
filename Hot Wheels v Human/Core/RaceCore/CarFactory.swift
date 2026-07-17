//
//  CarFactory.swift
//  Hot Wheels v Human
//
//  CarDesign → physical car entity. Box collision (cheaper + more stable
//  than mesh), physics material from tires, paint by tinting the Kenney
//  flat-color materials.
//

import Foundation
import RealityKit
#if canImport(UIKit)
import UIKit
#endif

/// Identity + race state carried by every car entity.
struct CarComponent: Component {
    let playerID: UUID
    let design: CarDesign
    var livesLeft: Int
    var boostMeter: Float = 0
    /// Queued boost impulses (set by RaceCoordinator, consumed by DriveSystem).
    var pendingBoost: Bool = false
    var stuckSeconds: Float = 0
    var flippedSeconds: Float = 0
    var finished: Bool = false
}

/// Which lane spline the car follows and how far along it is.
struct LaneFollowComponent: Component {
    var waypoints: [SIMD3<Float>]
    var nextIndex: Int = 0
    var lapsDone: Int = 0
}

@MainActor
enum CarFactory {

    static func makeCar(design: CarDesign, playerID: UUID, lane: [SIMD3<Float>],
                        lives: Int, assets: AssetStore? = nil) async throws -> ModelEntity {
        let assets = assets ?? AssetStore.shared
        CarComponent.registerComponent()
        LaneFollowComponent.registerComponent()

        let visual = try await assets.entity(named: design.chassis.modelName)
        paint(visual, spec: design.paint)

        let car = ModelEntity()
        car.name = "car-\(design.name)"
        car.addChild(visual)

        // Center the visual on the physics origin; box from visual bounds ×0.9.
        let bounds = visual.visualBounds(relativeTo: car)
        visual.position -= bounds.center
        let size = bounds.extents * 0.8   // slim box: rail clearance > fidelity
        let shape = ShapeResource.generateBox(size: size)
        car.collision = CollisionComponent(shapes: [shape])
        car.physicsBody = PhysicsBodyComponent(
            massProperties: .init(shape: shape, mass: design.chassis.mass),
            material: .generate(staticFriction: design.tires.staticFriction,
                                dynamicFriction: design.tires.dynamicFriction,
                                restitution: design.tires.restitution),
            mode: .dynamic)

        car.components.set(PhysicsMotionComponent())
        car.components.set(CarComponent(playerID: playerID, design: design, livesLeft: lives))
        car.components.set(LaneFollowComponent(waypoints: lane))
        return car
    }

    /// Tints every material in the model with the paint color/finish.
    static func paint(_ entity: Entity, spec: PaintSpec) {
        let color = platformColor(hex: spec.colorHex)
        for part in entity.descendantsAndSelf() {
            guard var model = part.components[ModelComponent.self] else { continue }
            model.materials = model.materials.map { _ in
                var m = PhysicallyBasedMaterial()
                m.baseColor = .init(tint: color)
                switch spec.finish {
                case .metallic:
                    m.metallic = 0.9
                    m.roughness = 0.3
                case .glossy:
                    m.metallic = 0.1
                    m.roughness = 0.15
                case .matte:
                    m.metallic = 0.0
                    m.roughness = 0.9
                }
                return m
            }
            part.components.set(model)
        }
    }

    #if canImport(UIKit)
    private static func platformColor(hex: String) -> UIColor {
        var value: UInt64 = 0
        Scanner(string: hex.replacingOccurrences(of: "#", with: "")).scanHexInt64(&value)
        return UIColor(red: CGFloat((value >> 16) & 0xFF) / 255,
                       green: CGFloat((value >> 8) & 0xFF) / 255,
                       blue: CGFloat(value & 0xFF) / 255, alpha: 1)
    }
    #endif
}

extension Entity {
    func descendantsAndSelf() -> [Entity] {
        children.flatMap { $0.descendantsAndSelf() } + [self]
    }
}
