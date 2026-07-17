//
//  GameTransport.swift
//  Hot Wheels v Human
//
//  The one seam between game logic and the network. Everything above this
//  protocol is transport-agnostic: Solo Arena uses LoopbackTransport,
//  real play uses MultipeerTransport.
//

import Foundation

nonisolated enum TransportRole: String, Sendable {
    case host      // TV, or the solo iPad hosting its own arena
    case player    // iPad workshop/dashboard
}

nonisolated enum TransportState: Equatable, Sendable {
    case idle
    case searching
    case connected
    case dropped
}

/// Note: connection events carry the peer's *display name* only — a
/// `PlayerInfo` isn't known until the `hello` message arrives (the
/// Networking README's sketch predates this detail).
nonisolated enum TransportEvent: Sendable {
    case peerConnected(peerName: String)
    case peerDropped(peerName: String)
    case message(GameMessage)
    case stateChanged(TransportState)
}

@MainActor
protocol GameTransport: AnyObject {
    var events: AsyncStream<TransportEvent> { get }
    var state: TransportState { get }
    func send(_ message: GameMessage, reliably: Bool)
    func start(role: TransportRole)
    func stop()
}
