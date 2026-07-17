//
//  RaceState.swift
//  Hot Wheels v Human
//
//  What the TV broadcasts (RaceSnapshot @10 Hz) and the discrete
//  things that happen (RaceEvent).
//

import Foundation

enum RacePhase: String, Codable, Sendable {
    case lobby
    case collectingDesigns
    case buildingTrack
    case countdown
    case racing
    case paused
    case finished
    case results
}

struct CarSnapshot: Codable, Equatable, Sendable {
    var playerID: UUID
    var progress: Float        // 0…1 along the whole race distance
    var speed: Float           // m/s
    var boostMeter: Float      // 0…1
    var livesLeft: Int
    var lane: Int              // 0 = left, 1 = right
}

struct RaceSnapshot: Codable, Equatable, Sendable {
    var raceClock: TimeInterval
    var phase: RacePhase
    var cars: [CarSnapshot]
}

enum RaceEvent: Codable, Equatable, Sendable {
    case countdownTick(Int)                              // 3, 2, 1, 0 = GO
    case carDestroyed(playerID: UUID)
    case respawned(playerID: UUID)
    case finished(playerID: UUID, time: TimeInterval)
    case blueprintRejected(reason: String)
}
