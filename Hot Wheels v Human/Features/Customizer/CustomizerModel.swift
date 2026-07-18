//
//  CustomizerModel.swift
//  Hot Wheels v Human
//
//  Working copy of a car (+driver) being designed. save() → SwiftData.
//

import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class CustomizerModel {
    var design: CarDesign
    var driver: DriverProfile

    init(design: CarDesign? = nil) {
        self.design = design ?? CarDesign(
            id: UUID(), name: CustomizerModel.randomCarName(),
            chassis: .balancedFormula, tires: .standard,
            paint: PaintSpec(colorHex: "#FF6600", finish: .glossy))
        self.driver = DriverProfile(
            id: UUID(), name: "Racer", helmetColorHex: "#FFD500",
            suitColorHex: "#2266FF", skinToneHex: "#E0AC69", hair: .short)
    }

    func save(into context: ModelContext) {
        // New id per save so "save again" makes a sibling, not an overwrite —
        // kids iterate by cloning.
        design.id = UUID()
        if let record = try? CarDesignRecord(design: design) {
            context.insert(record)
        }
        if let record = try? DriverProfileRecord(profile: driver) {
            context.insert(record)
        }
        try? context.save()
    }

    static func randomCarName() -> String {
        let first = ["Turbo", "Mega", "Rocket", "Thunder", "Blazing", "Wild",
                     "Lucky", "Cosmic", "Atomic", "Rapid"].randomElement()!
        let second = ["Comet", "Falcon", "Dragon", "Cheetah", "Lightning",
                      "Racer", "Streak", "Flash", "Bandit", "Zoomer"].randomElement()!
        return "\(first) \(second)"
    }
}
