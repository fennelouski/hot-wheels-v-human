//
//  DashboardView.swift
//  Hot Wheels v Human
//
//  The in-race cockpit: boost button center-bottom, progress strip on top,
//  garage slots left, speedometer right. Everything renders from snapshots.
//

import SwiftUI

struct DashboardView: View {
    let model: DashboardModel

    var body: some View {
        VStack(spacing: 16) {
            if let car = model.myCar {
                ProgressView(value: min(max(car.progress, 0), 1))
                    .tint(.yellow)
                    .scaleEffect(y: 3)
                    .padding(.horizontal)
                    .padding(.top, 12)

                HStack {
                    garageStrip(livesLeft: car.livesLeft)
                    Spacer()
                    speedometer(speed: car.speed)
                }
                .padding(.horizontal)

                Spacer()
                BoostButtonView(meter: car.boostMeter) {
                    model.fireBoost()
                }
                .padding(.bottom, 12)
            } else {
                Spacer()
                Text(waitingLabel)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
            }
        }
        .background(Color(red: 0.07, green: 0.08, blue: 0.13))
    }

    private var waitingLabel: String {
        switch model.transportState {
        case .idle, .searching: "🔍 Looking for the arena…"
        case .connected: "🛠️ Getting the race ready…"
        case .dropped: "📡 Reconnecting…"
        }
    }

    private func garageStrip(livesLeft: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<5, id: \.self) { i in
                Text(i < livesLeft ? "🚗" : "💥")
                    .font(.system(size: 30))
                    .opacity(i < livesLeft ? 1 : 0.5)
            }
        }
    }

    private func speedometer(speed: Float) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 4) {
            Text(String(format: "%.1f", speed))
                .font(.system(size: 44, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
            Text("m/s")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}

/// Circular charge meter; full = pulsing, tap = fire. THE button.
struct BoostButtonView: View {
    let meter: Float
    let fire: () -> Void

    private var full: Bool { meter >= 1 }

    var body: some View {
        Button(action: fire) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.15), lineWidth: 14)
                Circle()
                    .trim(from: 0, to: CGFloat(min(meter, 1)))
                    .stroke(full ? .yellow : .orange,
                            style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(full ? "🔥" : "⚡️")
                    .font(.system(size: 64))
                    .scaleEffect(full ? 1.15 : 1)
                    .animation(full ? .easeInOut(duration: 0.5).repeatForever(autoreverses: true)
                                    : .default,
                               value: full)
            }
            .frame(width: 170, height: 170)
        }
        .buttonStyle(.plain)
        .disabled(!full)
        #if !os(tvOS)
        .sensoryFeedback(.impact(weight: .heavy), trigger: full)
        #endif
    }
}
