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

    /// Whether this dashboard has readied up for the pending race.
    private(set) var readySent = false

    /// Announce + submit the design(s) and track, without readying up
    /// (Race-on-TV flow: READY is the kid's tap). The first design is
    /// ours (ownerID); extras belong to no controller (Test Mode's B car,
    /// demo opponents).
    func submit(designs: [CarDesign], blueprint: TrackBlueprint, config: MatchConfig) {
        transport.send(.hello(player, protocolVersion: gameProtocolVersion), reliably: true)
        for (i, design) in designs.enumerated() {
            transport.send(.carDesign(design, ownerID: i == 0 ? player.id : nil), reliably: true)
        }
        transport.send(.matchConfig(config), reliably: true)
        transport.send(.trackBlueprint(blueprint), reliably: true)
    }

    /// The whole pre-race handshake for solo/1P: submit, then auto-ready.
    func submitAndReady(designs: [CarDesign], blueprint: TrackBlueprint, config: MatchConfig) {
        submit(designs: designs, blueprint: blueprint, config: config)
        sendReady()
    }

    func sendReady() {
        readySent = true
        transport.send(.readyState(playerID: player.id, ready: true), reliably: true)
        SoundBank.shared.play("ready_bell")
    }

    /// REMATCH = ready up again from the results screen; the host tears
    /// down and reruns the same race once everyone re-readies.
    func requestRematch() {
        transport.send(.readyState(playerID: player.id, ready: true), reliably: true)
        SoundBank.shared.play("rematch_ding")
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
