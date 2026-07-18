//
//  RaceOnTVView.swift
//  Hot Wheels v Human
//
//  iPad → real TV flow: browse for the arena over Multipeer, submit the
//  design + track, then become the full-screen dashboard. Until the
//  Customizer/TrackBuilder ship, the demo car + track ride along.
//

import SwiftUI

struct RaceOnTVView: View {
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
                    model.submitAndReady(designs: [appModel.raceDesign],
                                         blueprint: appModel.raceBlueprint,
                                         config: MatchConfig(mode: .onePlayer))
                case .dropped:
                    submitted = false
                default:
                    break
                }
            }
    }
}
