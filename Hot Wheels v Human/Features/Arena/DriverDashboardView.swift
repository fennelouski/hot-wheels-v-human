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
    let onPick: (RadioStation) -> Void
    let onPower: () -> Void

    private let dashTop = Color(red: 0.22, green: 0.23, blue: 0.27)
    private let dashBottom = Color(red: 0.06, green: 0.06, blue: 0.08)
    private let amber = Color(red: 1.0, green: 0.72, blue: 0.19)

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            gauge
            faceplate
            SpeakerGrille()
                .frame(maxWidth: 300, maxHeight: 84)
            // Bare moulding: Solo Arena parks the boost dial in this corner,
            // and it reads as mounted on the dash rather than dropped on the
            // speaker.
            Spacer(minLength: 0)
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
        UnevenRoundedRectangle(topLeadingRadius: 34, bottomLeadingRadius: 0,
                               bottomTrailingRadius: 0, topTrailingRadius: 34)
            .fill(LinearGradient(colors: [dashTop, dashBottom],
                                 startPoint: .top, endPoint: .bottom))
            .overlay(alignment: .top) {
                LinearGradient(colors: [.white.opacity(0.45), .white.opacity(0.04)],
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
            PowerKey(on: powered, action: onPower)
            VStack(alignment: .leading, spacing: 8) {
                display
                HStack(spacing: 8) {
                    ForEach(Array(RadioStation.allCases.enumerated()), id: \.element) { slot, preset in
                        PresetKey(preset: preset, slot: slot + 1,
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
            .fill(Color(red: 0.10, green: 0.10, blue: 0.12))
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
    let lit: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            KeyFace(lit: lit) {
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            KeyFace(lit: on) {
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
    @ViewBuilder var content: Content
    @Environment(\.isFocused) private var isFocused

    private let amber = Color(red: 1.0, green: 0.72, blue: 0.19)

    var body: some View {
        content
            .foregroundStyle(lit ? Color(red: 0.15, green: 0.10, blue: 0.02) : .white.opacity(0.85))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(lit
                          ? LinearGradient(colors: [amber, Color(red: 0.85, green: 0.48, blue: 0.05)],
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
                .fill(Color(red: 0.13, green: 0.13, blue: 0.16))
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
