//
//  RaceOnTVView.swift
//  Hot Wheels v Human
//
//  iPad → real TV flow: pick your car and draft your tracks on the setup
//  screen, then browse for the arena over Multipeer, submit everything,
//  and become the full-screen dashboard.
//

import SwiftUI

struct RaceOnTVView: View {
    @State private var toTheTV = false

    var body: some View {
        if toTheTV {
            RaceOnTVDashboard()
        } else {
            RaceSetupView { toTheTV = true }
        }
    }
}

private struct RaceOnTVDashboard: View {
    @Environment(AppModel.self) private var appModel
    @State private var model = DashboardModel(transport: MultipeerTransport(),
                                              playerName: "Racer")
    @State private var submitted = false

    var body: some View {
        DashboardView(model: model)
            .onAppear { model.start() }
            .onDisappear { model.stop() }
            .onChange(of: model.transportState) { _, state in
                // Hand the host everything it needs on every fresh connection.
                // Resubmitting after a drop is safe (coordinator dedupes by id)
                // and required when the TV app restarted with empty state.
                switch state {
                case .connected where !submitted:
                    submitted = true
                    // Submit but don't auto-ready — READY is the kid's tap,
                    // so a race can't start before player 2 finds the couch.
                    model.submit(designs: [appModel.stampedRaceDesign()],
                                 tracks: appModel.raceTrackList,
                                 config: MatchConfig(mode: .onePlayer))
                case .dropped:
                    submitted = false
                default:
                    break
                }
            }
    }
}
