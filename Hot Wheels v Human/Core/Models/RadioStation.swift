//
//  RadioStation.swift
//  Hot Wheels v Human
//
//  The six presets on the driver's-seat radio (ArenaView's FPV dashboard).
//  Every station is one looping m4a in Resources/Audio, synthesized by
//  tools/generate_placeholder_music.py — see Audio/README.md.
//

import Foundation

enum RadioStation: String, CaseIterable, Codable, Sendable {
    case rock, jazz, pop, funk, smooth, chiptune

    /// Preset label. Short and shouty — it's read at 60 mph from the couch.
    var label: String {
        switch self {
        case .rock: "ROCK"
        case .jazz: "JAZZ"
        case .pop: "POP"
        case .funk: "FUNK"
        case .smooth: "SMOOTH"
        case .chiptune: "8-BIT"
        }
    }

    /// SF Symbol on the preset button, so a kid who can't read the label
    /// yet can still find their station (no emoji — house rule).
    var symbol: String {
        switch self {
        case .rock: "guitars.fill"
        case .jazz: "music.quarternote.3"
        case .pop: "music.mic"
        case .funk: "waveform"
        case .smooth: "pianokeys"
        case .chiptune: "gamecontroller.fill"
        }
    }

    /// Music file (m4a) in Resources/Audio. 8-BIT rides `race_intensity`,
    /// which is already a chiptune loop — no second copy of it.
    var track: String {
        self == .chiptune ? "race_intensity" : "radio_\(rawValue)"
    }
}
