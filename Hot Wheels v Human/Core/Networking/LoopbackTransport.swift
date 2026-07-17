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
    private weak var counterpart: LoopbackTransport?
    private let peerName: String
    private let codec = MessageCodec()

    private init(peerName: String) {
        self.peerName = peerName
        (events, continuation) = AsyncStream.makeStream()
    }

    /// A connected host+player pair.
    static func pair() -> (host: LoopbackTransport, player: LoopbackTransport) {
        let host = LoopbackTransport(peerName: "Solo TV")
        let player = LoopbackTransport(peerName: "Solo iPad")
        host.counterpart = player
        player.counterpart = host
        return (host, player)
    }

    func start(role: TransportRole) {
        state = .connected
        continuation.yield(.stateChanged(.connected))
        if let counterpart {
            continuation.yield(.peerConnected(peerName: counterpart.peerName))
        }
    }

    func send(_ message: GameMessage, reliably: Bool) {
        // Loopback never drops; encode→decode anyway so codec bugs surface
        // in solo play, not first on real hardware.
        guard let counterpart,
              let data = try? codec.encode(message),
              let decoded = try? counterpart.codec.decode(data) else { return }
        counterpart.continuation.yield(.message(decoded))
    }

    func stop() {
        state = .idle
        continuation.yield(.stateChanged(.idle))
    }
}
