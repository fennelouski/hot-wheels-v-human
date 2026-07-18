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

    static func make(paint: PaintSpec) async throws -> DriverPoser {
        let bust = try await AssetStore.shared.entity(named: "driver-idle")
        await CarFactory.paint(bust, spec: paint)
        let poser = DriverPoser(bust: bust)
        for (state, model) in [(ReactionState.idle, "driver-idle"),
                               (.boosted, "driver-boost"),
                               (.crashed, "driver-crash"),
                               (.celebrating, "driver-cheer")] {
            let source = state == .idle ? bust : try await AssetStore.shared.entity(named: model)
            if let clip = source.availableAnimations.last {
                poser.clips[state] = clip
            }
        }
        poser.apply(.idle)
        return poser
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
