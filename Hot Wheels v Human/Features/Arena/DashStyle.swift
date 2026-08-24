//
//  DashStyle.swift
//  Hot Wheels v Human
//
//  Every car gets its own dash. The chassis picks the material the dash is
//  moulded from, the paint picks the colour of everything that lights up, and
//  the finish decides how shiny the top lip is — so climbing into the monster
//  truck feels different from climbing into the formula car before you've
//  moved an inch.
//

import SwiftUI

struct DashStyle {
    /// What the dash is made of — drives the surface texture and the trim.
    enum Material {
        case brushedSteel   // heavy muscle: thick plate, exposed bolts
        case carbonFibre    // balanced formula: woven weave, no ornament
        case neonPlastic    // superlight drift: dark shell, lit underline
    }

    var material: Material
    var plateTop: Color
    var plateBottom: Color
    var housing: Color
    /// Everything that glows: gauge numerals, display text, lit preset keys.
    var accent: Color
    /// Top-lip highlight strength, 0…1 — a matte car's dash barely catches
    /// the sky, a glossy one flares.
    var gloss: Double
    /// Sparkle paint flecks the moulding too.
    var glitter: Bool
    /// Stamped on the gauge housing, like the badge on a real dash.
    var nameplate: String

    init(design: CarDesign) {
        nameplate = design.name.uppercased()
        accent = .dashAccent(design.paint.colorHex)

        switch design.chassis {
        case .heavyMuscle:
            material = .brushedSteel
            plateTop = Color(red: 0.30, green: 0.29, blue: 0.27)
            plateBottom = Color(red: 0.10, green: 0.09, blue: 0.08)
            housing = Color(red: 0.15, green: 0.14, blue: 0.13)
        case .balancedFormula:
            material = .carbonFibre
            plateTop = Color(red: 0.16, green: 0.17, blue: 0.19)
            plateBottom = Color(red: 0.03, green: 0.03, blue: 0.04)
            housing = Color(red: 0.08, green: 0.08, blue: 0.09)
        case .superlightDrift:
            material = .neonPlastic
            plateTop = Color(red: 0.19, green: 0.16, blue: 0.28)
            plateBottom = Color(red: 0.05, green: 0.04, blue: 0.09)
            housing = Color(red: 0.11, green: 0.09, blue: 0.16)
        }

        switch design.paint.finish {
        case .glossy: gloss = 0.75
        case .metallic: gloss = 0.55
        case .sparkle: gloss = 0.60
        case .matte: gloss = 0.18
        }
        glitter = design.paint.finish == .sparkle
    }
}

extension Color {
    /// Paint hex → something that still reads as a light on a black dash. A
    /// navy car would otherwise get a navy display you can't see from
    /// the couch, so dark paints get lifted until they glow.
    static func dashAccent(_ hex: String) -> Color {
        var value: UInt64 = 0
        Scanner(string: hex.replacingOccurrences(of: "#", with: "")).scanHexInt64(&value)
        var r = Double((value >> 16) & 0xFF) / 255
        var g = Double((value >> 8) & 0xFF) / 255
        var b = Double(value & 0xFF) / 255
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        if luminance < 0.45, luminance > 0 {
            let lift = 0.45 / luminance
            r = min(1, r * lift); g = min(1, g * lift); b = min(1, b * lift)
        } else if luminance == 0 {
            r = 0.85; g = 0.85; b = 0.85          // pure black paint: chrome
        }
        return Color(red: r, green: g, blue: b)
    }
}
