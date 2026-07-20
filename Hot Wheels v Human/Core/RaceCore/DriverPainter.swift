//
//  DriverPainter.swift
//  Hot Wheels v Human
//
//  DriverProfile → the Quaternius human. The rig's single material is
//  colored by a 32×32 stripe-palette texture (rows = skin / eyes / hair /
//  shirt / pants, ranges in DriverPalette.StripeRows), so painting the
//  whole character is just generating a 5-stripe image.
//

import CoreGraphics
import Foundation
import Metal
import RealityKit

@MainActor
enum DriverPainter {

    /// One texture per color combo — kids flip through swatches fast.
    private static var cache: [String: TextureResource] = [:]

    /// The 32×32 stripe-palette image for a profile. Row layout matches the
    /// rig's source texture (top-down); bald paints the hair stripe skin-tone
    /// so the scalp disappears. Pixels are written directly — CG fills would
    /// colorspace-convert and shift the exact palette values.
    nonisolated static func paletteImage(for profile: DriverProfile) -> CGImage? {
        let side = 32
        var pixels = [UInt8](repeating: 255, count: side * side * 4)
        for (rows, hex) in stripes(for: profile) {
            guard let rgb = DriverPalette.rgb(hex: hex) else { continue }
            for row in rows {   // buffer row 0 = image top row
                for x in 0..<side {
                    let i = (row * side + x) * 4
                    pixels[i] = UInt8((rgb.x * 255).rounded())
                    pixels[i + 1] = UInt8((rgb.y * 255).rounded())
                    pixels[i + 2] = UInt8((rgb.z * 255).rounded())
                }
            }
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(width: side, height: side, bitsPerComponent: 8,
                       bitsPerPixel: 32, bytesPerRow: side * 4,
                       space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil,
                       shouldInterpolate: false, intent: .defaultIntent)
    }

    nonisolated static func stripes(for profile: DriverProfile) -> [(Range<Int>, String)] {
        [(DriverPalette.StripeRows.skin, profile.skinToneHex),
         (DriverPalette.StripeRows.eyes,
          profile.eyeColorHex ?? DriverPalette.defaultEyeColor),
         (DriverPalette.StripeRows.hair,
          profile.hair == .bald ? profile.skinToneHex
              : profile.hairColorHex ?? DriverPalette.defaultHairColor),
         (DriverPalette.StripeRows.shirt, profile.suitColorHex),
         (DriverPalette.StripeRows.pants,
          profile.pantsColorHex ?? DriverPalette.defaultPantsColor)]
    }

    /// Everything `apply` actually paints or pins, as one comparable string.
    /// Live previews hold this against the last value so a rebuild only costs
    /// something when the character really changed.
    nonisolated static func appearanceSignature(for profile: DriverProfile) -> String {
        (stripes(for: profile).map(\.1) + [
            profile.hair.rawValue,
            profile.hat?.rawValue ?? "-",
            profile.hatColorHex ?? "-",
            profile.glasses?.rawValue ?? "-",
            profile.bodyType?.rawValue ?? "-",
        ]).joined(separator: "|")
    }

    /// Replaces every material on the driver entity with the profile's
    /// stripe texture, then attaches the wardrobe (hats/glasses/hair).
    /// Same wholesale-replacement path CarFactory.paint already exercises.
    ///
    /// Note: on a bust that's already mid-animation the wardrobe swap lands
    /// but the texture swap does not — live previews of a *changing* driver
    /// should rebuild the entity instead (see ReactionCamView).
    /// `bakedAppearance` (the default, for Kenney roster characters): their
    /// outfit, hair and face are already painted into a colormap, and this
    /// function paints by REPLACING every material — which on them erases
    /// precisely what makes each one a different person. So only the
    /// wardrobe gets fitted. Pass `false` for the legacy Quaternius rig,
    /// which is a blank mesh that NEEDS the stripe palette (the reaction-cam
    /// bust still rides it; skipping there rendered it plain white).
    static func apply(_ profile: DriverProfile, to driver: Entity,
                      bakedAppearance: Bool = true) async {
        // Wardrobe off first so the paint pass can't repaint the props.
        driver.findEntity(named: DriverDressUp.entityName)?.removeFromParent()
        defer { DriverDressUp.attach(profile, to: driver) }
        guard !bakedAppearance else { return }
        guard let texture = await texture(for: profile) else { return }
        var material = PhysicallyBasedMaterial()
        // Nearest sampling: 32 px of stripes must not blur into each other.
        let sampler = MTLSamplerDescriptor()
        sampler.minFilter = .nearest
        sampler.magFilter = .nearest
        material.baseColor = .init(texture: .init(texture,
            sampler: .init(sampler)))
        material.metallic = 0.0
        material.roughness = 0.8
        for part in driver.descendantsAndSelf() {
            guard var model = part.components[ModelComponent.self] else { continue }
            model.materials = model.materials.map { _ in material }
            part.components.set(model)
        }
    }

    private static func texture(for profile: DriverProfile) async -> TextureResource? {
        let key = stripes(for: profile).map(\.1).joined(separator: "|")
        if let cached = cache[key] { return cached }
        guard let image = paletteImage(for: profile),
              let texture = try? await TextureResource(
                  image: image, options: .init(semantic: .color, mipmapsMode: .none))
        else { return nil }
        cache[key] = texture
        return texture
    }
}
