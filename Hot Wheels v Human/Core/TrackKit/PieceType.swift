//
//  PieceType.swift
//  Hot Wheels v Human
//
//  The v1 piece types. Raw values are the wire format (PRD §4 JSON) —
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
    /// Portals come as a pair: drive into `portalIn`'s ring, come out of
    /// `portalOut`'s ring wherever the kid placed it (SegmentSpec.portalX/Z).
    case portalIn
    case portalOut
}
