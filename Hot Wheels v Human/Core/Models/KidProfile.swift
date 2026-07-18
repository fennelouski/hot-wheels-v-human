//
//  KidProfile.swift
//  Hot Wheels v Human
//
//  A local "Who's playing?" profile — Netflix-kids style, no accounts.
//  Each profile owns its saved characters (DriverProfileRecord.ownerProfileID).
//

import Foundation

nonisolated struct KidProfile: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var colorHex: String
}
