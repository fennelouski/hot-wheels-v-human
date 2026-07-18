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
            Text("🏁 Hot Wheels vs. Human")
                .font(.system(size: 64, weight: .black, design: .rounded))
            Text(coordinator.transportState == .searching
                 ? "Open the app on your iPad to join!"
                 : "Waiting for racers…")
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            HStack(spacing: 24) {
                ForEach(coordinator.players) { player in
                    VStack {
                        Text("🏎️").font(.system(size: 64))
                        Text(player.name)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                    }
                    .padding(24)
                    .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 20))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.09, green: 0.10, blue: 0.16))
        .foregroundStyle(.white)
    }
}
