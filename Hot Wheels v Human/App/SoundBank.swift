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

@MainActor
final class SoundBank {
    static let shared = SoundBank()

    private var oneShots: [String: AVAudioPlayer] = [:]
    private var music: AVAudioPlayer?
    private var duckedUntil = Date.distantPast
    private var variantLists: [String: [String]] = [:]
    private var lastVariant: [String: String] = [:]

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
        player.volume = RaceTuning.musicVolume
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
        music.setVolume(RaceTuning.musicVolume * RaceTuning.musicDuckFactor,
                        fadeDuration: 0.2)
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard let self, Date() >= self.duckedUntil else { return }
            self.music?.setVolume(RaceTuning.musicVolume, fadeDuration: 0.5)
        }
    }
}
