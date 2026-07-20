//
//  CarDesign.swift
//  Hot Wheels v Human
//
//  A kid's car build. Physics numbers live in RaceTuning — these enums
//  only *select* a row there, so tuning never touches saved designs.
//

import Foundation

nonisolated enum ChassisClass: String, Codable, CaseIterable, Sendable {
    case heavyMuscle
    case balancedFormula
    case superlightDrift

    var mass: Float { RaceTuning.chassisMass[self]! }
    var dragCoefficient: Float { RaceTuning.chassisDrag[self]! }
    var modelName: String { RaceTuning.chassisModelName[self]! }
}

nonisolated enum TireType: String, Codable, CaseIterable, Sendable {
    case standard
    case slickRacing
    case grippyOffroad

    var staticFriction: Float { RaceTuning.tireStaticFriction[self]! }
    var dynamicFriction: Float { RaceTuning.tireDynamicFriction[self]! }
    var restitution: Float { RaceTuning.tireRestitution[self]! }
}

nonisolated enum PaintFinish: String, Codable, CaseIterable, Sendable {
    case metallic
    case glossy
    case matte
    case sparkle   // metallic + high-frequency normal noise (glitter paint)
}

/// Paint slot names for `CarDesign.partColors`. The Kenney chassis models
/// are one shared material but distinct meshes: wheels are "wheel_*", the
/// body mesh carries the model's name ("body", "vehicle_racer", …).
/// Unrecognized parts paint as body so new models never come out untinted.
nonisolated enum CarPaintSlot {
    static let body = "body"
    static let wheels = "wheels"

    static func slot(forPartName name: String) -> String {
        name.hasPrefix("wheel") ? wheels : body
    }
}

nonisolated struct PaintSpec: Codable, Equatable, Sendable {
    var colorHex: String      // "#RRGGBB"
    var finish: PaintFinish
}

nonisolated enum LiveryPattern: String, Codable, CaseIterable, Sendable {
    case racingStripes
    case flames
    case polkaDots
    case lightningBolt
    case checkerboard
    case starField
    case zigzag
}

nonisolated struct LiverySpec: Codable, Equatable, Sendable {
    var pattern: LiveryPattern
    var colorHex: String      // "#RRGGBB"
    var scale: Float          // 0.5…2, pattern-relative size
}

/// One stamped sticker on the paint shell. `symbol` is an SF Symbol name,
/// or a custom-drawn id like "skull" (OverlayComposer special-cases those).
nonisolated struct StickerPlacement: Codable, Equatable, Sendable {
    var symbol: String
    var uv: SIMD2<Float>      // shell UV, (0,0) = nose bottom
    var scale: Float          // 1 = default size
    var rotation: Float       // radians, counterclockwise
    var colorHex: String
}

nonisolated struct CarDesign: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var chassis: ChassisClass
    var tires: TireType
    var paint: PaintSpec
    /// AI roster cars use a specific model (kart-*) instead of the chassis
    /// default. Optional so old saved designs keep decoding.
    var modelOverride: String? = nil
    /// Per-part color overrides, `CarPaintSlot` name → "#RRGGBB". Missing
    /// slot falls back to `paint.colorHex`. Optional → old designs decode.
    var partColors: [String: String]? = nil
    /// Livery pattern rendered onto the paint shell. Optional → old designs decode.
    var livery: LiverySpec? = nil
    /// Stickers stamped on the paint shell. Optional → old designs decode.
    var stickers: [StickerPlacement]? = nil
    /// Freehand drawing, PNG ≤ 200 KB (downscaled until it fits), rendered
    /// as the bottom overlay layer. Optional → old designs decode.
    var drawingPNG: Data? = nil
    /// The PencilKit strokes behind drawingPNG (`PKDrawing` data), kept so
    /// a reopened design stays stroke-editable. Skipped when over 200 KB —
    /// the PNG still renders. Optional → old designs decode.
    var drawingStrokes: Data? = nil
    /// Face paint drawn on the driver, PNG ≤ 64 KB, composited over the
    /// reaction-cam face. Superseded by DriverProfile.faceDrawingPNG — kept
    /// as a read fallback so old designs keep their face paint.
    var faceDrawingPNG: Data? = nil
    /// The character riding in this car. Stamped in by AppModel at race time
    /// so the driver travels the wire inside the design — no new message
    /// cases. Optional → old designs/peers decode.
    var driver: DriverProfile? = nil

    /// The USDZ this car renders as: the picked body, else the chassis
    /// class's default. Preview and race both read THIS — reading
    /// `chassis.modelName` directly is how the turntable used to show a
    /// different car than the one that raced.
    var modelName: String { modelOverride ?? chassis.modelName }
}
