//
//  DriverDashboardView.swift
//  Hot Wheels v Human
//
//  The dash you see over the hood in driver view: a moulded plastic cowl
//  bolted to the bottom edge of the screen, carrying a speed gauge, the car
//  radio, and a speaker grille. OPAQUE on purpose — a translucent panel just
//  showed the sky through it and read as a floating toolbar.
//
//  Only shown in driver view (and never at the flag, where the camera leaves
//  the cockpit). Same controls on both platforms: tapped on iPad, clicked
//  with the Siri Remote on the TV, which is why every key carries its own
//  focus ring.
//

import SwiftUI

struct DriverDashboardView: View {
    let station: RadioStation
    /// Hero car's speed, m/s — the gauge is real telemetry, not decoration.
    let speed: Float
    let powered: Bool
    /// Moulded to the car you're riding in (`DashStyle`).
    let style: DashStyle
    let onPick: (RadioStation) -> Void
    let onPower: () -> Void

    private var amber: Color { style.accent }

    var body: some View {
        // Narrow screens (portrait iPad is 834 pt, and the full row wants
        // ~800) shed the trim before the controls: speaker first, then the
        // gauge. The radio itself never goes.
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 20) {
                gauge
                faceplate
                SpeakerGrille(housing: style.housing)
                    .frame(maxWidth: 300, maxHeight: 84)
                // Bare moulding: Solo Arena parks the boost dial in this
                // corner, and it reads as mounted on the dash rather than
                // dropped on the speaker.
                Spacer(minLength: 0)
            }
            HStack(alignment: .center, spacing: 16) {
                gauge
                faceplate
            }
            faceplate
        }
        .padding(.horizontal, 26)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(cowl)
    }

    // MARK: The dash itself

    /// Moulded cowl: hard top lip catching the sky, dark plastic falling away
    /// to the bottom of the screen.
    private var cowl: some View {
        let shell = UnevenRoundedRectangle(topLeadingRadius: 34, bottomLeadingRadius: 0,
                                           bottomTrailingRadius: 0, topTrailingRadius: 34)
        return shell
            .fill(LinearGradient(colors: [style.plateTop, style.plateBottom],
                                 startPoint: .top, endPoint: .bottom))
            .overlay { MaterialSkin(style: style).clipShape(shell) }
            .overlay(alignment: .top) {
                LinearGradient(colors: [.white.opacity(0.1 + 0.5 * style.gloss),
                                        .white.opacity(0.04)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 4)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 34, topTrailingRadius: 34))
            }
            .shadow(color: .black.opacity(0.7), radius: 14, y: -8)
            .ignoresSafeArea(edges: .bottom)
    }

    // MARK: Gauge

    private var gauge: some View {
        VStack(spacing: 4) {
            // Badge, like the one moulded into a real dash.
            Text(style.nameplate)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(.white.opacity(0.32))
                .shadow(color: .white.opacity(0.18), radius: 0, y: 1)
                .padding(.horizontal, 8)
            Text(String(format: "%.1f", speed))
                .font(.system(size: 34, weight: .heavy, design: .monospaced))
                .foregroundStyle(amber)
                .shadow(color: amber.opacity(0.6), radius: 6)
                .contentTransition(.numericText())
            Text("M/S")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
            // Needle stand-in: a bar that sweeps with speed.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.12))
                    Capsule()
                        .fill(LinearGradient(colors: [amber, .red],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(sweep))
                }
            }
            .frame(width: 96, height: 6)
        }
        .frame(width: 116)
        .padding(.vertical, 10)
        .background(inset)
    }

    /// Gauge fill, 0…1. 6 m/s is well past anything the rail pace reaches, so
    /// the needle never pins.
    private var sweep: Float { min(max(speed / 6, 0), 1) }

    // MARK: Radio

    private var faceplate: some View {
        HStack(spacing: 12) {
            PowerKey(on: powered, accent: style.accent, action: onPower)
            VStack(alignment: .leading, spacing: 8) {
                display
                HStack(spacing: 8) {
                    ForEach(Array(RadioStation.allCases.enumerated()), id: \.element) { slot, preset in
                        PresetKey(preset: preset, slot: slot + 1, accent: style.accent,
                                  lit: powered && preset == station) { onPick(preset) }
                    }
                }
            }
        }
        .padding(12)
        .background(inset)
    }

    /// The little lit window every car radio has.
    private var display: some View {
        HStack(spacing: 8) {
            Image(systemName: powered ? "dot.radiowaves.left.and.right" : "radio")
                .font(.system(size: 15, weight: .bold))
            Text(powered ? station.label : "OFF")
                .font(.system(size: 17, weight: .heavy, design: .monospaced))
            Spacer(minLength: 0)
            Text(powered ? "FM \(RadioStation.allCases.firstIndex(of: station).map { $0 + 1 } ?? 1)" : "--")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
        }
        .foregroundStyle(powered ? amber : .white.opacity(0.2))
        .shadow(color: powered ? amber.opacity(0.7) : .clear, radius: 5)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 0.03, green: 0.04, blue: 0.03))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.black.opacity(0.8), lineWidth: 2)
                }
        }
    }

    /// Recessed housing: everything on a dash is sunk into it.
    private var inset: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(style.housing)
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(LinearGradient(
                        colors: [.black.opacity(0.9), .white.opacity(0.12)],
                        startPoint: .top, endPoint: .bottom), lineWidth: 2)
            }
    }
}

// MARK: - Keys

/// One preset button, built to look pressable: domed plastic, a lit face when
/// it's the station you're on, and its slot number stamped in the corner.
private struct PresetKey: View {
    let preset: RadioStation
    let slot: Int
    let accent: Color
    let lit: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            KeyFace(lit: lit, accent: accent) {
                VStack(spacing: 3) {
                    Image(systemName: preset.symbol)
                        .font(.system(size: 20, weight: .bold))
                    Text(preset.label)
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.horizontal, 4)
            }
            .frame(width: 82, height: 62)
            .overlay(alignment: .topTrailing) {
                Text("\(slot)")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(lit ? 0.75 : 0.3))
                    .padding(4)
            }
        }
        .buttonStyle(.plain)
    }
}

/// Power rocker. The radio is the one thing on this dash a kid can switch
/// off, so it gets the big round key.
private struct PowerKey: View {
    let on: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            KeyFace(lit: on, accent: accent) {
                Image(systemName: "power")
                    .font(.system(size: 24, weight: .black))
            }
            .frame(width: 64, height: 64)
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(on ? "Radio on" : "Radio off")
    }
}

/// Shared key look: domed gradient, hard top highlight, amber when lit, and a
/// focus ring so the Siri Remote can find it on the TV.
private struct KeyFace<Content: View>: View {
    let lit: Bool
    let accent: Color
    @ViewBuilder var content: Content
    @Environment(\.isFocused) private var isFocused

    private var amber: Color { accent }

    var body: some View {
        content
            .foregroundStyle(lit ? .black.opacity(0.8) : .white.opacity(0.85))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(lit
                          ? LinearGradient(colors: [amber, amber.mix(with: .black, by: 0.45)],
                                           startPoint: .top, endPoint: .bottom)
                          : LinearGradient(colors: [Color(red: 0.26, green: 0.27, blue: 0.31),
                                                    Color(red: 0.13, green: 0.13, blue: 0.16)],
                                           startPoint: .top, endPoint: .bottom))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.white.opacity(lit ? 0.5 : 0.16), lineWidth: 1.5)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.cyan, lineWidth: isFocused ? 4 : 0)
            }
            .shadow(color: lit ? amber.opacity(0.55) : .black.opacity(0.5),
                    radius: lit ? 10 : 4, y: 2)
            .scaleEffect(isFocused ? 1.06 : 1)
            .animation(.easeOut(duration: 0.12), value: lit)
            .animation(.easeOut(duration: 0.12), value: isFocused)
    }
}

/// Punched-metal speaker, the cheap way: a dot grid.
private struct SpeakerGrille: View {
    let housing: Color

    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 11, dot: CGFloat = 4.5
            var y: CGFloat = 4
            var row = 0
            while y < size.height - dot {
                var x: CGFloat = row.isMultiple(of: 2) ? 4 : 4 + step / 2
                while x < size.width - dot {
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: dot, height: dot)),
                                 with: .color(.black.opacity(0.55)))
                    x += step
                }
                y += step
                row += 1
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(housing)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}


/// What the dash is moulded from: brushed steel gets a horizontal grain and
/// corner bolts, carbon gets its weave, neon plastic gets a lit underline.
/// Sparkle paint flecks whichever of them the car is wearing.
private struct MaterialSkin: View {
    let style: DashStyle

    var body: some View {
        Canvas { context, size in
            switch style.material {
            case .brushedSteel:
                var y: CGFloat = 0
                var line = 0
                while y < size.height {
                    let shade = line.isMultiple(of: 3) ? 0.06 : 0.025
                    context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                                 with: .color(.white.opacity(shade)))
                    y += 3
                    line += 1
                }
                for bolt in stride(from: 46.0, to: size.width - 20, by: (size.width - 92) / 5) {
                    let rect = CGRect(x: bolt - 5, y: 13, width: 10, height: 10)
                    context.fill(Path(ellipseIn: rect), with: .color(.black.opacity(0.55)))
                    context.fill(Path(ellipseIn: rect.insetBy(dx: 2, dy: 2)),
                                 with: .color(.white.opacity(0.22)))
                }
            case .carbonFibre:
                let step: CGFloat = 9
                var offset = -size.height
                while offset < size.width {
                    context.stroke(Path { path in
                        path.move(to: CGPoint(x: offset, y: 0))
                        path.addLine(to: CGPoint(x: offset + size.height, y: size.height))
                    }, with: .color(.white.opacity(0.05)), lineWidth: 3)
                    context.stroke(Path { path in
                        path.move(to: CGPoint(x: offset, y: size.height))
                        path.addLine(to: CGPoint(x: offset + size.height, y: 0))
                    }, with: .color(.black.opacity(0.30)), lineWidth: 3)
                    offset += step
                }
            case .neonPlastic:
                context.fill(Path(CGRect(x: 0, y: 8, width: size.width, height: 2)),
                             with: .color(style.accent.opacity(0.85)))
                context.fill(Path(CGRect(x: 0, y: 10, width: size.width, height: 10)),
                             with: .linearGradient(
                                Gradient(colors: [style.accent.opacity(0.35), .clear]),
                                startPoint: CGPoint(x: 0, y: 10),
                                endPoint: CGPoint(x: 0, y: 20)))
            }

            guard style.glitter else { return }
            // Deterministic flecks: a redraw must not reshuffle the glitter.
            var seed: UInt64 = 0x5EED
            for _ in 0..<160 {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                let x = CGFloat(seed >> 33 % 10_000) / 10_000 * size.width
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                let y = CGFloat(seed >> 33 % 10_000) / 10_000 * size.height
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)),
                             with: .color(.white.opacity(0.5)))
            }
        }
        .allowsHitTesting(false)
    }
}
