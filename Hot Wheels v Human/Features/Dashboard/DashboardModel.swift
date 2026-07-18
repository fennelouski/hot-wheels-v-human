//
//  DashboardModel.swift
//  Hot Wheels v Human
//
//  Player-side transport client: sends hello/design/blueprint/ready/boost,
//  renders everything from RaceSnapshots. Never simulates.
//

import Foundation
import Observation

@MainActor
@Observable
final class DashboardModel {

    let player: PlayerInfo
    private(set) var snapshot: RaceSnapshot?
    private(set) var transportState: TransportState = .idle
    private(set) var rejectionReason: String?
    private(set) var lastEvent: RaceEvent?

    private let transport: any GameTransport

    init(transport: any GameTransport, playerName: String) {
        self.transport = transport
        self.player = PlayerInfo(id: UUID(), name: playerName, deviceRole: .iPad)
    }

    var myCar: CarSnapshot? {
        snapshot?.cars.first { $0.playerID == player.id }
    }
    var phase: RacePhase { snapshot?.phase ?? .lobby }

    func start() {
        transport.start(role: .player)
        Task { [weak self] in
            guard let events = self?.transport.events else { return }
            for await event in events {
                self?.handle(event)
            }
        }
    }

    func stop() { transport.stop() }

    /// The whole pre-race handshake for solo/1P: announce, submit the
    /// design(s) + track, ready up. Extra designs beyond the first belong
    /// to no controller (Test Mode's B car, demo opponents).
    func submitAndReady(designs: [CarDesign], blueprint: TrackBlueprint, config: MatchConfig) {
        transport.send(.hello(player, protocolVersion: gameProtocolVersion), reliably: true)
        for design in designs {
            transport.send(.carDesign(design), reliably: true)
        }
        transport.send(.matchConfig(config), reliably: true)
        transport.send(.trackBlueprint(blueprint), reliably: true)
        transport.send(.readyState(playerID: player.id, ready: true), reliably: true)
    }

    /// Hold-to-show driver PiP on the TV (Phase 6). Reliable — a lost
    /// "off" would strand the PiP on screen.
    func setReactionCam(on: Bool) {
        transport.send(.reactionCam(playerID: player.id, on: on), reliably: true)
    }

    /// Boost taps ride the unreliable channel ×3 with a dedupe token.
    func fireBoost() {
        guard (myCar?.boostMeter ?? 0) >= 1 else { return }
        let token = UUID()
        Task { @MainActor in
            for _ in 0..<3 {
                transport.send(.boost(playerID: player.id, token: token), reliably: false)
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private func handle(_ event: TransportEvent) {
        switch event {
        case .stateChanged(let state):
            transportState = state
        case .message(.raceSnapshot(let snap)):
            snapshot = snap
        case .message(.raceEvent(let raceEvent)):
            lastEvent = raceEvent
            if case .blueprintRejected(let reason) = raceEvent {
                rejectionReason = reason
            }
        default:
            break
        }
    }
}
