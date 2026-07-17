//
//  CarDesign.swift
//  Hot Wheels v Human
//
//  A kid's car build. Physics numbers live in RaceTuning — these enums
//  only *select* a row there, so tuning never touches saved designs.
//

import Foundation

enum ChassisClass: String, Codable, CaseIterable, Sendable {
    case heavyMuscle
    case balancedFormula
    case superlightDrift

    var mass: Float { RaceTuning.chassisMass[self]! }
    var dragCoefficient: Float { RaceTuning.chassisDrag[self]! }
    var modelName: String { RaceTuning.chassisModelName[self]! }
}

enum TireType: String, Codable, CaseIterable, Sendable {
    case standard
    case slickRacing
    case grippyOffroad

    var staticFriction: Float { RaceTuning.tireStaticFriction[self]! }
    var dynamicFriction: Float { RaceTuning.tireDynamicFriction[self]! }
    var restitution: Float { RaceTuning.tireRestitution[self]! }
}

enum PaintFinish: String, Codable, CaseIterable, Sendable {
    case metallic
    case glossy
    case matte
}

struct PaintSpec: Codable, Equatable, Sendable {
    var colorHex: String      // "#RRGGBB"
    var finish: PaintFinish
}

struct CarDesign: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var chassis: ChassisClass
    var tires: TireType
    var paint: PaintSpec
}
