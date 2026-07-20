//
//  PiPTunerView.swift
//  Hot Wheels v Human
//
//  Dev harness (`--pip-tuner`): a live ReactionCamView with a slider for
//  every cockpit number and the value printed next to it, so the framing
//  can be dialled in by eye instead of guessed at a constant, rebuilt, and
//  screenshotted one value at a time.
//
//  Why this exists: the PiP's RealityView ignores the PerspectiveCamera in
//  its scene, so the camera constants do nothing (DriverPoser.frameOnHead).
//  Driver size is set by SCALING the rig, and because scale happens about
//  the rig's feet it needs a lift to go with it — two coupled numbers that
//  are miserable to find by rebuilding and may differ per character. Hence
//  sliders, every roster character, and a PIN button that collects the
//  settled values into one list you can screenshot in a single shot.
//

//  iPad-only: this is a slider bench reached solely by `--pip-tuner`, and
//  Slider/textSelection don't exist on tvOS. Same whole-file gate as
//  LookalikeView. `#if canImport(UIKit)` would be TRUE on tvOS — don't.
//

#if os(iOS)

import Combine
import SwiftUI

struct PiPTunerView: View {
    /// Held, not rebuilt per redraw: ReactionDirector is a state machine
    /// with a min-hold clock, so a fresh one each frame never settles.
    @State private var director = ReactionDirector()
    @State private var tuning = CockpitTuning.standard
    @State private var state: ReactionState = .idle
    @State private var body_: BodyType = .man
    @State private var variant = "a"
    @State private var pinned: [PinnedSetting] = []
    /// Drives lean/speed so the wheel turns and the road scrolls — the
    /// framing reads differently on a static rig than a moving one.
    @State private var lean: Float = 0
    @State private var speed: Float = 0.6

    /// Held in state, NOT recomputed per redraw. The tuner ticks the
    /// director 30×/s, so a computed design handed `ReactionCamView` a fresh
    /// struct every frame and its rebuild-on-driver-change path kept tearing
    /// the bust down and reloading it — the cockpit never had a driver in it
    /// long enough to draw.
    @State private var design = PiPTunerView.makeDesign(.man, "a")

    private static func makeDesign(_ body: BodyType, _ variant: String) -> CarDesign {
        var profile = DriverProfile.presets[0]
        profile.bodyType = body
        profile.characterVariant = variant
        var design = CarDesign.presets[0]
        design.driver = profile
        return design
    }

    private var profile: DriverProfile { design.driver ?? DriverProfile.presets[0] }

    private var characterLabel: String {
        "\(body_.rawValue)-\(variant) · \(profile.modelName(pose: .idle))"
    }

    var body: some View {
        // Scrollable both ways: fixed-width columns get clipped off the
        // edges on a narrower device, and a tuner you can't read the numbers
        // off is useless.
        ScrollView([.horizontal, .vertical]) {
            HStack(alignment: .top, spacing: 14) {
                preview
                controls
            }
            .padding(12)
        }
        .onChange(of: state) { _, new in director.fire(new) }
        .onChange(of: body_) { _, new in design = Self.makeDesign(new, variant) }
        .onChange(of: variant) { _, new in design = Self.makeDesign(body_, new) }
        .task { director.fire(.idle) }
        // Feed the director continuously so lean/speed actually reach the
        // PiP; `update` alone would leave the wheel dead straight.
        .onReceive(Timer.publish(every: 1.0 / 30, on: .main, in: .common).autoconnect()) { _ in
            director.update(dt: 1.0 / 30,
                            yawRate: lean * 2 * RaceTuning.reactionSteerThreshold,
                            loopAhead: false, speed01: speed)
            if state != .idle { director.fire(state) }
        }
    }

    // MARK: Preview

    private var preview: some View {
        VStack(spacing: 16) {
            // Actual shipping size — judge the framing at the size it runs.
            ReactionCamView(director: director, design: design, tuning: tuning)
            Text("actual size (180 pt)").font(.caption2).foregroundStyle(.secondary)

            // And blown up, because a 180 pt circle hides where exactly the
            // head is sitting.
            ReactionCamView(director: director, design: design, tuning: tuning)
                .scaleEffect(1.6)
                .frame(width: 288, height: 288)
            Text("1.6× zoom").font(.caption2).foregroundStyle(.secondary)

            readout
        }
        .frame(width: 300)
    }

    /// The block to screenshot. Everything needed to reproduce the setting,
    /// including which character it was found on.
    private var readout: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("CURRENT — \(characterLabel)").font(.caption).bold()
            Group {
                Text(line("bustScale", tuning.bustScale))
                Text(line("bustLift", tuning.bustLift))
                Text(line("wheelCenterY", tuning.wheelCenterY))
                Text(line("wheelRadius", tuning.wheelRadius))
                Text(line("wheelAngle", tuning.wheelAngle))
                Text(line("horizonRatio", tuning.horizonRatio))
                Text(line("vanishShift", tuning.vanishShift))
                Text(line("keyLightWash", tuning.keyLightWash))
            }
            .font(.system(size: 12, design: .monospaced))

            if !pinned.isEmpty {
                Divider().padding(.vertical, 4)
                Text("PINNED").font(.caption).bold()
                ForEach(pinned) { pin in
                    Text(pin.summary)
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    private func line(_ name: String, _ value: Float) -> String {
        name.padding(toLength: 13, withPad: " ", startingAt: 0)
            + String(format: "%.3f", value)
    }

    // MARK: Controls

    private var controls: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Character").font(.headline)
                Picker("Body", selection: $body_) {
                    ForEach(BodyType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Variant", selection: $variant) {
                    ForEach(DriverProfile.characterVariants, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented)

                Text("Reaction state").font(.headline)
                Picker("State", selection: $state) {
                    ForEach(ReactionState.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu)

                Divider()
                Text("Driver in frame").font(.headline)
                slider("bustScale", $tuning.bustScale, 0.05...2.0,
                       help: "Shrinks the driver. THE size knob — the camera does nothing.")
                slider("bustLift", $tuning.bustLift, -6...6,
                       help: "Raises the driver. Scale is about their feet, so shrinking drops the head.")

                Divider()
                Text("Steering wheel").font(.headline)
                slider("wheelCenterY", $tuning.wheelCenterY, 0.5...2.0,
                       help: "Wheel centre below the circle. Higher = wheel sits lower.")
                slider("wheelRadius", $tuning.wheelRadius, 0.2...1.2)
                slider("wheelAngle", $tuning.wheelAngle, 0...2.0,
                       help: "How far the wheel swings at full lean.")

                Divider()
                Text("Windshield").font(.headline)
                slider("horizonRatio", $tuning.horizonRatio, 0.1...0.9)
                slider("vanishShift", $tuning.vanishShift, 0...0.8)
                slider("keyLightWash", $tuning.keyLightWash, 0...1)

                Divider()
                Text("Motion (not tuning — just to see it move)").font(.headline)
                slider("lean", $lean, -1...1)
                slider("speed", $speed, 0...1)

                Divider()
                HStack(spacing: 12) {
                    Button("PIN \(characterLabel)") {
                        pinned.removeAll { $0.character == characterLabel }
                        pinned.append(PinnedSetting(character: characterLabel, tuning: tuning))
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Reset") { tuning = .standard }
                    Button("Clear pins") { pinned.removeAll() }
                }
                .font(.callout)
            }
            .padding(.trailing, 8)
        }
        .frame(width: 430)
    }

    private func slider(_ name: String, _ value: Binding<Float>,
                        _ range: ClosedRange<Float>, help: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(name).font(.system(size: 13, weight: .semibold, design: .monospaced))
                Spacer()
                Text(String(format: "%.3f", value.wrappedValue))
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.tint)
            }
            Slider(value: value, in: range)
            if let help {
                Text(help).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

/// One settled character's numbers, kept so a single screenshot can carry
/// every per-character value at once.
private struct PinnedSetting: Identifiable {
    let id = UUID()
    let character: String
    let tuning: CockpitTuning

    var summary: String {
        String(format: "%@ | scale %.3f lift %.3f | wheel %.3f/%.3f/%.3f | glass %.3f/%.3f/%.3f",
               character, tuning.bustScale, tuning.bustLift,
               tuning.wheelCenterY, tuning.wheelRadius, tuning.wheelAngle,
               tuning.horizonRatio, tuning.vanishShift, tuning.keyLightWash)
    }
}

#endif
