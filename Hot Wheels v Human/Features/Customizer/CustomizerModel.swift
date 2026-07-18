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
        self.design = design ?? Self.startingDesign()
        self.driver = DriverProfile(
            id: UUID(), name: "Racer", helmetColorHex: "#FFD500",
            suitColorHex: "#2266FF", skinToneHex: "#E0AC69", hair: .short)
    }

    /// Dev deep link `--demo-design` opens the customizer showing every
    /// customization feature at once — the screenshot-verification loop.
    private static func startingDesign() -> CarDesign {
        var design = CarDesign(
            id: UUID(), name: CustomizerModel.randomCarName(),
            chassis: .balancedFormula, tires: .standard,
            paint: PaintSpec(colorHex: "#FF6600", finish: .glossy))
        if ProcessInfo.processInfo.arguments.contains("--demo-design") {
            design.name = "Demo Dazzler"
            design.paint = PaintSpec(colorHex: "#2266FF", finish: .sparkle)
            design.partColors = [CarPaintSlot.wheels: "#FFD500"]
            design.livery = LiverySpec(pattern: .flames, colorHex: "#FF3B30", scale: 1)
        }
        return design
    }

    // MARK: Undo (kid-first rule: always visible, unlimited, no confirmations)

    private(set) var undoStack: [CarDesign] = []
    private var restoring = false

    /// Called from the view's `.onChange(of: design)` with the old value.
    func designChanged(from old: CarDesign) {
        if restoring { restoring = false; return }
        undoStack.append(old)
        // ponytail: unbounded — designs are tiny; cap the stack when
        // drawingPNG (G4) makes snapshots heavy.
    }

    func undo() {
        guard let previous = undoStack.popLast() else {
            SoundBank.shared.play("nope_wobble")
            return
        }
        restoring = true
        design = previous
        SoundBank.shared.play("ui_back")
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
