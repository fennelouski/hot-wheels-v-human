//
//  DriverDressUp.swift
//  Hot Wheels v Human
//
//  Procedural dress-up props: hats, glasses, and hair volumes built from
//  generated meshes (no new assets), pinned at the rig's bind-pose head.
//  DriverPainter attaches these after painting, so every surface that
//  paints a driver gets the wardrobe for free.
//

import Foundation
import RealityKit
#if canImport(UIKit)
import UIKit
#endif

@MainActor
enum DriverDressUp {

    static let entityName = "dress-up"

    /// Which props a profile wears — pure mapping, unit-testable.
    nonisolated static func props(for profile: DriverProfile) -> [String] {
        var names: [String] = []
        switch profile.hat ?? .none {
        case .none: break
        case .helmet: names.append("helmet")
        case .cap: names.append("cap")
        case .crown: names.append("crown")
        case .headphones: names.append("headphones")
        case .policeCap: names.append(HatStyle.policeCap.modelName!)
        }
        // A few roster characters can't have their eyes recoloured apart from
        // a garment (RosterColormap.eyesTakeGarmentColor) — so they always wear
        // glasses to cover them, even when the profile picked "none".
        var glasses = profile.glasses ?? .none
        if glasses == .none, RosterColormap.eyesTakeGarmentColor(for: profile) {
            glasses = .round
        }
        switch glasses {
        case .none: break
        case .sunglasses: names.append("sport-shades")
        case .round: names.append("round-glasses")
        case .square: names.append("square-glasses")
        case .roundShades: names.append("round-shades")
        case .squareShades: names.append("square-shades")
        }
        // Hair is a real mesh lifted off the roster's own heads, attached to
        // the bald cut of whichever character you picked (see HairStyle).
        // `.character` wears its own; `.bald` wears nothing.
        if let hair = profile.hair.modelName {
            names.append(hair)
        }
        return names
    }

    /// Removes any previous wardrobe and pins fresh props at the head.
    /// The rig faces +Z; brims and lenses go on that side. HeadPinSystem
    /// re-pins the wardrobe to the posed Head joint every frame; the fixed
    /// bind-pose position set here is the fallback if the joint vanishes.
    static func attach(_ profile: DriverProfile, to driver: Entity,
                       assets: AssetStore? = nil) async {
        let assets = assets ?? AssetStore.shared
        registerOnce
        driver.findEntity(named: entityName)?.removeFromParent()
        let wardrobe = Entity()
        wardrobe.name = entityName
        wardrobe.position = [0, RaceTuning.driverSourceHeight * RaceTuning.driverHeadHeightRatio, 0]
        wardrobe.components.set(HeadPinComponent())

        let head = RaceTuning.driverSourceHeight * RaceTuning.driverHeadRadiusRatio
        let hatColor = color(profile.hatColorHex ?? "#FFD500")
        let hairColor = color(profile.hairColorHex ?? DriverPalette.defaultHairColor)
        let dark = color("#1C1C1E")

        // Wardrobe origin rides the Head joint (base of the head); props
        // below are positioned around the head's CENTER. Offset tuned by
        // eye against the editor preview — the joint sits mid-neck.
        let center = Entity()
        center.position = [0, head * 1.7, 0]
        wardrobe.addChild(center)

        // Hats ride their own mount: scaled up and floated ABOVE the head so
        // they sit ON the hair like a real hat, not jammed down over the
        // face, and even the biggest hair volumes never poke through them.
        // Sits high enough to read as headwear PERCHED on the hair. Lower
        // (0.3–0.45) the dome/crown swallow the skull and just recolour the
        // top of the head — a green helmet reads as green hair.
        let hat = Entity()
        hat.position = [0, head * 0.68, 0]
        hat.scale = .init(repeating: 1.18)
        center.addChild(hat)

        for prop in props(for: profile) {
            switch prop {
            case "helmet":
                // Oversized dome over the top half of the head.
                let dome = model(.generateSphere(radius: head * 1.25), hatColor)
                dome.position = [0, head * 0.15, 0]
                dome.scale = [1, 0.95, 1]
                hat.addChild(dome)
            case "cap":
                let crownPart = model(.generateSphere(radius: head * 1.1), hatColor)
                crownPart.position = [0, head * 0.45, 0]
                crownPart.scale = [1, 0.6, 1]
                hat.addChild(crownPart)
                let brim = model(.generateBox(size: [head * 1.3, head * 0.12, head * 0.9]), hatColor)
                brim.position = [0, head * 0.5, head * 1.1]
                hat.addChild(brim)
            case "crown":
                let band = model(.generateCylinder(height: head * 0.6, radius: head * 0.95), hatColor)
                band.position = [0, head * 1.0, 0]
                hat.addChild(band)
                for i in -1...1 {   // three chunky points
                    let point = model(.generateCone(height: head * 0.5, radius: head * 0.22), hatColor)
                    point.position = [Float(i) * head * 0.55, head * 1.55, head * 0.75]
                    hat.addChild(point)
                }
            case "headphones":
                // Band hugs the crown — it was pitched high enough to read as
                // a bar hovering over the head rather than headphones worn on it.
                let band = model(.generateBox(size: [head * 2.3, head * 0.22, head * 0.35]), hatColor)
                band.position = [0, head * 0.72, 0]
                hat.addChild(band)
                for side: Float in [-1, 1] {
                    let cup = model(.generateSphere(radius: head * 0.42), hatColor)
                    cup.position = [side * head * 1.05, 0, 0]
                    cup.scale = [0.6, 1, 1]
                    hat.addChild(cup)
                }
            case "sport-shades":
                // One big wraparound visor covering both eyes brow-to-cheek.
                let visor = model(.generateBox(size: [head * 1.85, head * 0.66, head * 0.16],
                                               cornerRadius: head * 0.1), dark)
                visor.position = [0, head * 0.16, head * 0.95]
                center.addChild(visor)
            case "round-glasses", "round-shades", "square-glasses", "square-shades":
                // Solid dark frames; clear styles get pale solid lenses,
                // shades get dark ones. Big lenses — kids want goggles that
                // cover the face, not dainty specs, so these run eye-socket
                // to cheekbone. Spacing widened to match so they still read
                // as two lenses joined by a bridge, not one band.
                let lensColor = prop.hasSuffix("shades") ? dark : color("#DFF3FF")
                for side: Float in [-1, 1] {
                    let frame: ModelEntity
                    let lens: ModelEntity
                    if prop.hasPrefix("round") {
                        frame = model(.generateCylinder(height: head * 0.1, radius: head * 0.52), dark)
                        lens = model(.generateCylinder(height: head * 0.12, radius: head * 0.44), lensColor)
                        // Cylinders extrude along Y; spin them to face front.
                        frame.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
                        lens.orientation = frame.orientation
                    } else {
                        frame = model(.generateBox(size: [head * 0.9, head * 0.72, head * 0.1],
                                                   cornerRadius: head * 0.08), dark)
                        lens = model(.generateBox(size: [head * 0.76, head * 0.58, head * 0.12],
                                                  cornerRadius: head * 0.07), lensColor)
                    }
                    frame.position = [side * head * 0.5, head * 0.16, head * 0.9]
                    lens.position = [side * head * 0.5, head * 0.16, head * 0.95]
                    center.addChild(frame)
                    center.addChild(lens)
                }
                let bridge = model(.generateBox(size: [head * 0.28, head * 0.12, head * 0.1]), dark)
                bridge.position = [0, head * 0.22, head * 0.92]
                center.addChild(bridge)
            case let name where name.hasPrefix("hair-"):
                // Real geometry, not a box approximation: the mesh was cut
                // off a roster head that shares its skull with every other,
                // so it lands where it was modelled. Its origin is already
                // the head joint (tools/extract_character_hair.py), which is
                // what `wardrobe` is pinned to — no offset, no guesswork.
                // The police cap came off the same extractor and rides the
                // same origin, so it loads here too — it just takes the hat
                // swatch instead of the hair one.
                guard let mesh = try? await assets.entity(named: name) else { break }
                mesh.name = name
                // The roster's colormap comes along baked in; retint it so
                // hair colour stays a customization axis.
                // ponytail: the cap sits where it was modelled — on a bare
                // skull — so it clips through the tallest hair volumes. Give
                // it the floated `hat` mount if kids pair the two and complain.
                let tint = name == HatStyle.policeCap.modelName ? hatColor : hairColor
                for part in mesh.descendantsAndSelf() {
                    guard var model = part.components[ModelComponent.self] else { continue }
                    model.materials = model.materials.map { _ in tint }
                    part.components.set(model)
                }
                wardrobe.addChild(mesh)
            default:
                break
            }
        }
        if !props(for: profile).isEmpty {
            driver.addChild(wardrobe)
        }
    }

    /// One-time RealityKit registration for the joint-pinning machinery.
    private static let registerOnce: Void = {
        HeadPinComponent.registerComponent()
        HeadPinSystem.registerSystem()
    }()

    private static func model(_ mesh: MeshResource, _ material: PhysicallyBasedMaterial) -> ModelEntity {
        ModelEntity(mesh: mesh, materials: [material])
    }

    private static func color(_ hex: String) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        let rgb = DriverPalette.rgb(hex: hex) ?? SIMD3(1, 1, 1)
        material.baseColor = .init(tint: .init(red: CGFloat(rgb.x), green: CGFloat(rgb.y),
                                               blue: CGFloat(rgb.z), alpha: 1))
        material.metallic = 0.1
        material.roughness = 0.6
        return material
    }
}

/// Marks a wardrobe entity that should ride the rig's Head joint.
struct HeadPinComponent: Component {}

/// Copies the posed Head-joint transform onto every wardrobe each frame,
/// so hats tilt and bob with the animation on all surfaces (race, reaction
/// cam, editor preview) without any per-view code.
final class HeadPinSystem: System {
    private static let query = EntityQuery(where: .has(HeadPinComponent.self))

    init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        for wardrobe in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard let driver = wardrobe.parent,
                  let skinned = Self.skinnedModel(in: driver),
                  let matrix = Self.jointMatrix(of: skinned, jointLeaf: "Head") else { continue }
            wardrobe.setTransformMatrix(matrix, relativeTo: skinned)
            // …but NOT the joint's scale. The roster USDZs wrap the mesh in a
            // `scale_rig` node (×10.73, normalising Kenney's 0.5 m figures to
            // the rig height the props are sized against), so the joint's
            // matrix carries that factor and inflated every hat to ten times
            // the head — a crown hovering over the car instead of on a head.
            wardrobe.scale = .one
        }
    }

    /// Where the posed Head joint actually is, in `reference`'s space (nil =
    /// world). Same joint the hats ride, exposed because the reaction cam
    /// aims its camera here: the boost/crash/cheer clips walk the rig's root,
    /// and a camera pinned to a constant height watched the driver stroll out
    /// of frame — you got their belly, then their hips. Returns nil for a rig
    /// with no skinned mesh or no head, so callers keep a bind-pose fallback.
    static func headPosition(of driver: Entity, relativeTo reference: Entity?) -> SIMD3<Float>? {
        guard let skinned = skinnedModel(in: driver),
              let matrix = jointMatrix(of: skinned, jointLeaf: "Head") else { return nil }
        let local = matrix.columns.3
        return skinned.convert(position: SIMD3(local.x, local.y, local.z), to: reference)
    }

    private static func skinnedModel(in entity: Entity) -> ModelEntity? {
        for child in entity.descendantsAndSelf() {
            if let model = child as? ModelEntity, !model.jointNames.isEmpty { return model }
        }
        return nil
    }

    /// Model-space transform of the joint whose path ends in `jointLeaf`,
    /// composed from the posed local joint transforms along its path.
    /// Case-insensitive: the Quaternius rig names it `…/Head` (Mixamo
    /// style) while the Kenney roster uses a flat lowercase `head`, and a
    /// case-sensitive match silently dropped every hat onto the fallback
    /// bind-pose anchor instead of the animated skull.
    private static func jointMatrix(of model: ModelEntity, jointLeaf: String) -> float4x4? {
        let names = model.jointNames
        guard let index = names.firstIndex(where: {
            $0.split(separator: "/").last
                .map { $0.caseInsensitiveCompare(jointLeaf) == .orderedSame } ?? false
        }) else { return nil }
        let transforms = model.jointTransforms
        guard transforms.count == names.count else { return nil }
        // "A/B/Head" → compose A, then A/B, then the joint itself.
        let path = names[index].split(separator: "/")
        var matrix = matrix_identity_float4x4
        for depth in 1...path.count {
            let prefix = path.prefix(depth).joined(separator: "/")
            guard let i = names.firstIndex(of: prefix) else { return nil }
            matrix *= transforms[i].matrix
        }
        return matrix
    }
}
