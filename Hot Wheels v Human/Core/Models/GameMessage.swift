//
//  GameMessage.swift
//  Hot Wheels v Human
//
//  The one Codable envelope on the wire (PRD §4). Every case round-trips
//  in ModelTests — the JSON shape is the protocol, keep it stable.
//

import Foundation

/// Bump when a wire-breaking change ships. `hello` carries it for forward compat.
let gameProtocolVersion = 1

enum GameMessage: Codable, Equatable, Sendable {
    // reliable
    case hello(PlayerInfo, protocolVersion: Int)
    case trackBlueprint(TrackBlueprint)
    case carDesign(CarDesign)
    case matchConfig(MatchConfig)
    case readyState(playerID: UUID, ready: Bool)
    case raceEvent(RaceEvent)
    // unreliable, high-frequency
    case boost(playerID: UUID, token: UUID)
    case reactionCam(playerID: UUID, on: Bool)
    case raceSnapshot(RaceSnapshot)
}

extension GameMessage {
    /// Encoded form for the transport. JSON: small payloads, debuggable in logs.
    func encoded() throws -> Data { try JSONEncoder().encode(self) }
    static func decoded(from data: Data) throws -> GameMessage {
        try JSONDecoder().decode(GameMessage.self, from: data)
    }
}
