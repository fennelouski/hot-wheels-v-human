//
//  ArenaEnvironment.swift
//  Hot Wheels v Human
//
//  The world around the track: a sky dome + a big play-mat ground,
//  themed per track (sunny day / sunset / outer space) so each starter
//  track feels like its own place. Theme is picked from the trackId —
//  stable across launches, no data added to the wire format.
//
//  Everything is procedural (CoreGraphics → TextureResource): no new
//  assets, identical on iPad and TV. Sizes are visual-only constants —
//  the ground must outsize the biggest buildable track (75 straights
//  = 60 m) so cars never race off the edge of the world.
//

import CoreGraphics
import Foundation
import RealityKit

enum ArenaEnvironment {

    struct Theme {
        let name: String
        let skyTop: CGColor
        let skyHorizon: CGColor
        let groundLight: CGColor
        let groundDark: CGColor
        let stars: Bool
        /// Trackside decoration models (Resources/Models3D), scattered
        /// around the track. Repeats weight the draw.
        let props: [String]
    }

    /// Indexed by trackId byte-sum — order matters, don't shuffle
    /// (kids remember which track is the space one).
    static let themes: [Theme] = [
        Theme(name: "candy",
              skyTop: rgb(0.95, 0.35, 0.62), skyHorizon: rgb(1.0, 0.82, 0.88),
              groundLight: rgb(0.55, 0.80, 0.72), groundDark: rgb(0.45, 0.71, 0.62),
              stars: false,
              props: ["item-banana", "item-box", "item-coin-gold", "item-cone"]),
        Theme(name: "day",
              skyTop: rgb(0.25, 0.55, 0.95), skyHorizon: rgb(0.80, 0.93, 1.0),
              groundLight: rgb(0.35, 0.62, 0.32), groundDark: rgb(0.27, 0.52, 0.26),
              stars: false,
              props: ["item-cone", "item-cone", "item-box", "item-banana"]),
        Theme(name: "sunset",
              skyTop: rgb(0.35, 0.16, 0.45), skyHorizon: rgb(1.0, 0.62, 0.30),
              groundLight: rgb(0.72, 0.58, 0.38), groundDark: rgb(0.62, 0.48, 0.30),
              stars: false,
              props: ["item-cone", "item-cone", "item-box"]),
        Theme(name: "space",
              skyTop: rgb(0.02, 0.02, 0.10), skyHorizon: rgb(0.16, 0.07, 0.32),
              groundLight: rgb(0.42, 0.38, 0.50), groundDark: rgb(0.34, 0.30, 0.42),
              stars: true,
              props: ["item-coin-gold", "item-coin-gold", "item-box"]),
    ]

    static func theme(for trackID: UUID?) -> Theme {
        guard let trackID else { return themes[1] }   // lobby default: day
        let sum = withUnsafeBytes(of: trackID.uuid) { bytes in
            bytes.reduce(0) { $0 + Int($1) }
        }
        return themes[sum % themes.count]
    }

    /// Entity name for change detection — ArenaView rebuilds when the
    /// track changes (props re-scatter around the new footprint).
    static func name(for trackID: UUID?) -> String {
        "env-\(trackID?.uuidString ?? "lobby")"
    }

    private static let groundSize: Float = 90
    private static let skyRadius: Float = 70
    /// Texture repeats across the ground: 4 m per repeat, 2×2 checks each
    /// → 2 m play-mat squares.
    private static let groundTiles: Float = 22.5

    /// Seeded LCG — same track, same world, every launch.
    private struct Dice {
        var seed: UInt64
        mutating func next01() -> Float {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            // >> 32 keeps 32 bits — >> 33 gave [0, 0.5) and left half
            // the dome starless.
            return Float(seed >> 32) / Float(UInt32.max)
        }
    }

    /// Sky dome + ground plane (with the arena's static collision floor)
    /// + decorative props scattered clear of `footprint` (the track).
    @MainActor
    static func make(for trackID: UUID?, around footprint: FootprintRect?) async -> Entity {
        let theme = theme(for: trackID)
        let root = Entity()
        root.name = name(for: trackID)

        let ground = ModelEntity(
            mesh: .generatePlane(width: groundSize, depth: groundSize),
            materials: [await groundMaterial(theme)])
        ground.position.y = -0.03
        ground.collision = CollisionComponent(
            shapes: [.generateBox(width: groundSize, height: 0.01, depth: groundSize)])
        ground.physicsBody = PhysicsBodyComponent(mode: .static)
        root.addChild(ground)

        var skyMaterial = UnlitMaterial()
        if let image = skyImage(theme),
           let texture = try? await TextureResource(
               image: image, options: .init(semantic: .color)) {
            skyMaterial.color = .init(texture: .init(texture))
        }
        let sky = ModelEntity(mesh: .generateSphere(radius: skyRadius),
                              materials: [skyMaterial])
        // Negative x-scale flips the winding so the inside faces render.
        sky.scale = [-1, 1, 1]
        root.addChild(sky)

        await scatterProps(theme: theme, trackID: trackID,
                           around: footprint, into: root)
        return root
    }

    /// Toy clutter around the track: sampled in a ring just outside the
    /// track's footprint, rejected if inside it. Decoration only — no
    /// collision, so a flung car sails through instead of pinballing.
    @MainActor
    private static func scatterProps(theme: Theme, trackID: UUID?,
                                     around footprint: FootprintRect?,
                                     into root: Entity) async {
        guard let footprint, !theme.props.isEmpty else { return }
        let trackSeed = trackID.map { id in
            withUnsafeBytes(of: id.uuid) { $0.reduce(0) { $0 &* 31 &+ Int($1) } }
        } ?? 0
        var dice = Dice(seed: 0xD1CE &+ UInt64(truncatingIfNeeded: trackSeed))

        // Prototype each model once; clone per placement.
        var prototypes: [Entity] = []
        for name in theme.props {
            if let entity = try? await AssetStore.shared.entity(named: name) {
                prototypes.append(entity)
            }
        }
        guard !prototypes.isEmpty else { return }

        let ringMargin: Float = 3.5     // how far past the track props reach
        let clearance: Float = 0.35     // keep-out gap around the track bed
        let halfGround = groundSize / 2 - 1
        for _ in 0..<26 {
            let x = footprint.minX - ringMargin
                + dice.next01() * (footprint.maxX - footprint.minX + 2 * ringMargin)
            let z = footprint.minZ - ringMargin
                + dice.next01() * (footprint.maxZ - footprint.minZ + 2 * ringMargin)
            let insideTrack = x > footprint.minX - clearance
                && x < footprint.maxX + clearance
                && z > footprint.minZ - clearance
                && z < footprint.maxZ + clearance
            guard !insideTrack, abs(x) < halfGround, abs(z) < halfGround else { continue }
            let prop = prototypes[Int(dice.next01() * 0.999 * Float(prototypes.count))]
                .clone(recursive: true)
            prop.position = [x, 0, z]
            prop.orientation = simd_quatf(angle: dice.next01() * 2 * .pi, axis: [0, 1, 0])
            root.addChild(prop)
        }
    }

    // MARK: Materials

    @MainActor
    private static func groundMaterial(_ theme: Theme) async -> any RealityKit.Material {
        var material = PhysicallyBasedMaterial()
        material.roughness = 1.0     // play mat, not a showroom floor
        material.metallic = 0.0
        if let image = checkerImage(theme),
           let texture = try? await TextureResource(
               image: image, options: .init(semantic: .color)) {
            material.baseColor = .init(texture: .init(texture))
            material.textureCoordinateTransform = .init(
                scale: [groundTiles, groundTiles])
        }
        return material
    }

    // MARK: Procedural images

    /// Vertical gradient, horizon color at the equator; stars stamped on
    /// the space theme with a seeded LCG so every launch has the same sky.
    private static func skyImage(_ theme: Theme) -> CGImage? {
        // Wide: u wraps the full 360° dome, so 64 px would stretch a 1 px
        // star into a metres-wide invisible smear.
        let w = 1024, h = 512
        return draw(width: w, height: h) { ctx in
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                // CG y-up: image bottom (y 0) is the dome's lower half —
                // horizon color there, deep sky at the top.
                colors: [theme.skyHorizon, theme.skyHorizon, theme.skyTop] as CFArray,
                locations: [0.0, 0.45, 0.9]) else { return }
            ctx.drawLinearGradient(gradient,
                                   start: CGPoint(x: 0, y: 0),
                                   end: CGPoint(x: 0, y: CGFloat(h)),
                                   options: [])
            guard theme.stars else { return }
            var dice = Dice(seed: 0x5EED)
            ctx.setFillColor(rgb(1, 1, 0.92))
            // Whole dome, dense and chunky: the chase cam grazes the sky,
            // so one frame only samples a thin v-band of this texture —
            // sparse or small stars simply never land in view.
            for _ in 0..<1400 {
                let x = CGFloat(dice.next01()) * CGFloat(w)
                let y = CGFloat(dice.next01()) * CGFloat(h)
                let r = 2.0 + CGFloat(dice.next01()) * 2.5
                ctx.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
            }
        }
    }

    /// 2×2 low-contrast checker — reads as a giant play mat when tiled.
    private static func checkerImage(_ theme: Theme) -> CGImage? {
        let size = 64
        return draw(width: size, height: size) { ctx in
            let half = CGFloat(size) / 2
            ctx.setFillColor(theme.groundLight)
            ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
            ctx.setFillColor(theme.groundDark)
            ctx.fill(CGRect(x: 0, y: 0, width: half, height: half))
            ctx.fill(CGRect(x: half, y: half, width: half, height: half))
        }
    }

    private static func draw(width: Int, height: Int,
                             _ body: (CGContext) -> Void) -> CGImage? {
        guard let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        body(ctx)
        return ctx.makeImage()
    }

    private static func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGColor {
        CGColor(red: r, green: g, blue: b, alpha: 1)
    }
}
