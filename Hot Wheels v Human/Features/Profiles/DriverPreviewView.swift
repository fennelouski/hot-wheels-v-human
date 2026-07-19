//
//  DriverPreviewView.swift
//  Hot Wheels v Human
//
//  Live 3D turntable of the character being edited — painted by the same
//  DriverPainter that races, so what you see is what races.
//

import SwiftUI
import RealityKit

struct DriverPreviewView: View {
    let driver: DriverProfile

    @State private var spin: EventSubscription?

    /// Sway limit either side of front, radians (~34°) — enough to read the
    /// profile and the side of a hat, never enough to hide the face.
    private static let swayAngle: Float = 0.6
    /// Radians/sec of the sine driving it: one slow lean each way, calm
    /// enough that a kid lining up face paint isn't chasing a moving target.
    private static let swayRate: Float = 0.7

    var body: some View {
        RealityView { content in
            content.camera = .virtual
            let turntable = Entity()
            turntable.name = "turntable"
            content.add(turntable)

            // Frame the whole rig, facing its front (+Z).
            let height = RaceTuning.driverSourceHeight
            let camera = PerspectiveCamera()
            camera.look(at: [0, height * 0.55, 0],
                        from: [0, height * 0.6, height * 1.05], relativeTo: nil)
            content.add(camera)
            let light = DirectionalLight()
            light.light.intensity = 5000
            light.look(at: [0, height * 0.5, 0],
                       from: [height, height, height], relativeTo: nil)
            content.add(light)

            await Self.rebuild(turntable, driver: driver)
            // SWAY, don't spin. This is a face you're editing — glasses,
            // hair, face paint — and a full turntable spin has the character
            // showing you its back half the time, which is exactly when you
            // can't judge the change you just made. A gentle sway around the
            // front keeps the face toward the camera at all times while still
            // giving the figure volume and showing off the profile.
            var elapsed: Float = 0
            spin = content.subscribe(to: SceneEvents.Update.self) { event in
                elapsed += Float(event.deltaTime)
                let angle = sin(elapsed * Self.swayRate) * Self.swayAngle
                turntable.transform.rotation = simd_quatf(angle: angle, axis: [0, 1, 0])
            }
        } update: { content in
            guard let turntable = content.entities.first(where: { $0.name == "turntable" }) else { return }
            Task { @MainActor in
                await Self.rebuild(turntable, driver: driver)
            }
        }
    }

    @MainActor
    private static func rebuild(_ turntable: Entity, driver: DriverProfile) async {
        let signature = DriverPainter.appearanceSignature(for: driver)
        guard turntable.components[PreviewSignature.self]?.value != signature else { return }
        turntable.components.set(PreviewSignature(value: signature))

        if let human = turntable.children.first {
            await DriverPainter.apply(driver, to: human)
            human.scale = (driver.bodyType ?? .man).scale
            return
        }
        guard let human = try? await AssetStore.shared.entity(named: "driver-idle") else { return }
        await DriverPainter.apply(driver, to: human)
        human.scale = (driver.bodyType ?? .man).scale
        // Prefer the IDLE clip by name. `.last` picked whatever happened to
        // be last in the file — the Quaternius rig ships idle/run/jump/death,
        // so the editor could be posing your character mid-sprint (or worse,
        // mid-death) while you try to fit a hat to its head.
        let clips = human.availableAnimations
        if let idle = clips.first(where: { ($0.name ?? "").localizedCaseInsensitiveContains("idle") })
            ?? clips.first {
            human.playAnimation(idle.repeat())
        }
        turntable.addChild(human)
    }
}
