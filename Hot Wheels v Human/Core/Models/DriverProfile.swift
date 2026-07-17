//
//  DriverProfile.swift
//  Hot Wheels v Human
//
//  The little human in the car. Visuals only — no physics.
//

import Foundation

nonisolated enum HairStyle: String, Codable, CaseIterable, Sendable {
    case short
    case long
    case curly
    case bald
}

nonisolated struct DriverProfile: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var helmetColorHex: String
    var suitColorHex: String
    var skinToneHex: String
    var hair: HairStyle
}
