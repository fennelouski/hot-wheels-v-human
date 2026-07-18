//
//  StarterPresetTests.swift
//  Hot Wheels v HumanTests
//
//  Guardrail: every shipped preset track passes the validator and every
//  preset car is wire-safe. Editing StarterPresets.swift into a broken
//  state fails here, not on a kid's iPad.
//

import Foundation
import Testing
@testable import Hot_Wheels_v_Human

struct StarterPresetTests {

    @Test func everyPresetTrackIsValid() {
        for (name, blueprint) in TrackBlueprint.presets {
            let result = BlueprintValidator.validate(blueprint)
            #expect(result.isValid, "\(name): \(result.reasons.joined(separator: "; "))")
        }
    }

    @Test func presetTracksHaveUniqueIdsAndNames() {
        let ids = TrackBlueprint.presets.map(\.blueprint.trackId)
        let names = TrackBlueprint.presets.map(\.name)
        #expect(Set(ids).count == ids.count)
        #expect(Set(names).count == names.count)
    }

    @Test func presetTracksSpanEasyToSpicy() {
        // At least one no-loop starter track and at least one with a loop.
        let loopCounts = TrackBlueprint.presets.map {
            $0.blueprint.segments.filter { $0.type == .loop }.count
        }
        #expect(loopCounts.contains(0))
        #expect(loopCounts.contains(where: { $0 >= 1 }))
    }

    @Test func everyPresetCarRoundTripsAndShowsOffCustomization() throws {
        for car in CarDesign.presets {
            let decoded = try JSONDecoder().decode(
                CarDesign.self, from: JSONEncoder().encode(car))
            #expect(decoded == car)
            #expect(car.livery != nil)
            #expect(!(car.stickers ?? []).isEmpty)
            #expect(!(car.partColors ?? [:]).isEmpty)
        }
    }

    @Test func presetCarsHaveUniqueIdsAndNames() {
        #expect(Set(CarDesign.presets.map(\.id)).count == CarDesign.presets.count)
        #expect(Set(CarDesign.presets.map(\.name)).count == CarDesign.presets.count)
    }
}
