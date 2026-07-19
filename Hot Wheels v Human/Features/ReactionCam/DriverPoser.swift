//
//  DriverPoser.swift
//  Hot Wheels v Human
//
//  Plays the right Quaternius clip for a reaction state, crossfaded.
//  Clips live in separate USDZs (driver-idle/-boost/-crash/-cheer,
//  converted by tools/convert_driver_rig.py); the skeletons match, so
//  any clip plays on the one visible bust.
//

import RealityKit

@MainActor
final class DriverPoser {

    /// The visible driver entity — caller adds this to the scene.
    let bust: Entity
    private var clips: [ReactionState: AnimationResource] = [:]
    private var current: ReactionState?

    private init(bust: Entity) {
        self.bust = bust
    }

    static func make(profile: DriverProfile) async throws -> DriverPoser {
        let bust = try await AssetStore.shared.entity(named: "driver-idle")
        await DriverPainter.apply(profile, to: bust)
        let poser = DriverPoser(bust: bust)
        poser.clips[.idle] = bust.availableAnimations.last
        poser.apply(.idle)
        // Hand the bust back on the idle rig alone and stream the event clips
        // in behind it. Awaiting all four rigged USDZs first (they load
        // serially on the main actor) left the PiP an empty circle for ~14s on
        // a cold launch — long enough that the character editor looked broken.
        // `apply` already falls back to idle for a clip that isn't in yet, so
        // arriving early only costs a plain-faced boost for a moment.
        Task { await poser.loadEventClips() }
        return poser
    }

    private func loadEventClips() async {
        for (state, model) in [(ReactionState.boosted, "driver-boost"),
                               (.crashed, "driver-crash"),
                               (.celebrating, "driver-cheer")] {
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

    /// Steering/braced reuse the idle clip — the face decal carries those.
    func apply(_ state: ReactionState) {
        guard state != current else { return }
        current = state
        let key: ReactionState = clips.keys.contains(state) ? state : .idle
        guard let clip = clips[key] else { return }
        bust.playAnimation(clip.repeat(), transitionDuration: 0.15, startsPaused: false)
    }
}
