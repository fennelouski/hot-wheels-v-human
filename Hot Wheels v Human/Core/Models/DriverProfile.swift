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

nonisolated enum HatStyle: String, Codable, CaseIterable, Sendable {
    case none
    case helmet
    case cap
    case crown
    case headphones
}

nonisolated enum GlassesStyle: String, Codable, CaseIterable, Sendable {
    case none
    case sunglasses
    case round
    case star
}

nonisolated struct DriverProfile: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var helmetColorHex: String
    var suitColorHex: String    // shirt stripe on the rig's palette texture
    var skinToneHex: String
    var hair: HairStyle
    // Character-creation fields (C-series). All optional → old records decode.
    var hairColorHex: String? = nil
    /// Eyes AND eyebrows — they share one stripe on the rig's palette texture.
    var eyeColorHex: String? = nil
    var pantsColorHex: String? = nil
    var hat: HatStyle? = nil
    var hatColorHex: String? = nil
    var glasses: GlassesStyle? = nil
    /// Face paint drawn in the editor, PNG ≤ 64 KB, composited over the
    /// reaction-cam face. Replaces CarDesign.faceDrawingPNG (kept there as a
    /// read fallback for old designs).
    var faceDrawingPNG: Data? = nil
}

extension DriverProfile {
    /// Kid-sized racer names for the dice button (profile picker + editors).
    static func randomName() -> String {
        ["Max", "Zip", "Dot", "Rex", "Sky", "Pip",
         "Ace", "Juno", "Bolt", "Nova"].randomElement()!
    }
}
