//
//  ArenaHUDView.swift
//  Hot Wheels v Human
//
//  Overlay for the arena: big countdown numerals, per-racer banners,
//  results table. Kid-first: huge type, no walls of text.
//

import SwiftUI

struct ArenaHUDView: View {
    let session: RaceSession

    var body: some View {
        ZStack {
            if session.phase == .countdown {
                Text(session.countdownValue > 0 ? "\(session.countdownValue)" : "GO!")
                    .font(.system(size: 160, weight: .black, design: .rounded))
                    .foregroundStyle(.yellow)
                    .shadow(radius: 8)
                    .transition(.scale)
            }

            VStack {
                HStack {
                    ForEach(session.racers) { racer in
                        racerBanner(racer)
                    }
                }
                .padding(.top, 8)
                Spacer()
                if session.phase == .racing {
                    Text(String(format: "%.1f s", session.raceClock))
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.bottom, 8)
                }
            }

            if session.phase == .results {
                resultsPanel
            }
        }
    }

    private func racerBanner(_ racer: RaceSession.Racer) -> some View {
        VStack(spacing: 4) {
            Text(racer.design.name)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
            HStack(spacing: 2) {
                if racer.livesLeft > 20 {
                    Text("∞").font(.title2)      // test mode
                } else {
                    ForEach(0..<max(racer.livesLeft, 0), id: \.self) { _ in
                        Text("🚗").font(.system(size: 16))
                    }
                }
            }
            ProgressView(value: min(max(racer.progress, 0), 1))
                .tint(.yellow)
                .frame(width: 140)
            Text(String(format: "%.1f m/s", racer.speed))
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
        }
        .padding(12)
        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 16))
        .foregroundStyle(.white)
    }

    private var resultsPanel: some View {
        VStack(spacing: 16) {
            Text("🏁 RESULTS")
                .font(.system(size: 48, weight: .black, design: .rounded))
            Grid(horizontalSpacing: 24, verticalSpacing: 8) {
                GridRow {
                    Text("Car").bold()
                    Text("Time").bold()
                    Text("Top speed").bold()
                    Text("Crashes").bold()
                }
                ForEach(session.racers) { racer in
                    GridRow {
                        Text(racer.design.name)
                        Text(racer.finishTime.map { String(format: "%.1f s", $0) } ?? "OUT")
                        Text(String(format: "%.1f m/s", racer.topSpeed))
                        Text("\(racer.crashes)")
                    }
                }
            }
            .font(.system(size: 24, design: .rounded))
        }
        .padding(32)
        .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 24))
        .foregroundStyle(.white)
    }
}
