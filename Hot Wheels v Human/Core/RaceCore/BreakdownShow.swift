//
//  BreakdownShow.swift
//  Hot Wheels v Human
//
//  The kid rule: losing is funny, not sad. Every finisher who didn't win
//  parks at the line and then falls apart — wheels ping off and the body
//  sags, or the car sputter-hops, poofs debris, and flops on its side.
//  Purely visual: finishers are already static, nothing here touches race
//  state or the wire format. Popped wheels are parented to the track, so
//  REMATCH's teardown sweeps them with everything else.
//

import Foundation
import RealityKit

@MainActor
enum BreakdownShow {

    enum Style: CaseIterable {
        case wheelsOff    // wheels pop one by one, body clunks onto the deck
        case sputterFlop  // coughing hops, a poof of debris, flops sideways
    }

    /// Style comes from the player ID, so a rematch gives the same car the
    /// same failure — it becomes "their thing".
    static func style(for playerID: UUID) -> Style {
        Style.allCases[Int(playerID.uuid.0) % Style.allCases.count]
    }

    static func play(on car: ModelEntity, style: Style) {
        Task { @MainActor in
            await sleep(RaceTuning.breakdownDelay)
            switch style {
            case .wheelsOff: await wheelsOff(car)
            case .sputterFlop: await sputterFlop(car)
            }
            SoundBank.shared.play("nice_try_kazoo")
        }
    }

    private static func sleep(_ seconds: Float) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    /// Wheels detach into small dynamic bodies (same wrapper the debris
    /// pool uses) and bounce away; the body drops onto the track bed.
    private static func wheelsOff(_ car: ModelEntity) async {
        guard let stage = car.parent else { return }
        let wheels = car.descendantsAndSelf().filter {
            CarPaintSlot.slot(forPartName: $0.name) == CarPaintSlot.wheels
        }
        for wheel in wheels {
            // World pose survives the reparent; translation moves to the
            // wrapper so physics acts on the wheel's own center.
            let position = wheel.position(relativeTo: nil)
            let rotation = wheel.orientation(relativeTo: nil)
            let scale = wheel.scale(relativeTo: nil)
            wheel.removeFromParent()
            wheel.transform = Transform(scale: scale, rotation: rotation)
            guard let body = ModelEntity.wrappingForPhysics(wheel) else { continue }
            body.position = position
            stage.addChild(body)
            body.applyLinearImpulse(
                SIMD3<Float>(Float.random(in: -1...1),
                             Float.random(in: 0.6...1.4),
                             Float.random(in: -1...1))
                    * Float.random(in: RaceTuning.breakdownWheelImpulse),
                relativeTo: nil)
            SoundBank.shared.play("tire_bounce")
            await sleep(RaceTuning.breakdownWheelStagger)
        }
        car.position.y -= RaceTuning.breakdownSag
        car.orientation *= simd_quatf(angle: RaceTuning.breakdownSagRoll, axis: [0, 0, 1])
        SoundBank.shared.play("car_crash_metal")
    }

    /// Engine-trouble hops on the ambient-motion driver, a debris cough
    /// midway, then the flop onto one side.
    private static func sputterFlop(_ car: ModelEntity) async {
        var motion = AmbientMotionComponent(bobAmplitude: RaceTuning.breakdownSputterAmplitude,
                                            bobRate: RaceTuning.breakdownSputterRate,
                                            swayAngle: 0.06,
                                            swayRate: RaceTuning.breakdownSputterRate)
        motion.baseY = car.position.y
        motion.baseOrientation = car.orientation
        car.components.set(motion)
        await sleep(RaceTuning.breakdownSputterSeconds / 2)
        DebrisPool.shared.explode(at: car.position(relativeTo: nil), in: car.parent)
        await sleep(RaceTuning.breakdownSputterSeconds / 2)
        car.components[AmbientMotionComponent.self] = nil
        car.position.y = motion.baseY
        car.orientation = motion.baseOrientation
            * simd_quatf(angle: RaceTuning.breakdownFlopRoll, axis: [0, 0, 1])
        SoundBank.shared.play("car_crash_metal")
    }
}
