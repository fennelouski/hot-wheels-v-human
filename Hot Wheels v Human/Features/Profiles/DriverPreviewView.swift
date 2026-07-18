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
            spin = content.subscribe(to: SceneEvents.Update.self) { event in
                turntable.transform.rotation *= simd_quatf(
                    angle: Float(event.deltaTime) * 1.0, axis: [0, 1, 0])
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
        let signature = DriverPainter.stripes(for: driver).map(\.1)
            .joined(separator: "|") + "|\(driver.hair.rawValue)"
            + "|\(driver.hat?.rawValue ?? "-")|\(driver.hatColorHex ?? "-")"
            + "|\(driver.glasses?.rawValue ?? "-")"
        guard turntable.components[PreviewSignature.self]?.value != signature else { return }
        turntable.components.set(PreviewSignature(value: signature))

        if let human = turntable.children.first {
            await DriverPainter.apply(driver, to: human)
            return
        }
        guard let human = try? await AssetStore.shared.entity(named: "driver-idle") else { return }
        await DriverPainter.apply(driver, to: human)
        if let clip = human.availableAnimations.last {
            human.playAnimation(clip.repeat())
        }
        turntable.addChild(human)
    }
}
