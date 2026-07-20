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
                if model.phase == .results {
                    Button {
                        model.requestRematch()
                    } label: {
                        Label("REMATCH!", systemImage: "arrow.clockwise")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .frame(width: 280, height: 90)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.yellow)
                    .foregroundStyle(.black)
                    .padding(.bottom, 12)
                } else {
                    BoostButtonView(meter: car.boostMeter) {
                        model.fireBoost()
                    }
                    ReactionCamButton { on in
                        model.setReactionCam(on: on)
                    }
                    .padding(.bottom, 12)
                }
            } else if model.transportState == .connected && !model.readySent {
                // Connected, submitted, waiting on the kid: THE ready tap.
                Spacer()
                Button {
                    model.sendReady()
                } label: {
                    Label("TAP WHEN READY!", systemImage: "flag.fill")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .frame(width: 420, height: 110)
                }
                .buttonStyle(.borderedProminent)
                .tint(.yellow)
                .foregroundStyle(.black)
                Spacer()
            } else {
                Spacer()
                VStack(spacing: 12) {
                    Text(waitingLabel.title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                    Text(waitingLabel.hint)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(.yellow.opacity(0.8))
                }
                Spacer()
            }
        }
        .background(Color(red: 0.07, green: 0.08, blue: 0.13))
    }

    // Failure states stay funny, not punishing (CLAUDE.md kid-first rules).
    private var waitingLabel: (title: String, hint: String) {
        switch model.transportState {
        case .idle, .searching:
            ("Looking for the arena…", "Is the TV app awake? Give it a poke!")
        case .connected:
            ("Getting the race ready…", "Helmets on!")
        case .dropped:
            ("Whoops, lost the TV!", "The robots tripped on a cable. Reconnecting…")
        }
    }

    private func garageStrip(livesLeft: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<5, id: \.self) { i in
                Image(systemName: i < livesLeft ? "car.fill" : "burst.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(i < livesLeft ? .white : .orange)
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

/// Tap to put your driver's reaction cam up on the TV; tap again to drop it.
struct ReactionCamButton: View {
    let setOn: (Bool) -> Void
    @State private var on = false

    var body: some View {
        Button {
            on.toggle()
            setOn(on)
            if on { SoundBank.shared.play("camera_shutter") }
        } label: {
            Label(on ? "CAM ON" : "CAM OFF", systemImage: "video.fill")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .frame(width: 240, height: 64)
                .background(on ? .yellow.opacity(0.4) : .white.opacity(0.1),
                            in: Capsule())
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
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
                Image(systemName: full ? "flame.fill" : "bolt.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(full ? .orange : .yellow)
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
