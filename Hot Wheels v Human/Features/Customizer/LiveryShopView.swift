//
//  LiveryShopView.swift
//  Hot Wheels v Human
//
//  Livery presets (G2): pattern chips (drawn by the same OverlayComposer
//  that textures the car — previews never lie), color swatches, size slider.
//

import SwiftUI

struct LiveryShopView: View {
    @Binding var livery: LiverySpec?

    var body: some View {
        VStack(spacing: 14) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    noneChip
                    ForEach(LiveryPattern.allCases, id: \.self) { pattern in
                        patternChip(pattern)
                    }
                }
                .padding(.horizontal, 16)
            }
            if livery != nil {
                HStack(spacing: 10) {
                    ForEach(PaintShopView.swatches, id: \.self) { hex in
                        Button {
                            livery?.colorHex = hex
                            SoundBank.shared.play("paint_spray")
                        } label: {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 44, height: 44)
                                .overlay(Circle().stroke(
                                    livery?.colorHex == hex ? .yellow : .white.opacity(0.25),
                                    lineWidth: livery?.colorHex == hex ? 4 : 1))
                                .padding(8)   // 60 pt effective target
                        }
                        .buttonStyle(.plain)
                    }
                }
                #if !os(tvOS)
                Slider(value: Binding(
                    get: { livery?.scale ?? 1 },
                    set: { livery?.scale = $0 }
                ), in: 0.5...2) {
                    Text("Size")
                } onEditingChanged: { editing in
                    if !editing { SoundBank.shared.play("ui_tap") }
                }
                .frame(maxWidth: 420)
                #endif
            }
        }
    }

    private var noneChip: some View {
        Button {
            livery = nil
            SoundBank.shared.play("customize_confirm_pop")
        } label: {
            VStack {
                Image(systemName: "circle.slash")
                    .font(.system(size: 34))
                Text("Plain")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            .frame(width: 84, height: 84)
            .background(livery == nil ? Color.yellow.opacity(0.25) : .white.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(
                livery == nil ? .yellow : .white.opacity(0.2),
                lineWidth: livery == nil ? 3 : 1))
        }
        .buttonStyle(.plain)
    }

    private func patternChip(_ pattern: LiveryPattern) -> some View {
        let selected = livery?.pattern == pattern
        return Button {
            var next = livery ?? LiverySpec(pattern: pattern, colorHex: "#F2F2F7", scale: 1)
            next.pattern = pattern
            livery = next
            SoundBank.shared.play("customize_confirm_pop")
        } label: {
            Group {
                if let image = Self.preview(pattern, colorHex: livery?.colorHex ?? "#F2F2F7") {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.white.opacity(0.08)
                }
            }
            .frame(width: 84, height: 84)
            .background(.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(
                selected ? .yellow : .white.opacity(0.2), lineWidth: selected ? 3 : 1))
        }
        .buttonStyle(.plain)
    }

    /// Small render of each pattern via the real compositor.
    private static func preview(_ pattern: LiveryPattern, colorHex: String) -> CGImage? {
        OverlayComposer.render(
            livery: LiverySpec(pattern: pattern, colorHex: colorHex, scale: 1),
            size: 168)
    }
}
