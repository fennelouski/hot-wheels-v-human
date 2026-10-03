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

    private(set) var lastSaveError: String?

    /// Upsert by id. Remembering a selected racer commits together with its
    /// appearance, so failed storage never leaves a false last-used pointer.
    @discardableResult
    func save(into context: ModelContext, ownerProfileID: UUID?,
              rememberAsLastUsed: Bool = false) -> Bool {
        var edited: DriverProfileRecord?
        var oldName: String?
        var oldData: Data?
        var inserted: DriverProfileRecord?
        var owner: KidProfileRecord?
        var oldLastUsed: UUID?
        do {
            let data = try JSONEncoder().encode(driver)
            let id = driver.id
            let descriptor = FetchDescriptor<DriverProfileRecord>(predicate: #Predicate { $0.id == id })
            if let record = try context.fetch(descriptor).first {
                edited = record
                oldName = record.name
                oldData = record.profileData
                record.profileData = data
                record.name = driver.name
            } else {
                let record = try DriverProfileRecord(profile: driver, ownerProfileID: ownerProfileID)
                context.insert(record)
                inserted = record
            }
            if rememberAsLastUsed, let ownerProfileID {
                let descriptor = FetchDescriptor<KidProfileRecord>(predicate: #Predicate { $0.id == ownerProfileID })
                owner = try context.fetch(descriptor).first
                oldLastUsed = owner?.lastUsedDriverID
                owner?.lastUsedDriverID = driver.id
            }
            try context.save()
            lastSaveError = nil
            return true
        } catch {
            if let edited, let oldName, let oldData {
                edited.name = oldName
                edited.profileData = oldData
            }
            if let inserted { context.delete(inserted) }
            owner?.lastUsedDriverID = oldLastUsed
            lastSaveError = "Your racer couldn't be saved. Your changes are still here; try Save again."
            return false
        }
    }
}
