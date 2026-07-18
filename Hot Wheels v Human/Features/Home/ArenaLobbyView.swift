//
//  ArenaLobbyView.swift
//  Hot Wheels v Human
//
//  TV entry point: advertises `hwvh-race` on appear, shows connected
//  players, hands off to ArenaView once the race starts. Display-only —
//  the iPad is the controller (Home README).
//

import SwiftUI

struct ArenaLobbyView: View {
    @State private var coordinator = RaceCoordinator(transport: MultipeerTransport())

    var body: some View {
        ZStack {
            if coordinator.session.phase == .lobby {
                lobby
            } else {
                ArenaView(coordinator: coordinator)
            }
        }
        .onAppear { coordinator.start() }
        .onDisappear { coordinator.stop() }
        .onChange(of: coordinator.players.count) { old, new in
            if new > old { SoundBank.shared.play("player_join_horn") }
        }
    }

    private var lobby: some View {
        VStack(spacing: 32) {
            Label("Hot Wheels vs. Human", systemImage: "flag.checkered")
                .font(.system(size: 64, weight: .black, design: .rounded))
            Text(coordinator.players.isEmpty
                 ? "Open the app on your iPad to join!"
                 : "Tap READY on your iPad to race!")
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            HStack(spacing: 24) {
                ForEach(Array(coordinator.players.enumerated()), id: \.element.id) { index, player in
                    VStack(spacing: 8) {
                        Image(systemName: "car.side.fill").font(.system(size: 56))
                        Text(player.name)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        if index == 0 && coordinator.players.count > 1 {
                            // First iPad in = track captain (TWO-IPAD-2P.md).
                            Label("picks the track!", systemImage: "map.fill")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(.yellow)
                        }
                        Label(coordinator.isReady(player.id) ? "READY!" : "getting set…",
                              systemImage: coordinator.isReady(player.id)
                                  ? "checkmark.circle.fill" : "ellipsis.circle")
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(coordinator.isReady(player.id) ? .green : .secondary)
                    }
                    .padding(24)
                    .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 20))
                }
            }
            if let rejection = coordinator.lastRejection {
                Text(rejection)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.09, green: 0.10, blue: 0.16))
        .foregroundStyle(.white)
    }
}
