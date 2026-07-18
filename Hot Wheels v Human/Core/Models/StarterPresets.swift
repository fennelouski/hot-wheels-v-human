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

    /// Starter tracks, easiest first. Names are kid-picked-sounding on
    /// purpose. All sprints except Dizzy Doughnut (closed circuit).
    static let presets: [(name: String, blueprint: TrackBlueprint)] = [
        ("Rocket Ribbon", preset(1, [.startGate, .straight, .straight, .loop, .straight, .finishGate])),
        ("Wiggle Worm", preset(2, [.startGate, .curve90L, .curve90R, .curve90R, .curve90L, .straight, .finishGate])),
        ("Mount Kaboom", preset(3, [.startGate, .hillUp, .straight, .bump, .hillDown, .straight, .finishGate])),
        ("Dizzy Doughnut", preset(4, [.startGate, .straight, .curve90R, .straight, .curve90R,
                                      .straight, .straight, .curve90R, .straight, .curve90R])),
        ("Loopy Louie", preset(5, [.startGate, .straight, .loop, .straight, .loop, .straight, .finishGate])),
        ("Jumpy Junction", preset(6, [.startGate, .straight, .rampJump, .straight, .curve90L, .straight, .finishGate])),
    ]

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
    ]

    private static func preset(_ n: Int, _ name: String, chassis: ChassisClass, tires: TireType,
                               paint: PaintSpec, partColors: [String: String],
                               livery: LiverySpec, stickers: [StickerPlacement]) -> CarDesign {
        CarDesign(id: UUID(uuidString: String(format: "CA900000-0000-0000-0000-%012d", n))!,
                  name: name, chassis: chassis, tires: tires, paint: paint,
                  partColors: partColors, livery: livery, stickers: stickers)
    }
}
