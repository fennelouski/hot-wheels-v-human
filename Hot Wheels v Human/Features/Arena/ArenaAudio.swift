//
//  ArenaAudio.swift
//  Hot Wheels v Human
//
//  Race soundtrack: spatial engine loops on the cars (per-chassis sample,
//  playback rate = f(speed)), one-shot stingers on race moments, AI
//  catchphrases, music with countdown/finish ducking. Driven per frame
//  from ArenaView's scene subscription, ReactionFeed-style (stat diffs).
//

import Foundation
import RealityKit

@MainActor
final class ArenaAudio {

    private var lastPhase: RacePhase = .lobby
    private struct Prev {
        var crashes = 0
        var boostMeter: Float = 0
        var boosting = false
        var finished = false
        var out = false
    }
    private var prev: [UUID: Prev] = [:]
    private var engines: [UUID: AudioPlaybackController] = [:]
    private var engineResources: [String: AudioFileResource] = [:]
    private var tapeSnapped = false

    func tick(session: RaceSession) {
        let phase = session.phase
        if phase != lastPhase {
            switch phase {
            case .countdown:
                prev.removeAll()   // rematch: stale meters must not misfire boosts
                SoundBank.shared.duckMusic(seconds: 4)
                SoundBank.shared.play("race_countdown")
                SoundBank.shared.play("grid_rev_anticipation")
                playAIVoice(session: session, moment: "intro")
            case .racing:
                SoundBank.shared.play("start_gate_drop")
                SoundBank.shared.playMusic("race_intensity")
                startEngines(session: session)
            case .results:
                SoundBank.shared.duckMusic(seconds: 4)
                SoundBank.shared.play("finish_fanfare")
                SoundBank.shared.play("crowd_kids_cheer")
                stopEngines()
                announceResults(session: session)
            default:
                break
            }
            lastPhase = phase
        }

        for racer in session.racers {
            var last = prev[racer.id] ?? Prev()
            if racer.crashes > last.crashes {
                SoundBank.shared.play("car_crash_metal")
                SoundBank.shared.play(racer.isAI ? "crowd_gasp" : "driver_dizzy")
            }
            if racer.isOut && !last.out {
                SoundBank.shared.play("off_track_alarm")
                engines[racer.id]?.stop()
            }
            if racer.boosting && !last.boosting {
                SoundBank.shared.play("speed_boost_fire")
                if let key = AIRoster.voiceKey(for: racer.design) {
                    SoundBank.shared.play("voice_\(key)_boost")
                } else {
                    SoundBank.shared.play("driver_woohoo")
                }
            } else if last.boostMeter < 1 && racer.boostMeter >= 1 && !racer.isAI {
                SoundBank.shared.play("boost_ready_chime")
            }
            if racer.finishTime != nil && !last.finished {
                engines[racer.id]?.stop()
                if !tapeSnapped {
                    tapeSnapped = true
                    SoundBank.shared.play("finish_tape_snap")
                }
            }

            // Engine pitch follows speed (clamped range per Audio/README).
            if let engine = engines[racer.id],
               let chassisTop = RaceTuning.maxSpeed[racer.design.chassis] {
                let unit = Double(min(max(racer.speed / chassisTop, 0), 1))
                let range = RaceTuning.enginePitchRange
                engine.speed = range.lowerBound + (range.upperBound - range.lowerBound) * unit
            }

            last.crashes = racer.crashes
            last.boostMeter = racer.boostMeter
            last.boosting = racer.boosting
            last.finished = racer.finishTime != nil
            last.out = racer.isOut
            prev[racer.id] = last
        }
    }

    private func playAIVoice(session: RaceSession, moment: String) {
        for racer in session.racers {
            if let key = AIRoster.voiceKey(for: racer.design) {
                SoundBank.shared.play("voice_\(key)_\(moment)")
            }
        }
    }

    /// AI won → its win line + a kind kazoo for the human; AI lost → its
    /// gracious lose line. Humans-only races just keep the fanfare.
    private func announceResults(session: RaceSession) {
        let winner = session.racers
            .filter { $0.finishTime != nil }
            .min { $0.finishTime! < $1.finishTime! }
        guard let ai = session.racers.first(where: { $0.isAI }),
              let key = AIRoster.voiceKey(for: ai.design) else { return }
        if winner?.id == ai.id {
            SoundBank.shared.play("voice_\(key)_win")
            SoundBank.shared.play("nice_try_kazoo")
        } else {
            SoundBank.shared.play("voice_\(key)_lose")
        }
    }

    private func startEngines(session: RaceSession) {
        tapeSnapped = false
        Task { @MainActor in
            for racer in session.racers {
                guard let car = racer.entity, engines[racer.id] == nil,
                      let sample = RaceTuning.engineLoopName[racer.design.chassis] else { continue }
                if engineResources[sample] == nil {
                    engineResources[sample] = try? await AudioFileResource(
                        named: sample + ".wav",
                        configuration: .init(shouldLoop: true))
                }
                guard let resource = engineResources[sample] else { continue }
                car.spatialAudio = SpatialAudioComponent(gain: RaceTuning.engineGain)
                let controller = car.prepareAudio(resource)
                controller.play()
                engines[racer.id] = controller
            }
        }
    }

    private func stopEngines() {
        for controller in engines.values { controller.stop() }
        engines.removeAll()
    }
}
