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
    case extraLong
    case pigtails
    case curly
    case bald

    /// Unknown raw values (older or newer peers) fall back instead of
    /// failing the whole profile decode.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: raw) ?? .short
    }
}

nonisolated enum HatStyle: String, Codable, CaseIterable, Sendable {
    case none
    case helmet
    case cap
    case crown
    case headphones
}

/// Frames (round / square / sporty) × lenses (clear / dark), all solid color.
nonisolated enum GlassesStyle: String, Codable, CaseIterable, Sendable {
    case none
    case round          // clear round
    case square         // clear square
    case sunglasses     // sporty wraparound shades (pre-C-series raw value)
    case roundShades
    case squareShades

    /// Retired styles ("star") and unknown values decode as shades.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: raw) ?? .roundShades
    }
}

/// The CC0 pack ships ONE rigged human, so all four bodies are that mesh —
/// they differ by silhouette (this non-uniform scale) plus per-profile skin/
/// hair/clothing colour and wardrobe. Genuinely separate meshes would need
/// assets we don't have. The scales are pushed far enough apart to read as
/// four distinct people, not one figure zoomed: adults full-height with the
/// man broad and the woman notably slimmer; kids clearly shorter AND stockier
/// (a child is not a scaled-down adult — bigger head-to-body ratio, which a
/// shorter body under the fixed-scale head approximates).
nonisolated enum BodyType: String, Codable, CaseIterable, Sendable {
    case man
    case woman
    case boy
    case girl

    var scale: SIMD3<Float> {
        switch self {
        case .man: SIMD3(1.06, 1.0, 1.06)   // broad-shouldered, full height
        case .woman: SIMD3(0.82, 0.98, 0.82) // slim, nearly as tall
        case .boy: SIMD3(0.88, 0.74, 0.9)    // short and stocky
        case .girl: SIMD3(0.74, 0.7, 0.74)   // smallest, slight
        }
    }

    var isFemale: Bool { self == .woman || self == .girl }

    /// Which of the six same-sex roster models this body wears by default.
    /// Kids get a DIFFERENT mesh from the adults, not just a smaller one —
    /// that was the whole complaint.
    var defaultVariant: String {
        switch self {
        case .man, .woman: "a"
        case .boy, .girl: "d"
        }
    }
}

/// Poses baked at conversion — one USDZ each (Blender's USD exporter can't
/// carry glTF's named clips, see Graphics/README).
nonisolated enum DriverPose: String, Sendable {
    case idle       // editors, previews, the reaction bust
    case drive      // sat in the car, hands out on the wheel
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
    /// nil = man (profiles predate body types).
    var bodyType: BodyType? = nil
    /// Which of the six roster models of this body's sex ("a"…"f").
    /// nil = the body type's default. Additive optional, so old records and
    /// older peers still decode.
    var characterVariant: String? = nil
    /// Face paint drawn in the editor, PNG ≤ 64 KB, composited over the
    /// reaction-cam face. Replaces CarDesign.faceDrawingPNG (kept there as a
    /// read fallback for old designs).
    var faceDrawingPNG: Data? = nil
}

extension DriverProfile {
    /// The roster model this profile wears, for a given pose — e.g.
    /// `character-female-d-drive`. Twelve distinct meshes (Kenney Mini
    /// Characters) replace the single Quaternius rig that every body type
    /// used to share at different scales.
    func modelName(pose: DriverPose) -> String {
        let body = bodyType ?? .man
        let sex = body.isFemale ? "female" : "male"
        let variant = characterVariant ?? body.defaultVariant
        return "character-\(sex)-\(variant)-\(pose.rawValue)"
    }

    /// Kid-sized racer names for the dice button (profile picker + editors).
    static func randomName() -> String {
        ["Max", "Zip", "Dot", "Rex", "Sky", "Pip",
         "Ace", "Juno", "Bolt", "Nova"].randomElement()!
    }
}
