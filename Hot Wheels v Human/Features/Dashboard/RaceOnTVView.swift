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
    @State private var model = DashboardModel(transport: MultipeerTransport(),
                                              playerName: "Racer")
    @State private var submitted = false

    var body: some View {
        DashboardView(model: model)
            .onAppear { model.start() }
            .onDisappear { model.stop() }
            .onChange(of: model.transportState) { _, state in
                // First connection: hand the host everything it needs.
                if state == .connected && !submitted {
                    submitted = true
                    model.submitAndReady(designs: [CarDesign.demoPair[0]],
                                         blueprint: .demo,
                                         config: MatchConfig(mode: .onePlayer))
                }
            }
    }
}
