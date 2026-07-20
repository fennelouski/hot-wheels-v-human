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
        (.helmet, .roundShades, .short, .man),
        (.cap, .squareShades, .long, .woman),
        (.crown, .round, .curly, .boy),
        (.headphones, .sunglasses, .pigtails, .girl),
    ]

    /// Newly converted Kenney Mini Characters, shown raw so a bad conversion
    /// (sideways, untextured, T-posed) is obvious at a glance.
    private static let newModels = [
        "character-male-a-drive", "character-female-a-drive",
        "character-male-c-idle", "character-female-d-idle",
    ]

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
            HStack(spacing: 4) {
                ForEach(Self.newModels, id: \.self) { name in
                    VStack(spacing: 4) {
                        RawModelPreview(modelName: name)
                        Text(name).font(.caption2).foregroundStyle(.secondary)
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
