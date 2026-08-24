//
//  RadioStationTests.swift
//  Hot Wheels v HumanTests
//
//  The cockpit radio's six presets. Both failure modes here are silent —
//  a missing m4a plays nothing at all (SoundBank swallows it so audio can
//  never crash the game) and a mistyped SF Symbol draws an empty button —
//  so the presets get checked here instead of by ear.
//

import Foundation
import Testing
#if canImport(UIKit)
import UIKit
#endif
@testable import Hot_Wheels_v_Human

struct RadioStationTests {

    @Test func everyStationHasABundledTrack() {
        for station in RadioStation.allCases {
            #expect(Bundle.main.url(forResource: station.track, withExtension: "m4a") != nil,
                    "\(station.label) has no \(station.track).m4a in Resources/Audio")
        }
    }

    #if canImport(UIKit)
    @MainActor @Test func everyStationSymbolExists() {
        for station in RadioStation.allCases {
            #expect(UIImage(systemName: station.symbol) != nil,
                    "\(station.label) points at a symbol that isn't in SF Symbols: \(station.symbol)")
        }
    }
    #endif

    /// 8-BIT deliberately shares the race loop; nothing else may double up,
    /// or two presets sound identical and the kid thinks the radio is broken.
    @Test func onlyChiptuneSharesATrack() {
        let tracks = RadioStation.allCases.map(\.track)
        #expect(Set(tracks).count == tracks.count)
        #expect(RadioStation.chiptune.track == "race_intensity")
    }
}
