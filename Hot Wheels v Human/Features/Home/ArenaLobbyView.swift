//
//  ArenaLobbyView.swift
//  Hot Wheels v Human
//
//  TV entry point: advertises `hwvh-race` on appear, shows connected
//  players, hands off to ArenaView once the race starts. The iPad is
//  still the primary controller (READY lives there), but the lobby also
//  has a focusable START RACE button for a couch short an iPad
//  (Home README).
//

import SwiftUI

struct ArenaLobbyView: View {
    @State private var coordinator = RaceCoordinator(transport: MultipeerTransport())

    private var allReady: Bool {
        !coordinator.players.isEmpty
            && coordinator.players.allSatisfy { coordinator.isReady($0.id) }
    }

    var body: some View {
        ZStack {
            // Always mounted, even during .lobby: this is what calls
            // coordinator.attach(root:), and startRaceIfReady() can't
            // leave .lobby without a root already attached. Gating this
            // view behind "phase != .lobby" was a deadlock — the phase
            // could never change because the thing that changes it was
            // waiting on this view to appear first. The lobby overlay
            // below covers the (trackless) scene until the race starts.
            ArenaView(coordinator: coordinator)
            if coordinator.session.phase == .lobby {
                lobby
            }
        }
        .onAppear { coordinator.start() }
        .onDisappear { coordinator.stop() }
        .onChange(of: coordinator.players.count) { old, new in
            if new > old { SoundBank.shared.play("player_join_horn") }
        }
    }

    private var lobby: some View {
        VStack(spacing: 28) {
            VStack(spacing: 6) {
                Label("Hot Wheels vs. Human", systemImage: "flag.checkered")
                    .font(.system(size: 64, weight: .black, design: .rounded))
                    .symbolEffect(.bounce, value: coordinator.players.count)
                if !coordinator.players.isEmpty {
                    Text("\(coordinator.players.count) of \(RaceCoordinator.maxPlayers) racers")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.yellow)
                }
            }
            if coordinator.players.isEmpty {
                joinGuide
            } else {
                Text(allReady ? "Everybody's ready — let's race!"
                               : "Tap READY on your iPad, or press START on the TV!")
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .foregroundStyle(allReady ? .green : .secondary)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.25), value: allReady)
            }
            HStack(spacing: 24) {
                ForEach(Array(coordinator.players.enumerated()), id: \.element.id) { index, player in
                    playerCard(player)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.75), value: coordinator.players.count)
            if !coordinator.players.isEmpty {
                Button {
                    coordinator.hostStartRace()
                } label: {
                    Label(allReady ? "START RACE!" : "START ANYWAY", systemImage: "flag.checkered")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .frame(width: 380, height: 84)
                }
                .buttonStyle(.borderedProminent)
                .tint(allReady ? .yellow : .white.opacity(0.22))
                .foregroundStyle(allReady ? .black : .white)
                .scaleEffect(allReady ? 1.04 : 1)
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: allReady)
            }
            if let rejection = coordinator.lastRejection {
                Label(rejection, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.orange, in: RoundedRectangle(cornerRadius: 16))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: coordinator.lastRejection)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RadialGradient(colors: [Color(red: 0.16, green: 0.18, blue: 0.27),
                                     Color(red: 0.07, green: 0.08, blue: 0.13)],
                           center: .center, startRadius: 60, endRadius: 1000)
        )
        .foregroundStyle(.white)
    }

    /// One racer's card: their actual car (once its design has synced),
    /// name, track picks, and a big unmistakable ready/not pill — a kid
    /// checking the TV from across the room shouldn't have to squint.
    private func playerCard(_ player: PlayerInfo) -> some View {
        let ready = coordinator.isReady(player.id)
        return VStack(spacing: 10) {
            if let design = coordinator.design(for: player.id) {
                CarSwatchView(design: design, size: 72)
            } else {
                Circle()
                    .fill(.white.opacity(0.1))
                    .overlay {
                        Image(systemName: "car.side.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .frame(width: 72, height: 72)
            }
            Text(player.name)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .lineLimit(1)
            let picks = coordinator.pickCount(player.id)
            if picks > 0 {
                // Everyone drafts tracks; the series alternates picks.
                Label(picks == 1 ? "1 track" : "\(picks) tracks", systemImage: "map.fill")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.yellow, in: Capsule())
            }
            Label(ready ? "READY!" : "getting set…",
                  systemImage: ready ? "checkmark.circle.fill" : "ellipsis.circle")
                .font(.system(size: 19, weight: .heavy, design: .rounded))
                .foregroundStyle(ready ? .green : .white.opacity(0.65))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(ready ? Color.green.opacity(0.2) : Color.white.opacity(0.08), in: Capsule())
                .contentTransition(.symbolEffect(.replace))
        }
        .padding(22)
        .frame(width: 200)
        .background(.white.opacity(ready ? 0.14 : 0.08), in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(ready ? Color.green.opacity(0.7) : .white.opacity(0.15),
                        lineWidth: ready ? 3 : 1)
        }
        .shadow(color: ready ? .green.opacity(0.35) : .clear, radius: 16)
        .animation(.easeInOut(duration: 0.3), value: ready)
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
