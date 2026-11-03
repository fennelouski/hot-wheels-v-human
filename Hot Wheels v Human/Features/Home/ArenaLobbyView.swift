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
            // Mount the arena immediately so ArenaView calls coordinator.attach(root:).
            // Without a root, startRaceIfReady() can never fire and two readied
            // players just sit in the lobby forever (SoloArenaView mounts it the
            // same way). The lobby covers the empty arena until the race starts.
            ArenaView(coordinator: coordinator)
            if coordinator.session.phase == .lobby {
                lobby
            }
        }
        .onAppear { coordinator.start() }
        .onDisappear { coordinator.stop() }
        // Siri Remote play/pause = start now, skipping the READY wait (a racer
        // wandered off, or you just want to watch). No-ops until an iPad has
        // sent a car, so a stray click on an empty lobby does nothing.
        #if os(tvOS)
        .onPlayPauseCommand { coordinator.forceStart() }
        #endif
        .onChange(of: coordinator.players.count) { old, new in
            if new > old { SoundBank.shared.play("player_join_horn") }
        }
    }

    private var lobby: some View {
        VStack(spacing: 32) {
            Label("Hot Wheels vs. Human", systemImage: "flag.checkered")
                .font(.system(size: 64, weight: .black, design: .rounded))
            if coordinator.players.isEmpty {
                joinGuide
            } else {
                Text("Tap READY on your iPad to race!")
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 24) {
                ForEach(Array(coordinator.players.enumerated()), id: \.element.id) { index, player in
                    VStack(spacing: 8) {
                        Image(systemName: "car.side.fill").font(.system(size: 56))
                        Text(player.name)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        let picks = coordinator.pickCount(player.id)
                        if picks > 0 {
                            // Everyone drafts tracks; the series alternates picks.
                            Label(picks == 1 ? "picked a track!" : "picked \(picks) tracks!",
                                  systemImage: "map.fill")
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
        // Translucent scrim, not an opaque fill: the ArenaView orbiting behind
        // the lobby shows through, while the dark wash keeps the white text
        // readable over a bright themed sky.
        .background(.black.opacity(0.4))
        .foregroundStyle(.white)
    }

    /// Shown on the TV while no one has joined: the exact steps to get an iPad
    /// into the race, and the two-racer cap, so a room full of kids knows what
    /// to do without anyone explaining it.
    private var joinGuide: some View {
        VStack(spacing: 20) {
            Text("Grab an iPad to join — up to 2 racers!")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 14) {
                joinStep(1, "Open Hot Wheels on your iPad", icon: "ipad")
                joinStep(2, "Tap “Race on TV” — then Allow Local Network", icon: "wifi")
                joinStep(3, "Pick your car & tracks, then “To the TV!”", icon: "car.side.fill")
                joinStep(4, "Tap READY — the race starts when everyone’s set", icon: "flag.fill")
            }
        }
        .padding(28)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24))
    }

    private func joinStep(_ number: Int, _ title: String, icon: String) -> some View {
        HStack(spacing: 16) {
            Text("\(number)")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(.black)
                .frame(width: 44, height: 44)
                .background(.yellow, in: Circle())
            Image(systemName: icon)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.yellow)
                .frame(width: 40)
            Text(title)
                .font(.system(size: 26, weight: .semibold, design: .rounded))
            Spacer(minLength: 0)
        }
    }
}
