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

    /// Our own car, for the pre-race lobby's swatch (the first of
    /// `submit`'s designs — see its doc for why that one's ours).
    private(set) var myDesign: CarDesign?

    /// Announce + submit the design(s) and ranked track picks, without
    /// readying up (Race-on-TV flow: READY is the kid's tap). The first
    /// design is ours (ownerID); extras belong to no controller (Test
    /// Mode's B car, demo opponents). Track order = the kid's ranking;
    /// the host drafts the race series from everyone's picks.
    func submit(designs: [CarDesign], tracks: [TrackBlueprint], config: MatchConfig) {
        myDesign = designs.first
        transport.send(.hello(player, protocolVersion: gameProtocolVersion), reliably: true)
        for (i, design) in designs.enumerated() {
            transport.send(.carDesign(design, ownerID: i == 0 ? player.id : nil), reliably: true)
        }
        transport.send(.matchConfig(config), reliably: true)
        for (i, track) in tracks.enumerated() {
            transport.send(.trackBlueprint(track, rank: i, ownerID: player.id), reliably: true)
        }
    }

    /// The whole pre-race handshake for solo/1P: submit, then auto-ready.
    func submitAndReady(designs: [CarDesign], tracks: [TrackBlueprint], config: MatchConfig) {
        submit(designs: designs, tracks: tracks, config: config)
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

    /// Toggle the driver PiP on the TV (Phase 6). Reliable — a lost
    /// "off" would strand the PiP on screen.
    func setReactionCam(on: Bool) {
        transport.send(.reactionCam(playerID: player.id, on: on), reliably: true)
    }

    private var boostHold: Task<Void, Never>?

    /// Boost is held, not tapped: from touch-down until release we heartbeat
    /// "still holding" over the unreliable channel. The host burns the meter
    /// for `RaceTuning.boostHoldGrace` past the last packet, so drops cost a
    /// few milliseconds of thrust and a lost release can't strand the burn.
    /// The host also owns the "is the meter armed?" call — we just report the
    /// finger.
    func beginBoost() {
        guard boostHold == nil else { return }
        boostHold = Task { @MainActor [weak self] in
            while !Task.isCancelled, let self {
                transport.send(.boost(playerID: player.id, token: UUID()), reliably: false)
                try? await Task.sleep(for: .milliseconds(66))
            }
        }
    }

    func endBoost() {
        boostHold?.cancel()
        boostHold = nil
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
