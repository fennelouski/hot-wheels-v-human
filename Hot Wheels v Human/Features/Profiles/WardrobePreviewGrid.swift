//
//  WardrobePreviewGrid.swift
//  Hot Wheels v Human
//
//  Dev harness (`--wardrobe`): every hat and glasses style on screen at once,
//  with fixed profiles. The character editor randomises its driver on each
//  launch, so wardrobe geometry — does a hat sit ON the head or hover above
//  it, do the lenses actually cover the face, does the hair hang right — is
//  impossible to check twice the same way from there. This is the bench for
//  that: change DriverDressUp, screenshot this, compare.
//

import SwiftUI

struct WardrobePreviewGrid: View {

    /// One column per hat, so a single screenshot covers the whole wardrobe.
    /// Glasses/hair/body vary alongside so those get eyes on them too.
    private static let combos: [(hat: HatStyle, glasses: GlassesStyle,
                                 hair: HairStyle, body: BodyType)] = [
        (.helmet, .roundShades, .short, .man),
        (.cap, .squareShades, .long, .woman),
        (.crown, .round, .curly, .boy),
        (.headphones, .sunglasses, .pigtails, .girl),
    ]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(Self.combos.enumerated()), id: \.offset) { _, combo in
                VStack(spacing: 4) {
                    DriverPreviewView(driver: Self.profile(combo))
                    Text("\(combo.hat.rawValue) · \(combo.glasses.rawValue)")
                        .font(.caption).bold()
                    Text("\(combo.body.rawValue) · \(combo.hair.rawValue)")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(8)
    }

    private static func profile(_ c: (hat: HatStyle, glasses: GlassesStyle,
                                      hair: HairStyle, body: BodyType)) -> DriverProfile {
        DriverProfile(id: UUID(), name: "Bench",
                      helmetColorHex: "#D62718",
                      suitColorHex: "#FFD500",
                      skinToneHex: "#F2C79A",
                      hair: c.hair,
                      hairColorHex: "#7A4A21",
                      eyeColorHex: "#1C1C1E",
                      pantsColorHex: "#2266FF",
                      hat: c.hat,
                      hatColorHex: "#2E7D32",
                      glasses: c.glasses,
                      bodyType: c.body)
    }
}
