//
//  SwiftDataRecords.swift
//  Hot Wheels v Human
//
//  SwiftData wrappers storing the Codable structs as JSON blobs —
//  migration-proof, and the wire types stay plain structs. Used on iPad
//  only (Phase 4 wires up the ModelContainer + garage UI).
//

import Foundation
import SwiftData

@Model
final class CarDesignRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var designData: Data

    init(design: CarDesign) throws {
        self.id = design.id
        self.name = design.name
        self.designData = try JSONEncoder().encode(design)
    }

    var design: CarDesign? { try? JSONDecoder().decode(CarDesign.self, from: designData) }
}

extension ModelContext {
    /// The stored record behind a design id, if this car was ever saved.
    func carRecord(_ id: UUID) -> CarDesignRecord? {
        try? fetch(FetchDescriptor<CarDesignRecord>(predicate: #Predicate { $0.id == id })).first
    }

    /// Save a car, keyed by design id: editing a saved car overwrites it,
    /// a new car inserts. "Save" means save everywhere — the garage's
    /// "Make a Copy" is how you deliberately get a sibling now (it used to
    /// be a side effect of tapping Save twice, which nobody could guess).
    func saveDesign(_ design: CarDesign) {
        if let existing = carRecord(design.id), let data = try? JSONEncoder().encode(design) {
            existing.name = design.name
            existing.designData = data
        } else if let record = try? CarDesignRecord(design: design) {
            insert(record)
        }
        try? save()
    }
}

@Model
final class DriverProfileRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var profileData: Data
    /// The KidProfile this character belongs to. Optional so pre-profile
    /// records lightweight-migrate; nil = orphaned, never shown.
    var ownerProfileID: UUID? = nil

    init(profile: DriverProfile, ownerProfileID: UUID? = nil) throws {
        self.id = profile.id
        self.name = profile.name
        self.profileData = try JSONEncoder().encode(profile)
        self.ownerProfileID = ownerProfileID
    }

    var profile: DriverProfile? { try? JSONDecoder().decode(DriverProfile.self, from: profileData) }
}

@Model
final class KidProfileRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var profileData: Data
    /// Character auto-selected when this profile logs in.
    var lastUsedDriverID: UUID? = nil

    init(profile: KidProfile) throws {
        self.id = profile.id
        self.name = profile.name
        self.profileData = try JSONEncoder().encode(profile)
    }

    var profile: KidProfile? { try? JSONDecoder().decode(KidProfile.self, from: profileData) }
}

@Model
final class TrackBlueprintRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var blueprintData: Data

    init(name: String, blueprint: TrackBlueprint) throws {
        self.id = blueprint.trackId
        self.name = name
        self.blueprintData = try JSONEncoder().encode(blueprint)
    }

    var blueprint: TrackBlueprint? { try? JSONDecoder().decode(TrackBlueprint.self, from: blueprintData) }
}
