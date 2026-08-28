//
//  SoundBank.swift
//  Hot Wheels v Human
//
//  One-shot SFX + looping music with countdown/finish ducking (Audio/README).
//  Plain AVAudioPlayer — spatial car audio lives in ArenaAudio via RealityKit.
//  Sound names match Audio/SFX-SPEC.md; missing files fail silently (audio
//  must never crash the game).
//

import AVFoundation
#if os(iOS)
import UIKit
#endif

@MainActor
final class SoundBank {
    static let shared = SoundBank()

    private var oneShots: [String: AVAudioPlayer] = [:]
    private var music: AVAudioPlayer?
    private var duckedUntil = Date.distantPast
    private var variantLists: [String: [String]] = [:]
    private var lastVariant: [String: String] = [:]

    /// The dash volume knob, 0…1. Scales the music mix only — engines, SFX
    /// and the AI's voice keep their level, so turning the radio down leaves
    /// the race audible instead of muting it.
    var musicLevel: Float = 1 {
        didSet { music?.setVolume(mixVolume, fadeDuration: 0.15) }
    }

    private var mixVolume: Float { RaceTuning.musicVolume * musicLevel }

    /// Play a one-shot WAV from Resources/Audio (base name, no extension).
    /// High-frequency sounds have `_b`/`_c` siblings (SFX-SPEC variant
    /// convention) — picks randomly, never the same one back-to-back.
    func play(_ name: String) {
        let options = variants(of: name)
        guard var pick = options.randomElement() else { return }
        if options.count > 1, pick == lastVariant[name],
           let other = options.filter({ $0 != pick }).randomElement() {
            pick = other
        }
        lastVariant[name] = pick
        buzz(for: name)

        if let player = oneShots[pick] {
            player.currentTime = 0
            player.play()
            return
        }
        guard let url = Bundle.main.url(forResource: pick, withExtension: "wav"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return }
        oneShots[pick] = player
        player.play()
    }

    /// The matching haptic for a sound. Every UI moment in the app already
    /// routes through `play(_:)`, so the taps, snaps and refusals get their
    /// thump here rather than at thirty call sites — and a sound added later
    /// gets one for free by naming itself like its neighbours.
    ///
    /// iOS only: `UIFeedbackGenerator` doesn't exist on tvOS, and the TV has
    /// nothing to buzz. `#if os(iOS)`, not `canImport(UIKit)` — UIKit imports
    /// fine on tvOS and would break the TV build (CLAUDE.md).
    private func buzz(for name: String) {
        #if os(iOS)
        switch name {
        // Refusals: the wobble a kid hears when a piece won't go there.
        case "nope_wobble":
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        // Something landed and stuck: saved, finished, confirmed.
        case "confirm_sparkle", "track_save_stamp":
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        // Track pieces: a click going on, a softer pop coming off.
        case "track_snap_connect":
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        case "piece_delete_pop":
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        // Metal on metal — the biggest thump the phone has.
        case "car_crash_metal":
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        // Picking one of something: chips, swatches, tabs.
        case "ui_tap", "ui_back", "paint_spray", "shuffle_dice", "car_select_vroom":
            UISelectionFeedbackGenerator().selectionChanged()
        default:
            break
        }
        #endif
    }

    private func variants(of name: String) -> [String] {
        if let cached = variantLists[name] { return cached }
        var list: [String] = []
        for candidate in [name, name + "_b", name + "_c"]
        where Bundle.main.url(forResource: candidate, withExtension: "wav") != nil {
            list.append(candidate)
        }
        variantLists[name] = list
        return list
    }

    /// Start a looping music track (m4a); replaces whatever was playing.
    func playMusic(_ name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "m4a") else { return }
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
        music?.stop()
        music = player
        player.numberOfLoops = -1
        player.volume = mixVolume
        player.play()
    }

    func stopMusic() {
        music?.stop()
        music = nil
    }

    /// Duck music −8 dB for `seconds` (countdown, finish fanfare).
    func duckMusic(seconds: TimeInterval) {
        guard let music else { return }
        duckedUntil = Date(timeIntervalSinceNow: seconds)
        music.setVolume(mixVolume * RaceTuning.musicDuckFactor,
                        fadeDuration: 0.2)
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard let self, Date() >= self.duckedUntil else { return }
            self.music?.setVolume(self.mixVolume, fadeDuration: 0.5)
        }
    }
}
