//
//  DriverPoser.swift
//  Hot Wheels v Human
//
//  Plays the right clip for a reaction state, crossfaded, on the roster
//  character who is actually driving — the PiP used to show a fixed
//  Quaternius bust, so the face in the circle was a different person from
//  the human in the car.
//
//  Clips live in separate USDZs because Blender's USD exporter bakes the
//  timeline rather than glTF's named clips (Graphics/README, "Animation").
//  All twelve Kenney Mini characters share ONE skeleton — same joint names,
//  same hierarchy, and byte-identical keyframes per clip — so the three
//  reaction clips are converted ONCE (`reaction-boost/-crash/-cheer`) and
//  retarget onto whoever is driving. Twelve characters × three reactions
//  would have been 36 rigged USDZs for identical animation data.
//

import Foundation
import RealityKit

@MainActor
final class DriverPoser {

    /// Which Kenney clip each reaction state animates, as one list so the
    /// bundle check in CharacterModelTests reads the same names the poser
    /// loads — a typo'd asset otherwise just leaves that reaction silently
    /// playing the drive pose. States not in here (steerLeft/-Right, braced)
    /// deliberately reuse the base pose.
    ///   boosted     ← `emote-yes`, a sharp nod: "yes, GO"
    ///   crashed     ← `die`, arms flailing, the rig folding up
    ///   celebrating ← `attack-melee-right`, read as a fist pump
    ///
    /// Clips are picked on what moves ABOVE THE WAIST, because the cockpit
    /// crop is head-and-shoulders. Measured peak joint swing decided it:
    /// Kenney's `jump` is a 21° leg tuck with 5° of arm — the obvious name
    /// for a celebration, and completely invisible in this framing — while
    /// `attack-melee-right` swings an arm 164° with 61° of torso and head.
    /// Nothing in the clip reads as an attack at PiP size; it reads as a
    /// kid throwing a fist in the air.
    static let clipAssets: [ReactionState: String] = [
        .boosted: "reaction-boost",
        .crashed: "reaction-crash",
        .celebrating: "reaction-cheer",
    ]

    /// The visible driver entity — caller adds this to the scene.
    let bust: Entity
    /// The PiP camera. Lives here, not in the view, because the framing it
    /// chases is per-rig mutable state: parked in SwiftUI `@State` and
    /// written from a RealityView update closure, the chase read its own
    /// stale value half the time and never converged — the camera would
    /// frame the driver's face, then sag to their waist a second later.
    let camera = PerspectiveCamera()
    private var clips: [ReactionState: AnimationResource] = [:]
    private var current: ReactionState?
    private var rigHeight: Float?
    private var framedHead: SIMD3<Float>?
    /// How the loaded rig sits before any framing nudge. `applyFraming`
    /// offsets/multiplies from these, so scale 1 + lift 0 leaves the rig
    /// exactly as authored — which matters because the roster USDZs carry
    /// their own transform (the `scale_rig` node, ×10.73, see HeadPinSystem).
    /// Assigning an absolute scale instead of multiplying this one shrank
    /// the driver by that factor and emptied the cockpit.
    private let restingY: Float
    private let restingScale: SIMD3<Float>

    private init(bust: Entity) {
        self.bust = bust
        self.restingY = bust.position.y
        self.restingScale = bust.scale
        // Bind-pose framing; `frameOnHead` corrects it on the first update.
        let head = RaceTuning.driverSourceHeight * RaceTuning.driverHeadHeightRatio
        camera.look(at: [0, head, 0],
                    from: [0, head - RaceTuning.driverSourceHeight * RaceTuning.cockpitCameraDropRatio,
                           RaceTuning.driverSourceHeight * RaceTuning.cockpitCameraDistanceRatio],
                    relativeTo: nil)
    }

    /// Size and place the driver in the circle. This — not the camera — is
    /// what actually changes how big the driver reads, because the PiP's
    /// RealityView ignores the scene camera (see `frameOnHead`).
    ///
    /// Scale is about the entity origin, which sits at the rig's FEET, so
    /// shrinking alone drops the head by the same fraction and the PiP ends
    /// up staring at an empty cockpit. `lift` puts it back.
    ///
    /// Lift is a NUDGE from wherever the loaded rig naturally sits, not an
    /// absolute Y — the roster USDZs don't all place their root at zero, and
    /// forcing one emptied the cockpit outright. So lift 0 always means
    /// "untouched", which is what makes it safe to drag a slider from.
    func applyFraming(scale: Float, lift: Float) {
        bust.scale = restingScale * scale
        bust.position.y = restingY + lift
    }

    /// KNOWN DEAD as of 2026-07-20 — do not tune against it, and do not
    /// trust its constants. The PiP's `RealityView` renders with its own
    /// automatic camera and ignores the `PerspectiveCamera` this class adds
    /// to the scene, so nothing below reaches the screen. Two independent
    /// proofs: `cockpitCameraDistanceRatio` was taken from 1.5 to 6.0 (a 4×
    /// change in camera distance) with byte-identical framing in the
    /// `--reaction-cam` bench; and a one-shot file dump from this function
    /// never wrote, i.e. it is never called at all — the `SceneEvents.Update`
    /// subscription in ReactionCamView does not survive being stored in
    /// SwiftUI `@State` from inside the RealityView build closure.
    ///
    /// The lever that DOES work is scaling the bust — see `make`. Either fix
    /// the subscription and find out why the camera is ignored, or delete
    /// this function, the `camera`, `PoserBox`, and the four cockpitCamera*
    /// constants outright. Left in place rather than half-removed because
    /// deleting it is a bigger change than this session could verify.
    ///
    /// Keep the driver's head in the same spot in the circle, whoever they
    /// are and whatever they're doing.
    ///
    /// The reaction clips (boost push-back, crash facepalm, cheer jump)
    /// translate the rig's ROOT, so a camera aimed at a fixed height watched
    /// the driver walk out of frame — the PiP filled with a shirt, then a
    /// pair of hips. Body types rescale the rig on top of that, so two cars
    /// framed two different crops of two differently-sized people. Aiming at
    /// the posed Head joint (the one the hats already ride) fixes both at
    /// the source, and keeps working if the bust ever moves to the roster
    /// meshes.
    func frameOnHead() {
        let posed = HeadPinSystem.headPosition(of: bust, relativeTo: nil)
        // How big this rig is, in WORLD units — the only measure that means
        // anything here. The roster USDZs wrap their mesh in a `scale_rig`
        // node (×10.73, see HeadPinSystem), so rig-local numbers and the
        // Quaternius-era `driverSourceHeight` are both off by an order of
        // magnitude, and a camera distance derived from either parks the
        // lens in the driver's face. Measured on a render frame, never at
        // build time: called that early it races the rig's load and comes
        // back zero.
        if rigHeight == nil {
            let measured = bust.visualBounds(relativeTo: nil).extents.y
            if measured > 0 { rigHeight = measured }
        }
        let height = rigHeight ?? RaceTuning.driverSourceHeight
        // The joint lookup fails for a frame or two whenever a clip
        // crossfades (the pose arrays go briefly inconsistent). Hold the last
        // good framing through that: the bind-pose guess is a WORLD point and
        // the reaction clips translate the root clean away from it, so
        // falling back to it is what dropped the camera into the driver's
        // hips a second after it had framed their face perfectly well.
        let head = posed ?? framedHead ?? SIMD3(0, height * RaceTuning.driverHeadHeightRatio, 0)
        // Chase rather than snap: a crash clip moves the skull fast enough
        // that hard-tracking reads as camera shake.
        let aim = framedHead.map { $0 + (head - $0) * RaceTuning.cockpitHeadTrackBlend } ?? head
        framedHead = aim
        camera.look(at: aim,
                    from: aim + SIMD3(0, -height * RaceTuning.cockpitCameraDropRatio,
                                      height * RaceTuning.cockpitCameraDistanceRatio),
                    relativeTo: nil)
    }

    /// Base pose is IDLE, not the cockpit's DRIVE pose, for two reasons that
    /// only showed up on screen:
    ///
    /// 1. Every reaction clip is a STANDING animation (`die`, `emote-yes`,
    ///    `attack-melee-right` — the pack has no seated reactions), so a
    ///    seated base snapped the driver bolt upright on every boost and
    ///    back down again after.
    /// 2. `frameOnHead` used to size the rig as `head.y /
    ///    driverHeadHeightRatio`, and that ratio measures a STANDING rig.
    ///    Fed a seated head it under-read the rig by roughly a third and
    ///    parked the camera inside the driver's chest. It now measures the
    ///    bust's world-space visual bounds instead, so this reason no longer
    ///    binds — but reason 1 still does, so the base pose stays `idle`.
    ///
    /// Nothing is lost: the drive pose's one advantage (arms out on a wheel)
    /// sits below frame anyway, and `SteeringWheelView` draws the wheel in
    /// front regardless. `idle` also actually breathes — `drive` is a single
    /// static keyframe.
    static func make(profile: DriverProfile) async throws -> DriverPoser {
        let bust = try await AssetStore.shared.entity(named: profile.modelName(pose: .idle))
        // Roster characters are pre-painted colormaps — the stripe palette
        // exists only for the blank Quaternius mesh, and applying it here
        // would erase exactly what makes each of the twelve a different
        // person. `apply` still fits the wardrobe.
        await DriverPainter.apply(profile, to: bust)
        let poser = DriverPoser(bust: bust)
        poser.clips[.idle] = bust.availableAnimations.last
        poser.apply(.idle)
        // Deliberately NOT framed here: at the shipped defaults framing is a
        // no-op, and leaving the loaded rig untouched keeps the normal PiP
        // exactly as it renders without this feature. The tuner drives
        // `applyFraming` from the view once a slider moves.
        // Hand the bust back on the drive pose alone and stream the event
        // clips in behind it. Awaiting all the rigged USDZs first (they load
        // serially on the main actor) left the PiP an empty circle for ~14s on
        // a cold launch — long enough that the character editor looked broken.
        // `apply` already falls back to idle for a clip that isn't in yet, so
        // arriving early only costs a plain-faced boost for a moment.
        Task { await poser.loadEventClips() }
        return poser
    }

    private func loadEventClips() async {
        for (state, model) in Self.clipAssets {
            guard let source = try? await AssetStore.shared.entity(named: model),
                  let clip = source.availableAnimations.last else { continue }
            clips[state] = clip
            // Already stuck on this state's idle stand-in? Upgrade in place.
            if current == state {
                current = nil
                apply(state)
            }
        }
    }

    /// Steering/braced reuse the base drive clip — the bust leans with the
    /// live yaw rate and the face decal carries the rest.
    func apply(_ state: ReactionState) {
        guard state != current else { return }
        current = state
        let key: ReactionState = clips.keys.contains(state) ? state : .idle
        guard let clip = clips[key] else { return }
        bust.playAnimation(clip.repeat(), transitionDuration: 0.15, startsPaused: false)
    }
}
