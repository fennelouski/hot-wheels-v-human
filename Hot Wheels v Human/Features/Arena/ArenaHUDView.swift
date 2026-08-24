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
    /// "Race 2 of 5" when a drafted series is running (nil = single race).
    var seriesLabel: String?
    /// Bottom clearance for the race clock — the driver's-seat dashboard
    /// parks along the bottom edge and the clock would land behind it.
    var bottomInset: CGFloat = 0

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
                        .padding(.bottom, 8 + bottomInset)
                }
            }

            if session.phase == .results {
                // Docked, not centred: the arena camera swings the cars into
                // the other two thirds so the breakdown stays watchable.
                HStack {
                    Spacer(minLength: 0)
                    resultsPanel
                        .frame(maxWidth: 560)
                        .padding(.trailing, 24)
                }
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
        return VStack(spacing: 12) {
            if let seriesLabel {
                Text(seriesLabel)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            }
            if let winner {
                Label("\(winner.design.name.uppercased()) WINS!", systemImage: "trophy.fill")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle(.yellow)
            } else {
                Label("EVERYBODY CRASHED!", systemImage: "burst.fill")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(.orange)
            }
            Grid(horizontalSpacing: 14, verticalSpacing: 8) {
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
            .font(.system(size: 19, design: .rounded))
            Text(seriesLabel == nil
                 ? "Press \(Image(systemName: "arrow.clockwise")) REMATCH on your iPad to go again!"
                 : "Press \(Image(systemName: "arrow.clockwise")) REMATCH on your iPad for the next track!")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.yellow)
        }
        .padding(22)
        .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 24))
        .foregroundStyle(.white)
    }
}
