//
//  CharacterEditorModel.swift
//  Hot Wheels v Human
//
//  Working copy of a character being designed. Unlike cars (clone-on-save),
//  a kid's "me" character saves in place — save() upserts by id.
//

import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class CharacterEditorModel {
    var driver: DriverProfile

    init(driver: DriverProfile? = nil) {
        self.driver = driver ?? Self.newCharacter()
    }

    /// A fresh character starts as a remix of a random starter so every
    /// tab already has something fun on it.
    static func newCharacter() -> DriverProfile {
        var starter = DriverProfile.presets.randomElement()!
        starter.id = UUID()
        starter.name = DriverProfile.randomName()
        return starter
    }

    // MARK: Undo (kid-first rule: always visible, unlimited, no confirmations)

    private(set) var undoStack: [DriverProfile] = []
    private var restoring = false

    /// Called from the view's `.onChange(of: driver)` with the old value.
    func driverChanged(from old: DriverProfile) {
        if restoring { restoring = false; return }
        undoStack.append(old)
        // Snapshots are small (a profile is colors and enums), but unlimited
        // undo on a screen kids hammer still wants a ceiling.
        if undoStack.count > 100 { undoStack.removeFirst() }
    }

    func undo() {
        guard let previous = undoStack.popLast() else {
            SoundBank.shared.play("nope_wobble")
            return
        }
        restoring = true
        driver = previous
        SoundBank.shared.play("ui_back")
    }

    /// Upsert by id: editing "me" updates in place, a new character inserts.
    func save(into context: ModelContext, ownerProfileID: UUID?) {
        let id = driver.id
        let descriptor = FetchDescriptor<DriverProfileRecord>(
            predicate: #Predicate { $0.id == id })
        if let existing = try? context.fetch(descriptor).first {
            if let data = try? JSONEncoder().encode(driver) {
                existing.profileData = data
                existing.name = driver.name
            }
        } else if let record = try? DriverProfileRecord(
                profile: driver, ownerProfileID: ownerProfileID) {
            context.insert(record)
        }
        try? context.save()
    }
}
