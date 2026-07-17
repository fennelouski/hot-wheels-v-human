//
//  MatchConfig.swift
//  Hot Wheels v Human
//

import Foundation

nonisolated enum GameMode: String, Codable, Sendable {
    case solo
    case onePlayer
    case twoPlayer
    case test
}

nonisolated enum AIDifficulty: String, Codable, Sendable {
    case easy
    case medium
    case hard
}

nonisolated struct MatchConfig: Codable, Equatable, Sendable {
    var mode: GameMode
    var laps: Int
    var lives: Int
    var aiDifficulty: AIDifficulty?

    init(mode: GameMode, laps: Int = 1, lives: Int = RaceTuning.defaultLives, aiDifficulty: AIDifficulty? = nil) {
        self.mode = mode
        self.laps = laps
        self.lives = lives
        self.aiDifficulty = aiDifficulty
    }
}
