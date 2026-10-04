//
//  DriverPreviewView.swift
//  Hot Wheels v Human
//
//  Live 3D turntable of the character being edited — painted by the same
//  DriverPainter that races, so what you see is what races.
//

import SwiftUI
import RealityKit

/// Grid-safe driver avatar: the character's 3D look WITHOUT a live scene.
///
/// A live `RealityView` per tile crashes a device — RealityKit can't hold
/// several simultaneous scenes inside a recycling `LazyVGrid`/`ScrollView`
/// (OPEN-THREADS "3D grid avatars"). So instead of a live scene, each tile
/// shows a still IMAGE rendered once off-screen by `DriverThumbnailStore`,
/// which draws one character at a time through a single transient scene — the
/// count on screen is always zero. The cheap 2D `DriverFaceBadge` shows until
/// (and if) the snapshot arrives, so a failed/slow render just degrades to 2D
/// and never crashes.
struct DriverGridAvatar: View {
    let driver: DriverProfile

    #if os(iOS)
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                DriverFaceBadge(driver: driver)
            }
        }
        .task(id: DriverPainter.appearanceSignature(for: driver)) {
            if let hit = DriverThumbnailStore.shared.cached(driver) {
                image = hit
            } else {
                image = await DriverThumbnailStore.shared.thumbnail(for: driver)
            }
        }
    }
    #else
    // tvOS has no ARView snapshot API. Its grid uses the painted badge;
    // opening a racer shows the full, editable RealityKit preview.
    var body: some View { DriverFaceBadge(driver: driver) }
    #endif
}

struct DriverPreviewView: View {
    let driver: DriverProfile
    /// Remote-owned camera state; nil preserves the iPad gesture camera.
    var remoteOrbit: TurntableOrbit? = nil

    @State private var spin: EventSubscription?
    @State private var refs = OrbitRefs()

    /// Sway limit either side of front, radians (~34°) — enough to read the
    /// profile and the side of a hat, never enough to hide the face.
    private static let swayAngle: Float = 0.6
    /// Radians/sec of the sine driving it: one slow lean each way, calm
    /// enough that a kid lining up face paint isn't chasing a moving target.
    private static let swayRate: Float = 0.7

    var body: some View {
        // Apple TV uses explicit remote camera controls; iPad keeps gestures.
        #if os(tvOS)
        realityView
        #else
        realityView
            .simultaneousGesture(DragGesture(minimumDistance: 8)
                .onChanged { refs.orbit.drag($0.translation, ended: false) }
                .onEnded { refs.orbit.drag($0.translation, ended: true) })
            .simultaneousGesture(MagnifyGesture()
                .onChanged { refs.orbit.pinch($0.magnification, ended: false) }
                .onEnded { refs.orbit.pinch($0.magnification, ended: true) })
        #endif
    }

    private var realityView: some View {
        RealityView { content in
            content.camera = .virtual
            let turntable = Entity()
            turntable.name = "turntable"
            content.add(turntable)

            // Frame the whole rig, facing its front (+Z). Pulled back from
            // 1.05: the roster characters stand taller and chunkier than the
            // Quaternius rig this framing was set for, and overflowed the
            // preview — head and feet cropped off. Then pulled back again by
            // 1/0.7 for a character ~30% smaller in frame: the whole offset
            // from the target is scaled, not just the distance, so the camera
            // keeps its angle and the figure only shrinks.
            let height = RaceTuning.driverSourceHeight
            let camera = PerspectiveCamera()
            refs.frame(camera, target: [0, height * 0.5, 0],
                       from: [0, height * 0.67, height * 2.21])
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
            //
            // Until a kid grabs them, that is — then they hold still where
            // they were caught and the camera does the moving, so the back
            // of the hair is finally something you can go and look at.
            var elapsed: Float = 0
            spin = content.subscribe(to: SceneEvents.Update.self) { event in
                guard GameEffectsPolicy.shared.motionEnabled else {
                    turntable.stopAllAnimations(recursive: true)
                    return refs.apply()
                }
                guard !refs.orbit.grabbed else { return refs.apply() }
                elapsed += Float(event.deltaTime)
                let angle = sin(elapsed * Self.swayRate) * Self.swayAngle
                turntable.transform.rotation = simd_quatf(angle: angle, axis: [0, 1, 0])
            }
        } update: { content in
            if let remoteOrbit { refs.orbit = remoteOrbit }
            guard let turntable = content.entities.first(where: { $0.name == "turntable" }) else { return }
            Task { @MainActor in
                await Self.rebuild(turntable, driver: driver)
            }
        }
    }

    /// Loads, paints, scales and idle-poses the driver into `turntable`.
    /// Internal (not private) so the off-screen thumbnail renderer builds the
    /// exact same rig — one code path, so a snapshot can't drift from the
    /// live turntable.
    @MainActor
    static func rebuild(_ turntable: Entity, driver: DriverProfile) async {
        let signature = DriverPainter.appearanceSignature(for: driver) + (GameEffectsPolicy.shared.motionEnabled ? ":moving" : ":still")
        guard turntable.components[PreviewSignature.self]?.value != signature else { return }
        turntable.components.set(PreviewSignature(value: signature))

        // Reuse the loaded rig ONLY while it's still the right person. Body
        // type now picks a different mesh, not just a rescale, so tapping
        // Woman after Man has to swap the model — the reuse path repainted
        // and rescaled the old one and the character never changed.
        let wanted = driver.modelName(pose: .idle)
        if let human = turntable.children.first {
            if human.name == wanted {
                await DriverPainter.apply(driver, to: human)
                human.scale = (driver.bodyType ?? .man).scale
                if !GameEffectsPolicy.shared.motionEnabled { human.stopAllAnimations(recursive: true) }
                else if let idle = human.availableAnimations.first(where: { ($0.name ?? "").localizedCaseInsensitiveContains("idle") })
                    ?? human.availableAnimations.first { human.playAnimation(idle.repeat()) }
                return
            }
            human.removeFromParent()
        }
        guard let human = try? await AssetStore.shared.entity(named: wanted) else { return }
        human.name = wanted
        await DriverPainter.apply(driver, to: human)
        human.scale = (driver.bodyType ?? .man).scale
        // Prefer the IDLE clip by name. `.last` picked whatever happened to
        // be last in the file — the Quaternius rig ships idle/run/jump/death,
        // so the editor could be posing your character mid-sprint (or worse,
        // mid-death) while you try to fit a hat to its head.
        let clips = human.availableAnimations
        if GameEffectsPolicy.shared.motionEnabled, let idle = clips.first(where: { ($0.name ?? "").localizedCaseInsensitiveContains("idle") })
            ?? clips.first {
            human.playAnimation(idle.repeat())
        }
        turntable.addChild(human)
    }
}
