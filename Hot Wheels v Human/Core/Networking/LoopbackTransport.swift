//
//  LoopbackTransport.swift
//  Hot Wheels v Human
//
//  In-process host↔player pair. Solo Arena, previews, and integration
//  tests all run the full message flow through this — 95% of development
//  never needs a real network.
//

import Foundation

@MainActor
final class LoopbackTransport: GameTransport {
    private(set) var state: TransportState = .idle
    let events: AsyncStream<TransportEvent>
    private let continuation: AsyncStream<TransportEvent>.Continuation
    /// Weak like Multipeer's session refs — the rig owns the endpoints.
    private struct WeakPeer { weak var transport: LoopbackTransport? }
    private var counterparts: [WeakPeer] = []
    private let peerName: String
    private let codec = MessageCodec()

    private init(peerName: String) {
        self.peerName = peerName
        (events, continuation) = AsyncStream.makeStream()
    }

    /// A connected host+player pair.
    static func pair() -> (host: LoopbackTransport, player: LoopbackTransport) {
        let hub = hub(playerCount: 1)
        return (hub.host, hub.players[0])
    }

    /// One host wired to N players — the two-iPad 2P topology in-process.
    /// Host sends broadcast to every player (like MCSession); player sends
    /// reach only the host.
    static func hub(playerCount: Int) -> (host: LoopbackTransport, players: [LoopbackTransport]) {
        let host = LoopbackTransport(peerName: "Solo TV")
        let players = (1...max(1, playerCount)).map { LoopbackTransport(peerName: "Solo iPad \($0)") }
        host.counterparts = players.map { WeakPeer(transport: $0) }
        for player in players {
            player.counterparts = [WeakPeer(transport: host)]
        }
        return (host, players)
    }

    func start(role: TransportRole) {
        state = .connected
        continuation.yield(.stateChanged(.connected))
        for peer in counterparts {
            if let counterpart = peer.transport {
                continuation.yield(.peerConnected(peerName: counterpart.peerName))
            }
        }
    }

    func send(_ message: GameMessage, reliably: Bool) {
        // Loopback never drops; encode→decode anyway so codec bugs surface
        // in solo play, not first on real hardware.
        for peer in counterparts {
            guard let counterpart = peer.transport,
                  let data = try? codec.encode(message),
                  let decoded = try? counterpart.codec.decode(data) else { continue }
            counterpart.continuation.yield(.message(decoded))
        }
    }

    func stop() {
        state = .idle
        continuation.yield(.stateChanged(.idle))
    }
}
