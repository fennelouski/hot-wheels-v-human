//
//  PieceType.swift
//  Hot Wheels v Human
//
//  The 11 v1 piece types. Raw values are the wire format (PRD §4 JSON) —
//  never rename a case without bumping gameProtocolVersion.
//

nonisolated enum PieceType: String, Codable, CaseIterable, Sendable {
    case startGate
    case finishGate
    case straight
    case curve90L
    case curve90R
    case curveLarge
    case hillUp
    case hillDown
    case bump
    case loop
    case rampJump
}
