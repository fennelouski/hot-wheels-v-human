//
//  CarFactory.swift
//  Hot Wheels v Human
//
//  CarDesign → physical car entity. Box collision (cheaper + more stable
//  than mesh), physics material from tires, paint by tinting the Kenney
//  flat-color materials.
//

import CoreGraphics
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
    /// Anchor for no-net-progress stuck detection (RaceTuning.stuckRadius).
    var stuckAnchor: SIMD3<Float>? = nil
    var flippedSeconds: Float = 0
    var finished: Bool = false
    /// DriveSystem applies no forces while this counts down. The first
    /// frame after GO stalls for seconds in the Simulator (physics world
    /// build + shader warmup) and RealityKit integrates forces over that
    /// whole spiked dt — 16 N × 2 s ≈ a 20 m/s catapult off the start line
    /// (sim drills traced it). Sitting out a few frames burns the spike.
    var warmupFrames: Int = 3
}

/// Which lane spline the car follows and how far along it is.
struct LaneFollowComponent: Component {
    var waypoints: [SIMD3<Float>]
    var nextIndex: Int = 0
    var lapsDone: Int = 0
    /// Waypoint index ranges covering loop pieces — the loop motor
    /// (RaceTuning.loopCarrySpeed) engages inside these.
    var loopRanges: [ClosedRange<Int>] = []
}

@MainActor
enum CarFactory {

    static func makeCar(design: CarDesign, playerID: UUID, lane: [SIMD3<Float>],
                        lives: Int, loopRanges: [ClosedRange<Int>] = [],
                        assets: AssetStore? = nil) async throws -> ModelEntity {
        let assets = assets ?? AssetStore.shared
        CarComponent.registerComponent()
        LaneFollowComponent.registerComponent()

        let visual = try await assets.entity(named: design.modelOverride ?? design.chassis.modelName)
        await applyCustomization(to: visual, design: design)

        let car = ModelEntity()
        car.name = "car-\(design.name)"
        car.addChild(visual)

        // Center the visual on the physics origin; box from visual bounds ×0.9.
        let bounds = visual.visualBounds(relativeTo: car)
        visual.position -= bounds.center
        var size = bounds.extents * 0.8   // slim box: rail clearance > fidelity
        // Low-profile box: cars only touch the track with their underside,
        // and full visual height jams the monster truck against the loop
        // mouth (stopped dead at the same spot every sim drill). Half
        // height, bottom kept in place so ride height is unchanged.
        size.y = bounds.extents.y * 0.4
        let shape = ShapeResource.generateBox(size: size)
            .offsetBy(translation: [0, -bounds.extents.y * (0.8 - 0.4) / 2, 0])
        car.collision = CollisionComponent(shapes: [shape])
        car.physicsBody = PhysicsBodyComponent(
            massProperties: .init(shape: shape, mass: design.chassis.mass),
            material: .generate(staticFriction: design.tires.staticFriction,
                                dynamicFriction: design.tires.dynamicFriction,
                                restitution: design.tires.restitution),
            mode: .dynamic)

        car.components.set(PhysicsMotionComponent())
        car.components.set(CarComponent(playerID: playerID, design: design, livesLeft: lives))
        car.components.set(LaneFollowComponent(waypoints: lane, loopRanges: loopRanges))

        // The little human, riding hip-deep so the standing rig reads as
        // seated (legs hidden inside the chassis).
        if let driver = try? await assets.entity(named: "driver-idle") {
            await DriverPainter.apply(design.driver ?? DriverProfile.presets[0], to: driver)
            let carHeight = bounds.extents.y
            let scale = carHeight * RaceTuning.driverHeightRatio / RaceTuning.driverSourceHeight
            driver.scale = .init(repeating: scale)
            driver.position = [0, carHeight * (0.5 - RaceTuning.driverSinkRatio), 0]
            car.addChild(driver)
        }
        return car
    }

    /// Full visual treatment: per-part paint + the paint-shell overlay
    /// (livery/stickers/drawing, plus the glitter layer for sparkle paint).
    /// Used by racing and the turntable preview.
    static func applyCustomization(to visual: Entity, design: CarDesign) async {
        await paint(visual, spec: design.paint, partColors: design.partColors)
        // ponytail: overlay renders on the calling task — 1024² CGContext
        // is a few ms; move off-main only if the profiler ever blames it.
        // (A Task.detached hop here never resumed inside the RealityView
        // make closure and hung the whole rebuild.)
        let sparkle = design.paint.finish == .sparkle
        await PaintShell.apply(
            overlay: OverlayComposer.render(
                livery: design.livery,
                stickers: design.stickers,
                drawing: design.drawingPNG,
                bodyAspect: PaintShell.bodyAspect(of: visual),
                sparkleFillHex: sparkle
                    ? design.partColors?[CarPaintSlot.body] ?? design.paint.colorHex
                    : nil),
            sparkle: sparkle,
            to: visual)
    }

    /// Tints every material in the model with the paint color/finish.
    /// `partColors` overrides the base color per `CarPaintSlot` (mesh name).
    static func paint(_ entity: Entity, spec: PaintSpec,
                      partColors: [String: String]? = nil) async {
        for part in entity.descendantsAndSelf() {
            guard var model = part.components[ModelComponent.self],
                  part.name != "paint-shell" else { continue }   // overlay keeps its texture
            let slot = CarPaintSlot.slot(forPartName: part.name)
            let color = platformColor(hex: partColors?[slot] ?? spec.colorHex)
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
                case .sparkle:
                    // Base coat only — the glitter grain renders on the
                    // paint shell, whose computed UVs are actually 2D
                    // (the Kenney atlas UVs are ~1D and only make streaks).
                    m.metallic = 1.0
                    m.roughness = 0.3
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

extension ModelEntity {
    /// Height to add above a lane waypoint when placing a car so its
    /// collision box bottom (at −0.4 × visual height, see makeCar) clears
    /// the bed. A fixed +0.05 put the tall monster truck's box 1 cm INSIDE
    /// the bed mesh and the depenetration impulse catapulted it off the
    /// start line at ~25 m/s (sim drills, collision-event trace).
    var spawnLift: Float {
        // Small drop clearance: spawning intersecting ANY collision gets
        // the car depenetration-catapulted, so cars always land from
        // above. 2 cm is plenty now that beds are clean slabs — a 10 cm
        // drop tipped the top-heavy monster truck onto its side.
        visualBounds(relativeTo: self).extents.y * 0.4 + 0.02
    }
}
