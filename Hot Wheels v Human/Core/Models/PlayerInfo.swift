//
//  PlayerInfo.swift
//  Hot Wheels v Human
//
//  Who is on the other end of the transport.
//

import Foundation

enum DeviceRole: String, Codable, Sendable {
    case iPad
    case tv
}

struct PlayerInfo: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var deviceRole: DeviceRole
}
