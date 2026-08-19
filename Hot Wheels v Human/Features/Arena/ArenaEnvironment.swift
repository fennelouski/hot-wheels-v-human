//
//  ArenaEnvironment.swift
//  Hot Wheels v Human
//
//  The world around the track: a sky dome + a big play-mat ground,
//  themed per track (candy / sunny day / sunset / outer space) so each starter
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

/// Spins a decorative prop about its own Y axis. Coins only, for now —
/// a turning coin reads as "treasure" the way a static one never does,
/// and it's the one prop whose silhouette rewards it.
struct SpinComponent: Component {
    var radiansPerSecond: Float
}

/// Deliberately not an OrbitAnimation: that orbits an entity around a
/// centre, so at radius 0 (a coin spinning where it stands) there's no
/// path to travel and nothing turns.
struct SpinSystem: System {
    private static let query = EntityQuery(where: .has(SpinComponent.self))

    init(scene: Scene) {}

    func update(context: SceneUpdateContext) {
        let dt = Float(context.deltaTime)
        for entity in context.entities(matching: Self.query,
                                       updatingSystemWhen: .rendering) {
            guard let spin = entity.components[SpinComponent.self] else { continue }
            entity.orientation *= simd_quatf(angle: spin.radiansPerSecond * dt,
                                             axis: [0, 1, 0])
        }
    }
}

enum ArenaEnvironment {

    struct Theme {
        let name: String
        /// Kid-facing label + SF Symbol for the builder's world picker.
        let displayName: String
        let symbol: String
        let skyTop: CGColor
        let skyHorizon: CGColor
        let groundLight: CGColor
        let groundDark: CGColor
        let stars: Bool
        let clouds: Bool
        /// Trackside decoration models (Resources/Models3D), scattered
        /// around the track. Repeats weight the draw.
        let props: [String]
        /// City-style placement: props snap to a grid and face the track
        /// instead of landing anywhere at any angle — random yaw makes a
        /// building read as knocked over, not built.
        var structured: Bool = false
        var propCount: Int = 26
        /// Keep-out gap around the track bed. Props place by their CENTER,
        /// so themes with big props (ships, cliffs, grandstands) need more
        /// room or a hull overhangs the racing line.
        var clearance: Float = 0.35
    }

    /// Indexed by trackId byte-sum for tracks with no chosen world —
    /// order matters, don't shuffle (kids remember which track is the
    /// space one). ONLY the first `hashedThemeCount` are auto-dealt;
    /// worlds after that are pick-them-yourself (appending one must not
    /// re-theme every existing track).
    static let hashedThemeCount = 4
    static let themes: [Theme] = [
        Theme(name: "candy", displayName: "Candy", symbol: "birthday.cake.fill",
              skyTop: rgb(0.95, 0.35, 0.62), skyHorizon: rgb(1.0, 0.82, 0.88),
              groundLight: rgb(0.55, 0.80, 0.72), groundDark: rgb(0.45, 0.71, 0.62),
              stars: false, clouds: true,
              props: ["item-banana", "item-box", "item-coin-gold", "item-cone",
                      "food-cupcake", "food-donut", "food-popsicle",
                      "winter-cane-red", "winter-cane-green"]),
        Theme(name: "day", displayName: "Sunny Day", symbol: "sun.max.fill",
              skyTop: rgb(0.25, 0.55, 0.95), skyHorizon: rgb(0.80, 0.93, 1.0),
              groundLight: rgb(0.35, 0.62, 0.32), groundDark: rgb(0.27, 0.52, 0.26),
              stars: false, clouds: true,
              props: ["item-cone", "item-cone", "item-box", "item-banana"]),
        Theme(name: "sunset", displayName: "Sunset", symbol: "sunset.fill",
              skyTop: rgb(0.35, 0.16, 0.45), skyHorizon: rgb(1.0, 0.62, 0.30),
              groundLight: rgb(0.72, 0.58, 0.38), groundDark: rgb(0.62, 0.48, 0.30),
              stars: false, clouds: true,
              props: ["item-cone", "item-cone", "item-box"]),
        Theme(name: "space", displayName: "Space", symbol: "moon.stars.fill",
              skyTop: rgb(0.02, 0.02, 0.10), skyHorizon: rgb(0.16, 0.07, 0.32),
              groundLight: rgb(0.42, 0.38, 0.50), groundDark: rgb(0.34, 0.30, 0.42),
              stars: true, clouds: false,
              props: ["item-coin-gold", "item-coin-gold",
                      "space-speeder-a", "space-speeder-b", "space-racer",
                      "space-meteor", "space-meteor-detailed",
                      "space-crater", "space-crater-large",
                      "space-crystals-a", "space-crystals-b", "space-dish",
                      "space-alien", "space-astronaut-a", "space-astronaut-b"],
              propCount: 36),

        // Pickable worlds (Kenney city/nature kits, converted at 0.3).
        Theme(name: "city", displayName: "Big City", symbol: "building.2.fill",
              skyTop: rgb(0.30, 0.55, 0.90), skyHorizon: rgb(0.84, 0.91, 0.98),
              groundLight: rgb(0.47, 0.47, 0.50), groundDark: rgb(0.40, 0.40, 0.43),
              stars: false, clouds: true,
              props: ["city-shop-a", "city-shop-b", "city-shop-c", "city-shop-d",
                      "city-shop-e", "city-shop-f", "city-shop-g", "city-shop-h",
                      "city-shop-i", "city-shop-j", "city-shop-k", "city-shop-l",
                      "city-shop-m", "city-shop-n",
                      "city-skyscraper-a", "city-skyscraper-b", "city-skyscraper-c",
                      "city-skyscraper-d", "city-skyscraper-e",
                      "city-streetlight", "city-streetlight", "city-planter"],
              structured: true, propCount: 44),
        Theme(name: "town", displayName: "Hometown", symbol: "house.fill",
              skyTop: rgb(0.32, 0.60, 0.95), skyHorizon: rgb(0.84, 0.94, 1.0),
              groundLight: rgb(0.42, 0.66, 0.34), groundDark: rgb(0.34, 0.56, 0.28),
              stars: false, clouds: true,
              props: ["city-house-a", "city-house-b", "city-house-c", "city-house-d",
                      "city-house-e", "city-house-f", "city-house-g", "city-house-h",
                      "city-house-i", "city-house-j", "city-house-k", "city-house-l",
                      "city-house-m", "city-house-n", "city-house-o", "city-house-p",
                      "city-house-q", "city-house-r", "city-house-s", "city-house-t",
                      "city-house-u",
                      "city-tree-large", "city-tree-small", "city-fence"],
              structured: true, propCount: 40),
        Theme(name: "park", displayName: "Park", symbol: "tree.fill",
              skyTop: rgb(0.28, 0.58, 0.90), skyHorizon: rgb(0.82, 0.94, 0.96),
              groundLight: rgb(0.30, 0.58, 0.28), groundDark: rgb(0.24, 0.49, 0.23),
              stars: false, clouds: true,
              // Trees dealt double — the flowers and mushrooms are lovely
              // up close and invisible from the chase cam, so an even draw
              // reads as an empty lawn.
              props: ["park-tree-default", "park-tree-default", "park-tree-oak",
                      "park-tree-oak", "park-tree-palm", "park-tree-detailed",
                      "park-tree-detailed", "city-tree-large",
                      "park-mushroom-red", "park-flower-red",
                      "park-flower-yellow", "park-stump"],
              propCount: 48),
        Theme(name: "speedway", displayName: "Speedway", symbol: "flag.checkered",
              skyTop: rgb(0.28, 0.55, 0.92), skyHorizon: rgb(0.82, 0.90, 0.97),
              groundLight: rgb(0.44, 0.56, 0.38), groundDark: rgb(0.38, 0.49, 0.33),
              stars: false, clouds: true,
              props: ["race-grandstand", "race-grandstand-covered",
                      "race-billboard", "race-banner-tower-red",
                      "race-banner-tower-green", "race-flag-checkers",
                      "race-pylon", "race-pylon", "race-lightpost",
                      "race-pits-garage", "race-pits-office",
                      "race-car-red", "race-car-green"],
              structured: true, propCount: 32, clearance: 0.8),
        Theme(name: "castle", displayName: "Castle", symbol: "crown.fill",
              skyTop: rgb(0.34, 0.52, 0.88), skyHorizon: rgb(0.85, 0.90, 0.95),
              groundLight: rgb(0.38, 0.60, 0.32), groundDark: rgb(0.31, 0.51, 0.27),
              stars: false, clouds: true,
              props: ["castle-tower", "castle-tower", "castle-catapult",
                      "castle-trebuchet", "castle-ballista", "castle-siege-tower",
                      "castle-flag", "castle-flag-wide", "castle-rocks",
                      "castle-tree", "castle-cart", "castle-cart-high",
                      "castle-fountain", "castle-hedge", "castle-lantern"],
              structured: true, propCount: 32, clearance: 0.7),
        Theme(name: "winter", displayName: "Winter", symbol: "snowflake",
              skyTop: rgb(0.55, 0.72, 0.92), skyHorizon: rgb(0.90, 0.95, 1.0),
              groundLight: rgb(0.93, 0.95, 0.98), groundDark: rgb(0.84, 0.88, 0.94),
              stars: false, clouds: true,
              props: ["winter-tree-decorated", "winter-tree-decorated-snow",
                      "winter-tree-a", "winter-tree-b", "winter-tree-c",
                      "winter-snowman", "winter-snowman-hat", "winter-reindeer",
                      "winter-present-a", "winter-present-b", "winter-present-c",
                      "winter-present-d", "winter-cane-red", "winter-cane-green",
                      "winter-nutcracker", "winter-gingerbread-man",
                      "winter-gingerbread-woman", "winter-sled",
                      "winter-snow-pile", "winter-lantern"],
              propCount: 44, clearance: 0.5),
        Theme(name: "pirate", displayName: "Pirate Cove", symbol: "sailboat.fill",
              skyTop: rgb(0.16, 0.55, 0.75), skyHorizon: rgb(0.80, 0.93, 0.94),
              groundLight: rgb(0.89, 0.80, 0.58), groundDark: rgb(0.82, 0.72, 0.50),
              stars: false, clouds: true,
              props: ["pirate-ship-large", "pirate-ship-medium", "pirate-ship-small",
                      "pirate-ship-ghost", "pirate-ship-wreck",
                      "pirate-tower-large", "pirate-tower-small",
                      "pirate-palm-a", "pirate-palm-a", "pirate-palm-b",
                      "pirate-palm-c", "pirate-chest", "pirate-barrel",
                      "pirate-cannon", "pirate-crate", "pirate-rocks-a",
                      "pirate-rocks-b", "pirate-flag"],
              propCount: 30, clearance: 1.0),
        Theme(name: "spooky", displayName: "Spooky", symbol: "moon.haze.fill",
              skyTop: rgb(0.07, 0.04, 0.14), skyHorizon: rgb(0.30, 0.14, 0.36),
              groundLight: rgb(0.24, 0.29, 0.24), groundDark: rgb(0.19, 0.24, 0.19),
              stars: true, clouds: false,
              props: ["spooky-crypt", "spooky-crypt-a", "spooky-grave-round",
                      "spooky-grave-wide", "spooky-grave-cross",
                      "spooky-grave-bevel", "spooky-grave-fancy",
                      "spooky-cross-wood", "spooky-coffin", "spooky-pumpkin",
                      "spooky-pumpkin-tall", "spooky-pine", "spooky-pine-fall",
                      "spooky-lantern", "spooky-lightpost", "spooky-ghost",
                      "spooky-skeleton", "spooky-vampire", "spooky-zombie",
                      "spooky-rocks"],
              propCount: 42),
        Theme(name: "golf", displayName: "Putt-Putt", symbol: "figure.golf",
              skyTop: rgb(0.30, 0.60, 0.92), skyHorizon: rgb(0.84, 0.94, 0.96),
              groundLight: rgb(0.36, 0.70, 0.36), groundDark: rgb(0.30, 0.61, 0.30),
              stars: false, clouds: true,
              props: ["golf-windmill", "golf-windmill", "golf-castle",
                      "golf-gate", "golf-diamond", "golf-triangle",
                      "golf-flag-red", "golf-flag-blue",
                      "golf-ball-red", "golf-ball-blue"],
              propCount: 26),
        Theme(name: "snacks", displayName: "Snack Land", symbol: "fork.knife",
              skyTop: rgb(0.98, 0.62, 0.35), skyHorizon: rgb(1.0, 0.88, 0.72),
              groundLight: rgb(0.94, 0.86, 0.74), groundDark: rgb(0.88, 0.78, 0.64),
              stars: false, clouds: true,
              props: ["food-burger", "food-hotdog", "food-icecream", "food-cone",
                      "food-donut", "food-donut-chocolate", "food-cupcake",
                      "food-cake", "food-pizza", "food-fries", "food-popsicle",
                      "food-sundae", "food-waffle", "food-soda", "food-muffin",
                      "food-pancakes"],
              propCount: 40, clearance: 0.5),
        Theme(name: "construction", displayName: "Construction",
              symbol: "hammer.fill",
              skyTop: rgb(0.30, 0.56, 0.90), skyHorizon: rgb(0.85, 0.90, 0.94),
              groundLight: rgb(0.64, 0.52, 0.38), groundDark: rgb(0.56, 0.45, 0.32),
              stars: false, clouds: true,
              props: ["build-barrier", "build-barrier", "build-cone", "build-cone",
                      "build-fence", "build-light", "build-dumpster", "build-pole",
                      "build-lightpost", "build-sign-stop", "build-pillar",
                      "item-box", "item-box"],
              propCount: 40),
        Theme(name: "camp", displayName: "Campground", symbol: "tent.fill",
              skyTop: rgb(0.24, 0.50, 0.84), skyHorizon: rgb(0.80, 0.90, 0.92),
              groundLight: rgb(0.28, 0.52, 0.26), groundDark: rgb(0.22, 0.44, 0.21),
              stars: false, clouds: true,
              props: ["camp-tent-open", "camp-tent-closed", "camp-tent-small",
                      "camp-fire", "camp-fire-stones", "camp-canoe", "camp-bridge",
                      "camp-bush", "camp-rock", "park-tree-default",
                      "park-tree-default", "park-tree-detailed",
                      "park-tree-detailed", "park-stump"],
              propCount: 40),
        Theme(name: "canyon", displayName: "Canyon", symbol: "mountain.2.fill",
              skyTop: rgb(0.45, 0.42, 0.72), skyHorizon: rgb(1.0, 0.72, 0.45),
              groundLight: rgb(0.80, 0.53, 0.36), groundDark: rgb(0.72, 0.46, 0.30),
              stars: false, clouds: true,
              props: ["canyon-cliff-large", "canyon-cliff", "canyon-mesa",
                      "canyon-cactus-short", "canyon-cactus-short",
                      "canyon-cactus-tall", "canyon-cactus-tall",
                      "canyon-rock-a", "canyon-rock-b", "canyon-rock-c",
                      "park-stump"],
              propCount: 34, clearance: 1.1),
    ]

    static func theme(named name: String?, for trackID: UUID?) -> Theme {
        if let name, let picked = themes.first(where: { $0.name == name }) {
            return picked
        }
        guard let trackID else { return themes[1] }   // lobby default: day
        let sum = withUnsafeBytes(of: trackID.uuid) { bytes in
            bytes.reduce(0) { $0 + Int($1) }
        }
        return themes[sum % hashedThemeCount]
    }

    /// Entity name for change detection — ArenaView rebuilds when the
    /// track OR its chosen world changes (props re-scatter).
    static func name(for trackID: UUID?, theme: String?) -> String {
        "env-\(theme ?? "auto")-\(trackID?.uuidString ?? "lobby")"
    }

    private static let halfPiF = Float.pi / 2
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
    /// `themeName` is the blueprint's picked world; nil falls back to the
    /// trackId hash.
    @MainActor
    static func make(for trackID: UUID?, theme themeName: String? = nil,
                     around footprint: FootprintRect?) async -> Entity {
        let theme = theme(named: themeName, for: trackID)
        let root = Entity()
        root.name = name(for: trackID, theme: themeName)

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

        SpinComponent.registerComponent()
        SpinSystem.registerSystem()

        // Prototype each model once; clone per placement.
        var prototypes: [Entity] = []
        for name in theme.props {
            if let entity = try? await AssetStore.shared.entity(named: name) {
                entity.name = name      // clones inherit it — spots the coins
                prototypes.append(entity)
            }
        }
        guard !prototypes.isEmpty else { return }

        // Structured worlds (city blocks) need more elbow room than loose
        // toy clutter, and buildings can't share a spot the way cones can.
        let ringMargin: Float = theme.structured ? 5.0 : 3.5
        let clearance = max(theme.clearance, theme.structured ? 0.6 : 0.35)
        let gridStep: Float = 0.7       // ≥ widest building footprint
        let halfGround = groundSize / 2 - 1
        var takenCells = Set<SIMD2<Int>>()
        let centerX = (footprint.minX + footprint.maxX) / 2
        let centerZ = (footprint.minZ + footprint.maxZ) / 2
        var placed = 0
        var attempts = 0
        while placed < theme.propCount, attempts < theme.propCount * 4 {
            attempts += 1
            var x = footprint.minX - ringMargin
                + dice.next01() * (footprint.maxX - footprint.minX + 2 * ringMargin)
            var z = footprint.minZ - ringMargin
                + dice.next01() * (footprint.maxZ - footprint.minZ + 2 * ringMargin)
            if theme.structured {
                // Snap to city blocks; one building per cell.
                let cell = SIMD2(Int((x / gridStep).rounded()),
                                 Int((z / gridStep).rounded()))
                guard takenCells.insert(cell).inserted else { continue }
                x = Float(cell.x) * gridStep
                z = Float(cell.y) * gridStep
            }
            let insideTrack = x > footprint.minX - clearance
                && x < footprint.maxX + clearance
                && z > footprint.minZ - clearance
                && z < footprint.maxZ + clearance
            guard !insideTrack, abs(x) < halfGround, abs(z) < halfGround else { continue }
            placed += 1
            let prop = prototypes[Int(dice.next01() * 0.999 * Float(prototypes.count))]
                .clone(recursive: true)
            prop.position = [x, 0, z]
            // Buildings face the track, squared to the street grid; loose
            // clutter lands at any angle.
            let yaw: Float
            if theme.structured {
                let toward: Float = atan2(centerX - x, centerZ - z)
                yaw = (toward / halfPiF).rounded() * halfPiF
            } else {
                yaw = dice.next01() * 2 * .pi
            }
            prop.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0])
            // Coins turn; cones and boxes stay put (a spinning traffic cone
            // reads as a glitch). Varied rate so they don't pulse in unison.
            if prop.name.contains("coin") {
                prop.components.set(SpinComponent(
                    radiansPerSecond: 1.1 + dice.next01() * 0.7))
            }
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
            if theme.clouds { drawClouds(ctx, w: w, h: h) }
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

    /// Puffy clouds, drawn as clusters of overlapping circles in the band
    /// above the horizon. Two lessons carried over from the stars: shapes
    /// must be TENS of pixels across (the chase cam samples a thin v-band
    /// of a texture that wraps the full 360°, so small = never seen), and
    /// u wraps — a cloud near the edge is redrawn a full texture-width to
    /// each side so the seam doesn't slice it in half.
    private static func drawClouds(_ ctx: CGContext, w: Int, h: Int) {
        var dice = Dice(seed: 0xC10D)
        ctx.setFillColor(rgb(1, 1, 1))
        for _ in 0..<22 {
            let cx = CGFloat(dice.next01()) * CGFloat(w)
            // Just above the horizon (0.5 = the dome's equator). The chase
            // cam is pitched DOWN at the cars and only ever samples roughly
            // 0.50–0.62 of the dome, so clouds parked high simply never
            // appear; squaring biases the draw into that band while still
            // dealing a few higher ones for when the camera tilts up.
            let lift = CGFloat(dice.next01())
            let cy = CGFloat(h) * (0.50 + lift * lift * 0.20)
            // Sized to fit INSIDE that band — the first pass used 26–56 and
            // whole clouds overflowed it, reading as a white wash.
            let scale = 16 + CGFloat(dice.next01()) * 14
            // Puffs are precomputed so every wrapped copy is identical.
            let puffs = (0..<6).map { _ in
                (dx: CGFloat(dice.next01()) * 2.6 - 1.3,
                 dy: CGFloat(dice.next01()) * 0.5 - 0.25,
                 r: 0.55 + CGFloat(dice.next01()) * 0.55)
            }
            // One transparency layer per cloud: at plain alpha the puffs
            // would double-darken where they overlap and read as bubbles.
            ctx.setAlpha(0.55 + CGFloat(dice.next01()) * 0.30)
            ctx.beginTransparencyLayer(auxiliaryInfo: nil)
            for wrap in [-CGFloat(w), 0, CGFloat(w)] {
                for puff in puffs {
                    let d = puff.r * scale * 2
                    ctx.fillEllipse(in: CGRect(x: cx + wrap + puff.dx * scale - d / 2,
                                               y: cy + puff.dy * scale - d / 2,
                                               width: d, height: d))
                }
            }
            ctx.endTransparencyLayer()
        }
        ctx.setAlpha(1)
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
