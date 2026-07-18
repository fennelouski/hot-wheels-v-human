//
//  PaintShopView.swift
//  Hot Wheels v Human
//
//  Kid-proof 12-swatch palette + part chips + finish picker. Applies live
//  to the turntable preview (tap the car's body/wheels there to switch part).
//

import SwiftUI

struct PaintShopView: View {
    @Binding var design: CarDesign
    /// Which part the swatches paint (`CarPaintSlot` name).
    @Binding var slot: String

    static let swatches = [
        "#FF3B30", "#FF6600", "#FFD500", "#34C759", "#00C7BE", "#2266FF",
        "#5856D6", "#AF52DE", "#FF2D92", "#8E5B3A", "#F2F2F7", "#1C1C1E",
    ]

    /// Body writes the base paint (wire-compatible); other slots overlay.
    private var slotHex: String {
        slot == CarPaintSlot.body
            ? design.paint.colorHex
            : design.partColors?[slot] ?? design.paint.colorHex
    }

    private func setSlotHex(_ hex: String) {
        if slot == CarPaintSlot.body {
            design.paint.colorHex = hex
        } else {
            var colors = design.partColors ?? [:]
            colors[slot] = hex
            design.partColors = colors
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                partChip("Body", symbol: "car.side.fill", name: CarPaintSlot.body)
                partChip("Wheels", symbol: "circle.circle.fill", name: CarPaintSlot.wheels)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(72)), count: 6), spacing: 14) {
                ForEach(Self.swatches, id: \.self) { hex in
                    Button {
                        setSlotHex(hex)
                        SoundBank.shared.play("paint_spray")
                    } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 62, height: 62)
                            .overlay(Circle().stroke(
                                slotHex == hex ? .yellow : .white.opacity(0.25),
                                lineWidth: slotHex == hex ? 5 : 2))
                    }
                    .buttonStyle(.plain)
                }
            }
            Picker("Finish", selection: $design.paint.finish) {
                Label("Metallic", systemImage: "sparkles").tag(PaintFinish.metallic)
                Label("Glossy", systemImage: "sun.max.fill").tag(PaintFinish.glossy)
                Label("Matte", systemImage: "square.fill").tag(PaintFinish.matte)
                Label("Sparkle", systemImage: "sparkle").tag(PaintFinish.sparkle)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 560)
            .onChange(of: design.paint.finish) {
                SoundBank.shared.play("customize_confirm_pop")
            }
        }
    }

    private func partChip(_ title: String, symbol: String, name: String) -> some View {
        Button {
            slot = name
            SoundBank.shared.play("ui_tap")
        } label: {
            Label(title, systemImage: symbol)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
                .background(slot == name ? Color.yellow.opacity(0.25) : .white.opacity(0.08),
                            in: Capsule())
                .overlay(Capsule().stroke(slot == name ? .yellow : .white.opacity(0.2),
                                          lineWidth: slot == name ? 3 : 1))
        }
        .buttonStyle(.plain)
    }
}

extension Color {
    init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex.replacingOccurrences(of: "#", with: "")).scanHexInt64(&value)
        self.init(red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }
}
