//
//  MessageCodec.swift
//  Hot Wheels v Human
//
//  Single place for the wire format. Every payload is an Envelope with a
//  monotonic sequence number; receivers drop stale RaceSnapshots (they
//  arrive unreliably and can be reordered).
//

import Foundation

nonisolated struct MessageEnvelope: Codable, Sendable {
    var seq: UInt32
    var message: GameMessage
}

/// One per transport endpoint. Not thread-safe by itself — transports own
/// one and touch it from their isolation only.
nonisolated final class MessageCodec {
    enum PayloadError: Error { case tooLarge, invalidShare }
    private var nextSeq: UInt32 = 0
    private var lastSnapshotSeq: UInt32 = 0
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func encode(_ message: GameMessage) throws -> Data {
        if case .raceShare(let payload) = message, !payload.isValid { throw PayloadError.invalidShare }
        nextSeq &+= 1
        return try encoder.encode(MessageEnvelope(seq: nextSeq, message: message))
    }

    /// Returns nil for stale snapshots (newer one already seen).
    func decode(_ data: Data) throws -> GameMessage? {
        // Preserve existing large drawing/photo messages. The new image
        // handoff alone is bounded before JSONDecoder expands its Base64 data.
        if data.count > 3_000_000,
           let envelope = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = envelope["message"] as? [String: Any], message["raceShare"] != nil {
            throw PayloadError.tooLarge
        }
        let envelope = try decoder.decode(MessageEnvelope.self, from: data)
        if case .raceShare(let payload) = envelope.message, !payload.isValid { throw PayloadError.invalidShare }
        if case .raceSnapshot = envelope.message {
            guard envelope.seq > lastSnapshotSeq else { return nil }
            lastSnapshotSeq = envelope.seq
        }
        return envelope.message
    }
}

/// Executes an action exactly once per token — the receiving half of
/// "send boost ×3 and let the host dedupe".
nonisolated final class TokenDeduper {
    private var seen: Set<UUID> = []

    /// True the first time a token is seen.
    func firstSighting(_ token: UUID) -> Bool {
        seen.insert(token).inserted
    }
}
