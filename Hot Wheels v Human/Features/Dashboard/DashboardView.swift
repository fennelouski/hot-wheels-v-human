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
