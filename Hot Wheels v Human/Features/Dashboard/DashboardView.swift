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
                    BoostButtonView(meter: car.boostMeter,
                                    begin: model.beginBoost,
                                    end: model.endBoost)
                    ReactionCamButton { on in
                        model.setReactionCam(on: on)
                    }
                    .padding(.bottom, 12)
                }
            } else {
                // Everything before the race: a live checklist of the steps
                // from "find the TV" to "tap READY", so it's always clear what
                // to do next (kid-first: one highlighted step at a time).
                Spacer()
                ConnectionLadder(state: model.transportState,
                                 ready: model.readySent,
                                 design: model.myDesign,
                                 onReady: model.sendReady)
                Spacer()
            }
        }
        .background(background.ignoresSafeArea())
    }

    /// A moving, connection-state-driven glow before the race (matches the
    /// TV lobby's — same signal, opposite end of the wire); once racing, a
    /// flat cockpit backdrop so nothing behind the HUD steals focus.
    @ViewBuilder private var background: some View {
        if model.myCar == nil {
            LobbyBackground(energy: lobbyEnergy)
        } else {
            Color(red: 0.07, green: 0.08, blue: 0.13)
        }
    }

    private var lobbyEnergy: Double {
        switch model.transportState {
        case .idle: 0
        case .searching: 0.15
        case .connected: model.readySent ? 1 : 0.5
        case .dropped: 0.05
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

/// The pre-race "what do I do now?" checklist on the iPad. Reads straight off
/// the transport state so exactly one step is highlighted: find the TV →
/// connect → tap READY. Failure text stays funny, not punishing (CLAUDE.md).
private struct ConnectionLadder: View {
    let state: TransportState
    let ready: Bool
    let design: CarDesign?
    let onReady: () -> Void

    private var connected: Bool { state == .connected }
    private var searching: Bool { state == .idle || state == .searching }
    private var awaitingTap: Bool { connected && !ready }

    var body: some View {
        VStack(spacing: 22) {
            if let design {
                CarSwatchView(design: design, size: 92)
                    .shadow(color: ready ? .green.opacity(0.45) : .yellow.opacity(0.25), radius: 18)
                    .transition(.scale.combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: design.id)
            }

            Text(headline)
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: headline)

            VStack(alignment: .leading, spacing: 16) {
                step(1, "Open Hot Wheels on your Apple TV",
                     icon: "tv.fill", done: connected, current: !connected)
                step(2, "This iPad connects to the TV",
                     icon: "wifi", done: connected, current: !connected)
                step(3, "Tap READY to race",
                     icon: "flag.fill", done: ready, current: connected && !ready)
            }
            .frame(maxWidth: 480, alignment: .leading)

            if connected && !ready {
                Button(action: onReady) {
                    Label("TAP WHEN READY!", systemImage: "flag.fill")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .frame(width: 420, height: 104)
                }
                .buttonStyle(.borderedProminent)
                .tint(.yellow)
                .foregroundStyle(.black)
                .scaleEffect(awaitingTap ? 1.03 : 1)
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: awaitingTap)
            } else if ready {
                Label("You're in!", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.green.opacity(0.18), in: Capsule())
                    .transition(.scale.combined(with: .opacity))
            }

            if state == .dropped {
                Text("The robots tripped on a cable — reconnecting…")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.orange)
            }
            if !connected {
                Text("Stuck here? Make sure both are on the same Wi‑Fi, and tap **Allow** on the “Local Network” pop‑up (or turn it on in Settings ▸ Privacy & Security ▸ Local Network).")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.yellow.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 480)
            }
        }
        .padding(32)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 28))
        .padding(.horizontal, 24)
        .animation(.easeInOut(duration: 0.3), value: ready)
    }

    private var headline: String {
        switch state {
        case .idle, .searching: "Let’s find your TV!"
        case .connected: ready ? "You’re in — waiting for the race…" : "Connected! One more tap:"
        case .dropped: "Whoops, lost the TV!"
        }
    }

    private func step(_ number: Int, _ title: String, icon: String,
                      done: Bool, current: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(done ? Color.green.opacity(0.22)
                               : current ? Color.yellow.opacity(0.18) : Color.white.opacity(0.06))
                    .frame(width: 44, height: 44)
                Image(systemName: done ? "checkmark" : icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(done ? .green : current ? .yellow : .white.opacity(0.3))
                    .contentTransition(.symbolEffect(.replace))
            }
            Text(title)
                .font(.system(size: 22, weight: current ? .heavy : .semibold, design: .rounded))
                .foregroundStyle(done || current ? .white : .white.opacity(0.45))
            if current && searching {
                ProgressView().tint(.yellow).padding(.leading, 4)
            }
            Spacer(minLength: 0)
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
                // Same black-45 as the HUD banners: this also floats over
                // the live 3D scene on iPad, where a bright sky would
                // swallow a white-tinted pill.
                .background(on ? .yellow.opacity(0.5) : .black.opacity(0.45),
                            in: Capsule())
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}

/// The NOS bottle gauge: a 270° dial reading 0–200%, armed at 100%, red
/// overcharge zone above it. THE button — press and HOLD to burn, the
/// needle drops while you hold, the dial shakes and thumps as it fires.
struct BoostButtonView: View {
    let meter: Float
    let begin: () -> Void
    let end: () -> Void

    /// Press state, not snapshot state: the finger is local, the meter
    /// arrives 10 Hz behind over the wire.
    @State private var pressed = false
    @State private var armedAtPress = false
    /// Ticks while firing — each tick is one haptic thump.
    @State private var bump = 0

    private static let size: CGFloat = 170
    private static let sweep: CGFloat = 0.75          // 270° of dial
    private static let ring: CGFloat = 14

    private var armed: Bool { meter >= 1 }
    private var firing: Bool { pressed && armedAtPress && meter > 0 }
    /// 0…1 across the whole 0–200% dial.
    private var dial: CGFloat { CGFloat(min(max(meter, 0), 2) / 2) }

    var body: some View {
        TimelineView(.animation(minimumInterval: firing ? 1 / 30 : 1, paused: !firing)) { timeline in
            let jitter = firing
                ? sin(timeline.date.timeIntervalSinceReferenceDate * 47) * 2
                : 0
            dialFace
                .offset(x: jitter, y: -jitter)
        }
        .frame(width: Self.size, height: Self.size)
        .padding(10)
        .background(.black.opacity(0.45), in: Circle())
        .contentShape(Circle())
        // Touch DOWN starts the boost — a race button that waits for
        // touch-up feels broken, and holding is now the whole mechanic.
        // ponytail: DragGesture is unavailable on tvOS, and the TV routes to
        // ArenaLobbyView so this dial is never presented there — it only has
        // to compile. An inert dial on TV is the correct outcome.
        #if !os(tvOS)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !pressed else { return }
                    pressed = true
                    armedAtPress = armed
                    begin()
                }
                .onEnded { _ in
                    pressed = false
                    end()
                }
        )
        #endif
        // A cancelled gesture (view swapped out mid-hold, phase change) never
        // delivers onEnded — without this the heartbeat runs forever.
        .onDisappear {
            pressed = false
            end()
        }
        .task(id: firing) {
            guard firing else { return }
            while !Task.isCancelled {
                bump += 1
                try? await Task.sleep(for: .milliseconds(110))
            }
        }
        #if !os(tvOS)
        // A thump per tick while it burns, plus one clunk the moment it arms
        // (rising edge only — the meter crosses 1 downward on every burn).
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.8), trigger: bump)
        .sensoryFeedback(trigger: armed) { was, now in
            was == false && now ? .impact(weight: .heavy) : nil
        }
        #endif
    }

    private var dialFace: some View {
        ZStack {
            // Dial track + the red overcharge half of it.
            arc(to: 1).stroke(.white.opacity(0.15), lineWidth: Self.ring)
            arc(from: 0.5, to: 1).stroke(.red.opacity(0.3), lineWidth: Self.ring)

            arc(to: dial)
                .stroke(chargeGradient,
                        style: StrokeStyle(lineWidth: Self.ring, lineCap: .round))
                .shadow(color: armed ? .orange.opacity(0.9) : .clear, radius: firing ? 14 : 8)

            ticks
            needle

            VStack(spacing: 0) {
                Image(systemName: firing ? "flame.fill" : (armed ? "bolt.fill" : "bolt.slash.fill"))
                    .font(.system(size: 40))
                    .foregroundStyle(armed ? .orange : .white.opacity(0.35))
                    .scaleEffect(armed && !firing ? 1.12 : 1)
                    .animation(armed && !firing
                               ? .easeInOut(duration: 0.45).repeatForever(autoreverses: true)
                               : .default,
                               value: armed)
                Text("\(Int(min(max(meter, 0), 2) * 100))%")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(meter > 1 ? .red : .white.opacity(0.85))
                    .contentTransition(.numericText())
            }
            .offset(y: 6)
        }
        .animation(.easeOut(duration: 0.12), value: meter)
    }

    /// Orange → yellow while charging, red once overcharged.
    private var chargeGradient: AngularGradient {
        AngularGradient(colors: meter > 1 ? [.orange, .yellow, .red] : [.orange, .yellow],
                        center: .center,
                        startAngle: .degrees(135), endAngle: .degrees(405))
    }

    /// The dial reads clockwise from bottom-left (135°) to bottom-right.
    private func arc(from: CGFloat = 0, to: CGFloat) -> some Shape {
        Circle()
            .trim(from: from * Self.sweep, to: to * Self.sweep)
            .rotation(.degrees(135))
    }

    private var ticks: some View {
        ForEach(0..<11, id: \.self) { i in
            let unit = CGFloat(i) / 10
            Capsule()
                .fill(unit > 0.5 ? .red.opacity(0.7) : .white.opacity(0.45))
                .frame(width: 2, height: i % 5 == 0 ? 12 : 7)
                .offset(y: -Self.size / 2 + Self.ring + 10)
                .rotationEffect(.degrees(-135 + Double(unit) * 270))
        }
    }

    private var needle: some View {
        Capsule()
            .fill(armed ? .white : .white.opacity(0.5))
            .frame(width: 3, height: Self.size / 2 - Self.ring - 14)
            .offset(y: -(Self.size / 2 - Self.ring - 14) / 2)
            .rotationEffect(.degrees(-135 + Double(dial) * 270))
    }
}
