//
//  SoloArenaView.swift
//  Hot Wheels v Human
//
//  Arena + mini-Dashboard in one screen, wired through LoopbackTransport —
//  the full networked message flow running in-process. Primary dev loop,
//  and Test Mode's home (MatchConfig.mode == .test).
//

import SwiftUI

struct SoloArenaView: View {
    var designs: [CarDesign] = [CarDesign.demoPair[0]]
    var blueprint: TrackBlueprint = .demo
    var config = MatchConfig(mode: .solo)

    @State private var rig: SoloRig?

    var body: some View {
        HStack(spacing: 0) {
            if let rig {
                ArenaView(coordinator: rig.coordinator)
                DashboardView(model: rig.dashboard)
                    .frame(width: 300)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(red: 0.07, green: 0.08, blue: 0.13))
        .task {
            guard rig == nil else { return }
            let pair = LoopbackTransport.pair()
            let coordinator = RaceCoordinator(transport: pair.host)
            let dashboard = DashboardModel(transport: pair.player, playerName: "Solo Racer")
            coordinator.start()
            dashboard.start()
            dashboard.submitAndReady(designs: designs, blueprint: blueprint, config: config)
            rig = SoloRig(coordinator: coordinator, dashboard: dashboard)
        }
        .onDisappear {
            rig?.coordinator.stop()
            rig?.dashboard.stop()
        }
    }
}

/// Keeps the loopback pair + both endpoints alive together.
struct SoloRig {
    let coordinator: RaceCoordinator
    let dashboard: DashboardModel
}

#Preview {
    SoloArenaView()
}
