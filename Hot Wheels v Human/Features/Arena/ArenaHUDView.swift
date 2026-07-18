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
                        Image(systemName: "car.fill").font(.system(size: 14))
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

    /// Finishers by time, then the wrecked (a kid's first question is
    /// "who won?!" — answer it in headline type, keep failure funny).
    private var ranked: [RaceSession.Racer] {
        session.racers.sorted {
            ($0.finishTime ?? .infinity, $0.crashes) < ($1.finishTime ?? .infinity, $1.crashes)
        }
    }

    private var resultsPanel: some View {
        let ranked = ranked
        let winner = ranked.first(where: { $0.finishTime != nil })
        return VStack(spacing: 16) {
            if let winner {
                Label("\(winner.design.name.uppercased()) WINS!", systemImage: "trophy.fill")
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundStyle(.yellow)
            } else {
                Label("EVERYBODY CRASHED!", systemImage: "burst.fill")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundStyle(.orange)
            }
            Grid(horizontalSpacing: 24, verticalSpacing: 8) {
                GridRow {
                    Text("Car").bold()
                    Text("Time").bold()
                    Text("Top speed").bold()
                    Text("Crashes").bold()
                    Text("Best segment").bold()
                }
                ForEach(ranked) { racer in
                    GridRow {
                        HStack(spacing: 6) {
                            if racer.id == winner?.id {
                                Image(systemName: "trophy.fill").foregroundStyle(.yellow)
                            }
                            Text(racer.design.name).lineLimit(1)
                        }
                        .fixedSize()
                        Text(racer.finishTime.map { String(format: "%.1f s", $0) } ?? "OUT")
                        Text(String(format: "%.1f m/s", racer.topSpeed))
                        Text("\(racer.crashes)")
                        Text(racer.bestSegment.map {
                            String(format: "#%d · %.2f s", $0.piece + 1, $0.seconds)
                        } ?? "—")
                    }
                }
            }
            .font(.system(size: 24, design: .rounded))
            Text("Press \(Image(systemName: "arrow.clockwise")) REMATCH on your iPad to go again!")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.yellow)
        }
        .padding(32)
        .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 24))
        .foregroundStyle(.white)
    }
}
