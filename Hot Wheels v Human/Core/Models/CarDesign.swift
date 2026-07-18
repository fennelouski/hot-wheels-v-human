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
}
