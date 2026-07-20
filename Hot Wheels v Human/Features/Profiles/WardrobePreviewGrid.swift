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
import RealityKit

/// Raw USDZ on a turntable — no painting, no wardrobe. Proves a newly
/// converted asset actually loads, stands upright, keeps its texture and
/// holds its baked pose, without going through the driver pipeline.
struct RawModelPreview: View {
    let modelName: String

    var body: some View {
        RealityView { content in
            content.camera = .virtual
            let height = RaceTuning.driverSourceHeight
            let camera = PerspectiveCamera()
            camera.look(at: [0, height * 0.5, 0],
                        from: [0, height * 0.6, height * 1.15], relativeTo: nil)
            content.add(camera)
            let light = DirectionalLight()
            light.light.intensity = 5000
            light.look(at: .zero, from: [height, height, height], relativeTo: nil)
            content.add(light)
            if let model = try? await AssetStore.shared.entity(named: modelName) {
                if let clip = model.availableAnimations.first {
                    model.playAnimation(clip.repeat())
                }
                content.add(model)
            }
        }
    }
}

struct WardrobePreviewGrid: View {

    /// One column per hat, so a single screenshot covers the whole wardrobe.
    /// Glasses/hair/body vary alongside so those get eyes on them too.
    private static let combos: [(hat: HatStyle, glasses: GlassesStyle,
                                 hair: HairStyle, body: BodyType)] = [
        (.helmet, .roundShades, .character, .man),
        (.cap, .squareShades, .longHair, .woman),
        (.crown, .round, .bun, .boy),
        (.headphones, .sunglasses, .buns, .girl),
    ]

    /// Every hairstyle, six to a row.
    private static let hairRows: [[HairStyle]] = HairStyle.allCases
        .chunked(into: 6)

    var body: some View {
        VStack(spacing: 6) {
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
            Divider()
            // The whole hair library on one screen, bare-headed so nothing
            // hides it. Hair is real extracted geometry now, so "does it sit
            // on the skull or float behind it" is the question this bench
            // was built to answer — and it can only be answered by looking.
            ForEach(Array(Self.hairRows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 4) {
                    ForEach(row, id: \.self) { style in
                        VStack(spacing: 2) {
                            DriverPreviewView(driver: Self.profile(
                                (hat: HatStyle.none, glasses: GlassesStyle.none,
                                 hair: style, body: .woman)))
                            Text(style.rawValue).font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
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

private extension Array {
    /// ponytail: bench-only row splitter; there's no other caller.
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
