//
//  StickerShopView.swift
//  Hot Wheels v Human
//
//  Sticker sheet (G3): pick a sticker + color, then tap the car to stamp.
//  Drag moves the newest sticker, pinch resizes, two-finger twist rotates.
//

import SwiftUI

struct StickerShopView: View {
    /// The armed sticker symbol (nil = nothing armed).
    @Binding var armed: String?
    @Binding var colorHex: String

    var body: some View {
        VStack(spacing: 14) {
            Text(armed == nil ? "Pick a sticker!" : "Now tap your car!")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(armed == nil ? .white.opacity(0.7) : .yellow)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(OverlayComposer.stickerSheet, id: \.self) { symbol in
                        chip(symbol)
                    }
                }
                .padding(.horizontal, 16)
            }
            // Centered like every other bench — a short sheet pinned left
            // under centered prompt text reads as broken.
            .defaultScrollAnchor(.center)
            HStack(spacing: 10) {
                ForEach(PaintShopView.swatches, id: \.self) { hex in
                    Button {
                        colorHex = hex
                        SoundBank.shared.play("paint_spray")
                    } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 44, height: 44)
                            .overlay(Circle().stroke(
                                colorHex == hex ? .yellow : .white.opacity(0.25),
                                lineWidth: colorHex == hex ? 4 : 1))
                            .padding(8)   // 60 pt effective target
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func chip(_ symbol: String) -> some View {
        Button {
            armed = armed == symbol ? nil : symbol
            SoundBank.shared.play("ui_tap")
        } label: {
            Group {
                if symbol == "skull", let skull = Self.skullImage {
                    Image(decorative: skull, scale: 1)
                        .resizable()
                        .scaledToFit()
                        .padding(14)
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: 36, weight: .bold))
                }
            }
            .foregroundStyle(.white)
            .frame(width: 76, height: 76)
            .background(armed == symbol ? Color.yellow.opacity(0.3) : .white.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(
                armed == symbol ? .yellow : .white.opacity(0.2),
                lineWidth: armed == symbol ? 3 : 1))
        }
        .buttonStyle(.plain)
    }

    /// The one non-SF sticker, rendered by the same code that stamps it.
    private static let skullImage: CGImage? = {
        guard let ctx = CGContext(data: nil, width: 96, height: 96, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        OverlayComposer.drawSkull(in: CGRect(x: 0, y: 0, width: 96, height: 96),
                                  color: CGColor(red: 1, green: 1, blue: 1, alpha: 1),
                                  ctx: ctx)
        return ctx.makeImage()
    }()
}
