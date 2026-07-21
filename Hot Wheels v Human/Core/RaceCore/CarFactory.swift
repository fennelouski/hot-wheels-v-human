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
#elseif canImport(AppKit)
import AppKit
#endif

/// Identity + race state carried by every car entity.
struct CarComponent: Component {
    let playerID: UUID
    let design: CarDesign
    var livesLeft: Int
    /// 0…`RaceTuning.boostMaxCharge`; 1 = armed, above 1 = overcharged.
    var boostMeter: Float = 0
    /// Is the boost currently burning? (Started by `RaceSession.requestBoost`,
    /// run down by `DriveSystem.stepBoost`.)
    var boosting: Bool = false
    /// How long the current burn has run — drives the thrust ramp.
    var boostSeconds: Float = 0
    /// Counts down from `RaceTuning.boostHoldGrace` on every boost packet;
    /// hits zero shortly after the kid lifts their finger.
    var boostHoldGrace: Float = 0
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
    /// Seconds spent beyond `RaceTuning.offSplineCutoff`. Tells a jump
    /// (brief) apart from a fling (sustained) — the track only reels a car
    /// back once this passes `RaceTuning.laneRecoveryGrace`. (Chaos mode only.)
    var offLaneSeconds: Float = 0
    /// Wheel-bottom-to-origin height (plus the bed's own offset from the
    /// lane line), set by CarFactory from the visual bounds — the rail
    /// follower floats the car this far above the lane along the track's up
    /// vector, so the tyres sit ON the drawn surface.
    var rideHeight: Float = 0
}

/// Which lane spline the car follows and how far along it is.
struct LaneFollowComponent: Component {
    var waypoints: [SIMD3<Float>]
    var nextIndex: Int = 0
    var lapsDone: Int = 0
    /// Waypoint index ranges covering loop pieces — the loop motor
    /// (RaceTuning.loopCarrySpeed) engages inside these.
    var loopRanges: [ClosedRange<Int>] = []
    /// Unit "left" vector per waypoint (LaneSplines.laterals) — with the
    /// tangent this frames the track so loops roll the car correctly.
    var laterals: [SIMD3<Float>] = []

    // Rail-mode state (RaceTuning.railPinned) — ignored by chaos physics.
    /// Progress within the current segment [waypoint nextIndex−1, nextIndex], 0…1.
    var fraction: Float = 0
    /// Scalar along-track speed, m/s. THE authoritative speed in rail mode.
    var speed: Float = 0
    /// World-space y of the ground contact point; tracks the bed while
    /// grounded, integrates gravity while airborne.
    var height: Float = 0
    var verticalVelocity: Float = 0
    var airborne: Bool = false
    /// Smoothed lateral drift offset, metres (− = sliding right).
    var drift: Float = 0
}

@MainActor
enum CarFactory {

    static func makeCar(design: CarDesign, playerID: UUID, lane: [SIMD3<Float>],
                        lives: Int, loopRanges: [ClosedRange<Int>] = [],
                        laterals: [SIMD3<Float>] = [],
                        assets: AssetStore? = nil) async throws -> ModelEntity {
        let assets = assets ?? AssetStore.shared
        CarComponent.registerComponent()
        LaneFollowComponent.registerComponent()

        let visual = try await assets.entity(named: design.modelName)
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
        // Rail mode: kinematic — DriveSystem places the car on the spline
        // directly, so the solver can never fling it; the body still shoves
        // debris around. Chaos mode: the original force-driven dynamic body.
        car.physicsBody = PhysicsBodyComponent(
            massProperties: .init(shape: shape, mass: design.chassis.mass),
            material: .generate(staticFriction: design.tires.staticFriction,
                                dynamicFriction: design.tires.dynamicFriction,
                                restitution: design.tires.restitution),
            mode: RaceTuning.railPinned ? .kinematic : .dynamic)

        if !RaceTuning.railPinned {
            // Velocity-integrated motion is chaos-mode only: on a kinematic
            // body PhysicsMotionComponent would fight the direct placement.
            car.components.set(PhysicsMotionComponent())
        }
        car.components.set(CarComponent(playerID: playerID, design: design, livesLeft: lives,
                                        rideHeight: rideHeight(visualHeight: bounds.extents.y)))
        car.components.set(LaneFollowComponent(waypoints: lane, loopRanges: loopRanges,
                                               laterals: laterals))

        // The little human, in the roster's DRIVE pose — hands out on the
        // wheel. The old standing rig had to be sunk hip-deep with its legs
        // hidden inside the chassis to read as seated; a real sitting pose
        // retires that trick.
        let profile = design.driver ?? DriverProfile.presets[0]
        if let driver = try? await assets.entity(named: profile.modelName(pose: .drive)) {
            await DriverPainter.apply(profile, to: driver)
            let carHeight = bounds.extents.y
            let scale = carHeight * RaceTuning.driverHeightRatio / RaceTuning.driverSourceHeight
            driver.scale = SIMD3(repeating: scale) * (profile.bodyType ?? .man).scale
            driver.position = [0, carHeight * (0.5 - RaceTuning.driverSinkRatio), 0]
            car.addChild(driver)
        }
        return car
    }

    /// How far above a lane waypoint a car's origin belongs, so its WHEELS
    /// rest on the drawn bed. The visual is centred on the origin (above),
    /// so its lowest point — the tyres — is half its height down; the bed
    /// itself sits `bedSurfaceHeight` over the lane line.
    ///
    /// This used to be 0.4 × height measured against the raw lane: the
    /// COLLISION box's bottom, which is deliberately slim and stops well
    /// short of the tyres. Every car therefore rode 0.1 × its height + 13 mm
    /// low — wheels buried on the flat, and poking clean through the ring on
    /// the loop, where "under the bed" points at the camera.
    nonisolated static func rideHeight(visualHeight: Float) -> Float {
        visualHeight * 0.5 + RaceTuning.bedSurfaceHeight
    }

    /// Full visual treatment: per-part paint + the paint-shell overlay
    /// (livery/stickers/drawing, plus the glitter layer for sparkle paint).
    /// Used by racing and the turntable preview.
    static func applyCustomization(to visual: Entity, design: CarDesign) async {
        await paint(visual, spec: design.paint, partColors: design.partColors,
                    wheelFinish: design.wheelFinish)
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
                      partColors: [String: String]? = nil,
                      wheelFinish: PaintFinish? = nil) async {
        for part in entity.descendantsAndSelf() {
            guard var model = part.components[ModelComponent.self],
                  part.name != "paint-shell" else { continue }   // overlay keeps its texture
            let slot = CarPaintSlot.slot(forPartName: part.name)
            let color = platformColor(hex: partColors?[slot] ?? spec.colorHex)
            // Wheels default to matte rubber (nil), but the kid can now pick a
            // finish for them too — chrome, gloss, sparkle. Body uses paint.finish.
            let finish = slot == CarPaintSlot.wheels ? (wheelFinish ?? .matte) : spec.finish
            model.materials = model.materials.map { _ in
                var m = PhysicallyBasedMaterial()
                m.baseColor = .init(tint: color)
                applyFinish(finish, to: &m)
                return m
            }
            part.components.set(model)
        }
    }

    /// Maps a paint finish to metallic/roughness. Sparkle is just the base
    /// coat here — its glitter grain renders on the body paint shell (the
    /// Kenney atlas UVs are ~1D and only streak), so sparkle wheels read as
    /// chrome, which still delights.
    private static func applyFinish(_ finish: PaintFinish,
                                    to m: inout PhysicallyBasedMaterial) {
        switch finish {
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
            m.metallic = 1.0
            m.roughness = 0.3
        }
    }


    private static func platformColor(hex: String) -> PlatformColor {
        var value: UInt64 = 0
        Scanner(string: hex.replacingOccurrences(of: "#", with: "")).scanHexInt64(&value)
        return PlatformColor(red: CGFloat((value >> 16) & 0xFF) / 255,
                             green: CGFloat((value >> 8) & 0xFF) / 255,
                             blue: CGFloat(value & 0xFF) / 255, alpha: 1)
    }
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
