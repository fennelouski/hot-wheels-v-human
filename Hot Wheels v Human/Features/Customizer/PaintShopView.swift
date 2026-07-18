//
//  PaintShopView.swift
//  Hot Wheels v Human
//
//  Kid-proof 12-swatch palette + finish picker. Applies live to the
//  turntable preview.
//

import SwiftUI

struct PaintShopView: View {
    @Binding var paint: PaintSpec

    static let swatches = [
        "#FF3B30", "#FF6600", "#FFD500", "#34C759", "#00C7BE", "#2266FF",
        "#5856D6", "#AF52DE", "#FF2D92", "#8E5B3A", "#F2F2F7", "#1C1C1E",
    ]

    var body: some View {
        VStack(spacing: 20) {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(72)), count: 6), spacing: 14) {
                ForEach(Self.swatches, id: \.self) { hex in
                    Button {
                        paint.colorHex = hex
                        SoundBank.shared.play("paint_spray")
                    } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 62, height: 62)
                            .overlay(Circle().stroke(
                                paint.colorHex == hex ? .yellow : .white.opacity(0.25),
                                lineWidth: paint.colorHex == hex ? 5 : 2))
                    }
                    .buttonStyle(.plain)
                }
            }
            Picker("Finish", selection: $paint.finish) {
                Text("✨ Metallic").tag(PaintFinish.metallic)
                Text("💎 Glossy").tag(PaintFinish.glossy)
                Text("🧱 Matte").tag(PaintFinish.matte)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 460)
        }
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
