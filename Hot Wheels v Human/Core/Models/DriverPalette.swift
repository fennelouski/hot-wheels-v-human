//
//  DriverPalette.swift
//  Hot Wheels v Human
//
//  The character-creation color book: every swatch the editor offers, the
//  stripe layout of the Quaternius rig's 32×32 palette texture, and the
//  nearest-swatch snap shared by the editor and the camera lookalike.
//

import Foundation

nonisolated enum DriverPalette {

    // MARK: Swatches (editor buttons + lookalike snap targets)

    static let skinTones = ["#FFDBB4", "#F1C27D", "#E0AC69", "#C68642", "#8D5524"]

    static let hairColors = ["#1C1C1E", "#4A2C13", "#7C5823", "#B0793C",
                             "#E7C87B", "#D62718", "#8E8E93", "#8E44AD"]

    static let eyeColors = ["#3B2716", "#7C5823", "#2266FF", "#5AC8FA",
                            "#34C759", "#8E8E93"]

    static let outfitColors = ["#FFD500", "#FF3B30", "#FF9500", "#2266FF",
                               "#34C759", "#8E44AD", "#F2F2F7", "#1C1C1E"]

    // MARK: Defaults for old profiles that predate the new fields

    static let defaultHairColor = "#7C5823"
    static let defaultEyeColor = "#3B2716"
    static let defaultPantsColor = "#2266FF"

    // MARK: Stripe rows in the rig's 32×32 palette texture (top-down)

    /// Verified against the Quaternius TextureTutorial: the whole human is
    /// UV-mapped to horizontal stripes of one 32×32 texture.
    enum StripeRows {
        static let skin = 0..<6
        static let eyes = 6..<11      // eyes + eyebrows share this stripe
        static let hair = 11..<17
        static let shirt = 17..<23
        static let pants = 23..<32
    }

    // MARK: Shading

    /// How much the pants stripe is darkened relative to the swatch picked.
    /// Enough that a shirt and pants of the same color read as an outfit
    /// instead of pajamas; little enough that the swatch still looks right.
    static let pantsDarkening: Float = 0.15

    /// `hex` with every channel scaled down by `amount`. Malformed hex is
    /// returned untouched — same garbage-in rule as `nearest(hex:in:)`.
    static func darkened(_ hex: String, by amount: Float) -> String {
        guard let rgb = rgb(hex: hex) else { return hex }
        let scaled = rgb * (1 - amount) * 255
        return String(format: "#%02X%02X%02X",
                      Int(scaled.x.rounded()), Int(scaled.y.rounded()),
                      Int(scaled.z.rounded()))
    }

    // MARK: Snapping

    /// The swatch in `palette` closest to `hex` by RGB distance. Returns
    /// `hex` unchanged if it doesn't parse (garbage in, garbage kept —
    /// callers pass palette hexes or camera-sampled hexes, both well-formed).
    static func nearest(hex: String, in palette: [String]) -> String {
        guard let target = rgb(hex: hex) else { return hex }
        let best = palette.min { a, b in
            distanceSquared(target, rgb(hex: a)) < distanceSquared(target, rgb(hex: b))
        }
        return best ?? hex
    }

    /// "#RRGGBB" → channels 0…1. Nil for anything malformed.
    static func rgb(hex: String) -> SIMD3<Float>? {
        var text = hex
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6, let value = UInt32(text, radix: 16) else { return nil }
        return SIMD3(Float((value >> 16) & 0xFF),
                     Float((value >> 8) & 0xFF),
                     Float(value & 0xFF)) / 255
    }

    private static func distanceSquared(_ a: SIMD3<Float>, _ b: SIMD3<Float>?) -> Float {
        guard let b else { return .infinity }
        let d = a - b
        return (d * d).sum()
    }
}
