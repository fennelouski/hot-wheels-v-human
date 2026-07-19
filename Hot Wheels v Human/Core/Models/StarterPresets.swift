//
//  StarterPresets.swift
//  Hot Wheels v Human
//
//  Built-in starter content: preset tracks and preset cars so a kid who
//  just opened the app has something fun to race immediately. Fixed UUIDs
//  (PR90/CA90 prefixes) so selection identity is stable across launches.
//  Every track must pass BlueprintValidator — unit-tested in
//  StarterPresetTests, so a bad edit here fails CI, not a kid.
//

import Foundation

extension TrackBlueprint {

    /// The launch lineup: 7 ready-to-race tracks, shortest first
    /// (20 → 75 pieces), every track from #3 on has a loop or a jump.
    /// All serpentine sprints — rows of straights joined by U-turns, so
    /// rows sit 0.8 m apart and can never overlap (validator-proof by
    /// construction, still unit-tested). Names are kid-picked-sounding
    /// on purpose. Piece counts are asserted in StarterPresetTests.
    static let presets: [(name: String, blueprint: TrackBlueprint)] = [
        ("Wiggle Worm", preset(1, wiggleWorm)),          // 20 — flat & friendly
        ("Mount Kaboom", preset(2, mountKaboom)),        // 27 — first hills
        ("Loopy Louie", preset(3, loopyLouie)),          // 35 — first loop
        ("Jumpy Junction", preset(4, jumpyJunction)),    // 42 — ramp jumps
        ("Loop-de-Leap", preset(5, loopDeLeap)),         // 50 — loops AND jumps
        ("Thunder Mountain", preset(6, thunderMountain)),// 60 — two-level climb
        ("The Mega Mega Track", preset(7, megaMega)),    // 75 — everything
    ]

    // MARK: Track recipes

    private static func straights(_ n: Int) -> [PieceType] {
        Array(repeating: .straight, count: n)
    }
    /// U-turns: two same-way 90° corners flip the heading and step the
    /// serpentine sideways one row (0.8 m). Alternate R, L, R, … so the
    /// track always snakes into fresh ground.
    private static let uTurnR: [PieceType] = [.curve90R, .curve90R]
    private static let uTurnL: [PieceType] = [.curve90L, .curve90L]

    private static let wiggleWorm: [PieceType] = [.startGate]           // 20
        + straights(2) + [.bump] + straights(3)
        + uTurnR
        + straights(3) + [.bump] + straights(2)
        + uTurnL
        + straights(2)
        + [.finishGate]

    private static let mountKaboom: [PieceType] = [.startGate]          // 27
        + [.straight, .hillUp, .straight, .hillDown, .straight, .bump, .straight]
        + uTurnR
        + straights(2) + [.hillUp, .straight, .hillDown] + straights(2)
        + uTurnL
        + [.straight, .bump, .straight, .bump, .straight, .bump, .straight]
        + [.finishGate]

    private static let loopyLouie: [PieceType] = [.startGate]           // 35
        + straights(2) + [.hillUp, .bump, .hillDown] + straights(3)
        + uTurnR
        + straights(3) + [.loop] + straights(4)
        + uTurnL
        + straights(2) + [.bump] + straights(2) + [.bump] + straights(2)
        + uTurnR
        + straights(3)
        + [.finishGate]

    private static let jumpyJunction: [PieceType] = [.startGate]        // 42
        + straights(3) + [.rampJump] + straights(5)
        + uTurnR
        + straights(2) + [.hillUp] + straights(3) + [.hillDown] + straights(2)
        + uTurnL
        + straights(4) + [.rampJump] + straights(4)
        + uTurnR
        + straights(3) + [.bump] + straights(3)
        + [.finishGate]

    private static let loopDeLeap: [PieceType] = [.startGate]           // 50
        + straights(4) + [.loop] + straights(6)
        + uTurnR
        + straights(2) + [.hillUp] + straights(4) + [.hillDown] + straights(2)
        + uTurnL
        + straights(3) + [.loop] + straights(6)
        + uTurnR
        + straights(2) + [.rampJump] + straights(5) + [.bump] + straights(2)
        + [.finishGate]

    private static let thunderMountain: [PieceType] = [.startGate]      // 60
        + straights(2) + [.hillUp] + straights(2) + [.hillUp] + straights(2)
        + [.hillDown, .straight, .hillDown, .straight]
        + uTurnR
        + straights(4) + [.loop] + straights(7)
        + uTurnL
        + straights(2) + [.rampJump] + straights(2) + [.bump] + straights(2)
        + [.bump] + straights(3)
        + uTurnR
        + straights(3) + [.hillUp] + straights(4) + [.hillDown] + straights(3)
        + uTurnL
        + straights(2)
        + [.finishGate]

    private static let megaMega: [PieceType] = [.startGate]             // 75
        + straights(3) + [.hillUp] + straights(2) + [.bump] + straights(2)
        + [.hillDown] + straights(3)
        + uTurnR
        + straights(5) + [.loop] + straights(7)
        + uTurnL
        + straights(2) + [.hillUp, .straight, .hillUp] + straights(2)
        + [.hillDown, .straight, .hillDown] + straights(3)
        + uTurnR
        + straights(4) + [.loop] + straights(8)
        + uTurnL
        + straights(3) + [.rampJump] + straights(2) + [.bump] + straights(2)
        + [.bump] + straights(3)
        + [.finishGate]

    private static func preset(_ n: Int, _ types: [PieceType]) -> TrackBlueprint {
        TrackBlueprint(
            trackId: UUID(uuidString: String(format: "90000000-0000-0000-0000-%012d", n))!,
            lanes: 2,
            segments: types.enumerated().map { SegmentSpec(index: $0.offset, type: $0.element) })
    }
}

extension CarDesign {

    /// Starter cars — each one shows off a different slice of the
    /// customization stack (per-part colors, liveries, stickers, finishes)
    /// so the garage doubles as a "look what you can make" gallery.
    static let presets: [CarDesign] = [
        preset(1, "Fire Chief", chassis: .heavyMuscle, tires: .grippyOffroad,
               paint: PaintSpec(colorHex: "#D62718", finish: .glossy),
               partColors: [CarPaintSlot.wheels: "#FFD500"],
               livery: LiverySpec(pattern: .flames, colorHex: "#FF9500", scale: 1.2),
               stickers: [StickerPlacement(symbol: "flame.fill", uv: [0.65, 0.45],
                                           scale: 1.1, rotation: 0, colorHex: "#FFD500")]),
        preset(2, "Banana Bolt", chassis: .superlightDrift, tires: .slickRacing,
               paint: PaintSpec(colorHex: "#FFD500", finish: .metallic),
               partColors: [CarPaintSlot.wheels: "#7A4A21"],
               livery: LiverySpec(pattern: .lightningBolt, colorHex: "#F2F2F7", scale: 1),
               stickers: [StickerPlacement(symbol: "bolt.fill", uv: [0.4, 0.5],
                                           scale: 1.2, rotation: 0.2, colorHex: "#2266FF")]),
        preset(3, "Disco Nova", chassis: .balancedFormula, tires: .slickRacing,
               paint: PaintSpec(colorHex: "#8E44AD", finish: .sparkle),
               partColors: [CarPaintSlot.wheels: "#FF2D95"],
               livery: LiverySpec(pattern: .polkaDots, colorHex: "#FF2D95", scale: 0.8),
               stickers: [StickerPlacement(symbol: "star.fill", uv: [0.3, 0.4],
                                           scale: 0.9, rotation: -0.3, colorHex: "#FFD500"),
                          StickerPlacement(symbol: "star.fill", uv: [0.7, 0.55],
                                           scale: 0.7, rotation: 0.4, colorHex: "#FFD500")]),
        preset(4, "Checker Champ", chassis: .balancedFormula, tires: .standard,
               paint: PaintSpec(colorHex: "#F2F2F7", finish: .matte),
               partColors: [CarPaintSlot.wheels: "#1C1C1E"],
               livery: LiverySpec(pattern: .checkerboard, colorHex: "#1C1C1E", scale: 1),
               stickers: [StickerPlacement(symbol: "1.circle.fill", uv: [0.55, 0.42],
                                           scale: 1.3, rotation: 0, colorHex: "#D62718")]),
        preset(5, "Sea Monster", chassis: .heavyMuscle, tires: .grippyOffroad,
               paint: PaintSpec(colorHex: "#0E7C6B", finish: .metallic),
               partColors: [CarPaintSlot.wheels: "#0A3D34"],
               livery: LiverySpec(pattern: .zigzag, colorHex: "#7FE7D2", scale: 1.4),
               stickers: [StickerPlacement(symbol: "skull", uv: [0.5, 0.45],
                                           scale: 1, rotation: 0, colorHex: "#F2F2F7")]),
        preset(6, "Star Captain", chassis: .superlightDrift, tires: .standard,
               paint: PaintSpec(colorHex: "#1B2A6B", finish: .sparkle),
               partColors: [CarPaintSlot.wheels: "#FFD500"],
               livery: LiverySpec(pattern: .starField, colorHex: "#FFD500", scale: 1),
               stickers: [StickerPlacement(symbol: "moon.stars.fill", uv: [0.62, 0.4],
                                           scale: 1.1, rotation: 0.15, colorHex: "#F2F2F7")]),
        preset(7, "Zebra Zoom", chassis: .balancedFormula, tires: .slickRacing,
               paint: PaintSpec(colorHex: "#1C1C1E", finish: .glossy),
               partColors: [CarPaintSlot.wheels: "#F2F2F7"],
               livery: LiverySpec(pattern: .racingStripes, colorHex: "#F2F2F7", scale: 1),
               stickers: [StickerPlacement(symbol: "pawprint.fill", uv: [0.6, 0.45],
                                           scale: 1, rotation: 0.2, colorHex: "#F2F2F7")]),
        preset(8, "Tiger Turbo", chassis: .heavyMuscle, tires: .grippyOffroad,
               paint: PaintSpec(colorHex: "#FF9500", finish: .glossy),
               partColors: [CarPaintSlot.wheels: "#1C1C1E"],
               livery: LiverySpec(pattern: .zigzag, colorHex: "#1C1C1E", scale: 1.2),
               stickers: [StickerPlacement(symbol: "hare.fill", uv: [0.55, 0.42],
                                           scale: 1.1, rotation: 0, colorHex: "#FFD500")]),
        preset(9, "Bubblegum Blast", chassis: .superlightDrift, tires: .slickRacing,
               paint: PaintSpec(colorHex: "#FF2D95", finish: .glossy),
               partColors: [CarPaintSlot.wheels: "#F2F2F7"],
               livery: LiverySpec(pattern: .polkaDots, colorHex: "#F2F2F7", scale: 1.1),
               stickers: [StickerPlacement(symbol: "heart.fill", uv: [0.45, 0.5],
                                           scale: 1.2, rotation: -0.2, colorHex: "#D62718")]),
        preset(10, "Robo Racer", chassis: .balancedFormula, tires: .standard,
               paint: PaintSpec(colorHex: "#8E8E93", finish: .metallic),
               partColors: [CarPaintSlot.wheels: "#1C1C1E"],
               livery: LiverySpec(pattern: .lightningBolt, colorHex: "#5AC8FA", scale: 1),
               stickers: [StickerPlacement(symbol: "gearshape.fill", uv: [0.6, 0.4],
                                           scale: 1.1, rotation: 0.3, colorHex: "#1C1C1E")]),
    ]

    private static func preset(_ n: Int, _ name: String, chassis: ChassisClass, tires: TireType,
                               paint: PaintSpec, partColors: [String: String],
                               livery: LiverySpec, stickers: [StickerPlacement]) -> CarDesign {
        CarDesign(id: UUID(uuidString: String(format: "CA900000-0000-0000-0000-%012d", n))!,
                  name: name, chassis: chassis, tires: tires, paint: paint,
                  partColors: partColors, livery: livery, stickers: stickers)
    }
}

extension DriverProfile {

    /// Starter characters — every color comes from DriverPalette (unit-tested)
    /// and together they show off hair styles, hats, and glasses so the
    /// character-select screen doubles as a "look what you can make" gallery.
    static let presets: [DriverProfile] = [
        preset(1, "Ace", skin: "#E0AC69", hair: .short, hairColor: "#1C1C1E",
               eyes: "#3B2716", shirt: "#FFD500", pants: "#2266FF",
               helmet: "#FF3B30", hat: HatStyle.none, hatColor: "#FF3B30", glasses: GlassesStyle.none),
        preset(2, "Nova", skin: "#FFDBB4", hair: .long, hairColor: "#E7C87B",
               eyes: "#2266FF", shirt: "#8E44AD", pants: "#1C1C1E",
               helmet: "#FFD500", hat: HatStyle.none, hatColor: "#FFD500", glasses: .star),
        preset(3, "Juno", skin: "#8D5524", hair: .curly, hairColor: "#1C1C1E",
               eyes: "#3B2716", shirt: "#34C759", pants: "#FFD500",
               helmet: "#2266FF", hat: .cap, hatColor: "#2266FF", glasses: GlassesStyle.none),
        preset(4, "Bolt", skin: "#C68642", hair: .bald, hairColor: "#1C1C1E",
               eyes: "#34C759", shirt: "#FF3B30", pants: "#F2F2F7",
               helmet: "#F2F2F7", hat: .crown, hatColor: "#FFD500", glasses: GlassesStyle.none),
        preset(5, "Pip", skin: "#F1C27D", hair: .short, hairColor: "#D62718",
               eyes: "#5AC8FA", shirt: "#FF9500", pants: "#34C759",
               helmet: "#34C759", hat: .headphones, hatColor: "#1C1C1E", glasses: .round),
    ]

    private static func preset(_ n: Int, _ name: String, skin: String, hair: HairStyle,
                               hairColor: String, eyes: String, shirt: String, pants: String,
                               helmet: String, hat: HatStyle, hatColor: String,
                               glasses: GlassesStyle) -> DriverProfile {
        DriverProfile(id: UUID(uuidString: String(format: "DA900000-0000-0000-0000-%012d", n))!,
                      name: name, helmetColorHex: helmet, suitColorHex: shirt,
                      skinToneHex: skin, hair: hair, hairColorHex: hairColor,
                      eyeColorHex: eyes, pantsColorHex: pants, hat: hat,
                      hatColorHex: hatColor, glasses: glasses)
    }
}
