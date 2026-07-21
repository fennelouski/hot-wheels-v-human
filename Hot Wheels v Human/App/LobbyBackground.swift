//
//  LobbyBackground.swift
//  Hot Wheels v Human
//
//  Shared pre-race backdrop for the TV lobby (ArenaLobbyView) and the
//  iPad's pre-race screen (Dashboard's ConnectionLadder) — two windows
//  onto the same connection state, from opposite ends of the wire. Slow
//  drifting glow, not a light show: kid-first means calm, never strobing.
//

import SwiftUI

/// `energy` drives both color and drift speed: cool and nearly still with
/// an empty lobby, warming toward the brand yellow and quickening as
/// connected racers join and ready up. Callers compute `energy` from
/// whatever connection state they can see — the TV from every player's
/// join/ready state, the iPad from its own transport + ready flag.
struct LobbyBackground: View {
    /// 0 = nobody connected/ready, 1 = every connected racer is ready to go.
    var energy: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12, paused: false)) { timeline in
            let e = min(max(energy, 0), 1)
            let t = timeline.date.timeIntervalSinceReferenceDate
            let speed = 0.04 + e * 0.10
            ZStack {
                floor(e)
                orb(angle: t * speed, radius: 0.5, phase: 0, warmth: e)
                orb(angle: t * speed * 0.66 + 2.1, radius: 0.38, phase: 1.7, warmth: e)
            }
        }
    }

    private func floor(_ e: Double) -> some View {
        LinearGradient(
            colors: [
                Color(red: 0.07 + e * 0.03, green: 0.08 + e * 0.02, blue: 0.13 - e * 0.02),
                Color(red: 0.04, green: 0.045, blue: 0.08)
            ],
            startPoint: .top, endPoint: .bottom)
    }

    /// One soft light source drifting a slow ellipse; `warmth` slides its
    /// tint from cool navy toward the brand yellow-orange.
    private func orb(angle: Double, radius: Double, phase: Double, warmth: Double) -> some View {
        let center = UnitPoint(x: 0.5 + cos(angle + phase) * radius,
                                y: 0.5 + sin(angle + phase) * radius * 0.55)
        let color = Color(red: 0.15 + warmth * 0.75,
                           green: 0.14 + warmth * 0.55,
                           blue: 0.32 - warmth * 0.16)
            .opacity(0.5)
        return RadialGradient(colors: [color, .clear], center: center, startRadius: 0, endRadius: 680)
    }
}
