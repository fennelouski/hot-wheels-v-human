import SwiftUI

#if os(tvOS)
import UIKit
struct TVPaintShopView: View {
    @Binding var design: CarDesign
    @Binding var slot: String

    private var color: Binding<String> {
        Binding(get: { slot == CarPaintSlot.body ? design.paint.colorHex : design.partColors?[slot] ?? design.paint.colorHex },
                set: { value in
                    if slot == CarPaintSlot.body { design.paint.colorHex = value }
                    else { var colors = design.partColors ?? [:]; colors[slot] = value; design.partColors = colors }
                })
    }

    private var finish: Binding<PaintFinish> {
        slot == CarPaintSlot.wheels
            ? Binding(get: { design.wheelFinish ?? .matte }, set: { design.wheelFinish = $0 })
            : $design.paint.finish
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            ChipRow(chips: [.init(value: CarPaintSlot.body, title: "Body", symbol: "car.side.fill"),
                             .init(value: CarPaintSlot.wheels, title: "Wheels", symbol: "circle.circle.fill")], selection: $slot)
            TVColorPalette(title: "Color", options: PaintShopView.swatches, selection: color)
            ChipRow(chips: [.init(value: PaintFinish.metallic, title: "Metallic", symbol: "sparkles"),
                            .init(value: .glossy, title: "Glossy", symbol: "sun.max.fill"),
                            .init(value: .matte, title: "Matte", symbol: "square.fill"),
                            .init(value: .sparkle, title: "Sparkle", symbol: "sparkle")], selection: finish)
        }
    }
}

struct TVLiveryShopView: View {
    @Binding var livery: LiverySpec?

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 20)], spacing: 20) {
                Button { livery = nil } label: { Label("Plain", systemImage: "circle.slash").frame(minHeight: 84) }
                    .buttonStyle(TVWorkshopButtonStyle(selected: livery == nil))
                ForEach(LiveryPattern.allCases, id: \.self) { pattern in
                    Button {
                        var next = livery ?? LiverySpec(pattern: pattern, colorHex: "#F2F2F7", scale: 1)
                        next.pattern = pattern
                        livery = next
                        SoundBank.shared.play("customize_confirm_pop")
                    } label: {
                        VStack(spacing: 10) {
                            if let image = OverlayComposer.render(livery: LiverySpec(pattern: pattern, colorHex: "#F2F2F7", scale: 1), size: 168) {
                                Image(decorative: image, scale: 1).resizable().frame(width: 110, height: 80)
                            }
                            Text(name(pattern)).font(.system(size: 22, weight: .bold, design: .rounded))
                                .multilineTextAlignment(.center)
                        }
                        .padding(12)
                    }
                    .buttonStyle(TVWorkshopButtonStyle(selected: livery?.pattern == pattern))
                }
            }
            if let current = livery {
                TVColorPalette(title: "Pattern Color", options: PaintShopView.swatches,
                               selection: Binding(get: { livery?.colorHex ?? "#F2F2F7" }, set: { livery?.colorHex = $0 }))
                TVAdjustmentRow(title: "Pattern Size", value: String(format: "%.1f×", current.scale),
                                canDecrease: current.scale > 0.5, canIncrease: current.scale < 2,
                                decrease: { livery?.scale = max(0.5, current.scale - 0.1) },
                                increase: { livery?.scale = min(2, current.scale + 0.1) })
            }
        }
    }

    private func name(_ pattern: LiveryPattern) -> String {
        switch pattern {
        case .racingStripes: "Racing Stripes"
        case .flames: "Flames"
        case .polkaDots: "Polka Dots"
        case .lightningBolt: "Lightning"
        case .checkerboard: "Checkerboard"
        case .starField: "Stars"
        case .zigzag: "Zigzag"
        }
    }
}

struct TVStickerEditor: View {
    @Binding var stickers: [StickerPlacement]?
    @State private var armed = OverlayComposer.stickerSheet[0]
    @State private var newColor = "#F2F2F7"
    @State private var selectedIndex = 0

    private var count: Int { stickers?.count ?? 0 }
    private var current: StickerPlacement? {
        guard let stickers, stickers.indices.contains(selectedIndex) else { return nil }
        return stickers[selectedIndex]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 86), spacing: 18)], spacing: 18) {
                ForEach(OverlayComposer.stickerSheet, id: \.self) { symbol in
                    Button { armed = symbol } label: {
                        stickerImage(symbol).frame(width: 62, height: 62).padding(10)
                    }
                    .buttonStyle(TVWorkshopButtonStyle(selected: armed == symbol))
                    .accessibilityLabel(stickerName(symbol))
                }
            }
            Button(action: add) { Label("Add Sticker", systemImage: "plus.circle.fill") }
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .buttonStyle(TVWorkshopButtonStyle())
                .accessibilityIdentifier("tv-add-sticker")
            if let current {
                TVAdjustmentRow(title: "Sticker", value: "\(selectedIndex + 1) / \(count)",
                                canDecrease: selectedIndex > 0, canIncrease: selectedIndex + 1 < count,
                                decrease: { selectedIndex -= 1 }, increase: { selectedIndex += 1 })
                TVAdjustmentRow(title: "Position Across", value: "\(Int(current.uv.x * 100))%",
                                canDecrease: current.uv.x > 0.02, canIncrease: current.uv.x < 0.98,
                                decrease: { edit { $0.uv = ShellGeometry.clampStickerUV($0.uv - SIMD2(0.025, 0)) } },
                                increase: { edit { $0.uv = ShellGeometry.clampStickerUV($0.uv + SIMD2(0.025, 0)) } })
                TVAdjustmentRow(title: "Position Up", value: "\(Int(current.uv.y * 100))%",
                                canDecrease: current.uv.y > 0.02, canIncrease: current.uv.y < 0.98,
                                decrease: { edit { $0.uv = ShellGeometry.clampStickerUV($0.uv - SIMD2(0, 0.025)) } },
                                increase: { edit { $0.uv = ShellGeometry.clampStickerUV($0.uv + SIMD2(0, 0.025)) } })
                TVAdjustmentRow(title: "Sticker Size", value: String(format: "%.1f×", current.scale),
                                canDecrease: current.scale > 0.3, canIncrease: current.scale < 4,
                                decrease: { edit { $0.scale = max(0.3, $0.scale - 0.1) } },
                                increase: { edit { $0.scale = min(4, $0.scale + 0.1) } })
                TVAdjustmentRow(title: "Rotation", value: "\(Int(current.rotation * 180 / .pi))°",
                                decrease: { edit { $0.rotation -= .pi / 12 } },
                                increase: { edit { $0.rotation += .pi / 12 } })
                Button(role: .destructive, action: remove) { Label("Remove Sticker", systemImage: "trash.fill") }
                    .buttonStyle(TVWorkshopButtonStyle())
                    .accessibilityIdentifier("tv-remove-sticker")
            }
            TVColorPalette(title: "Sticker Color", options: PaintShopView.swatches,
                           selection: Binding(get: { current?.colorHex ?? newColor }, set: { value in
                               newColor = value
                               edit { $0.colorHex = value }
                           }))
        }
        .onChange(of: count) { _, newCount in selectedIndex = max(0, min(selectedIndex, newCount - 1)) }
    }

    private func edit(_ change: (inout StickerPlacement) -> Void) {
        guard var list = stickers, list.indices.contains(selectedIndex) else { return }
        change(&list[selectedIndex])
        stickers = list
        SoundBank.shared.play("ui_tap")
    }

    private func add() {
        var list = stickers ?? []
        list.append(StickerPlacement(symbol: armed, uv: [0.5, 0.5], scale: 1, rotation: 0, colorHex: newColor))
        stickers = list
        selectedIndex = list.count - 1
        SoundBank.shared.play("customize_confirm_pop")
    }

    private func remove() {
        guard var list = stickers, list.indices.contains(selectedIndex) else { return }
        list.remove(at: selectedIndex)
        stickers = list.isEmpty ? nil : list
        selectedIndex = max(0, min(selectedIndex, list.count - 1))
        SoundBank.shared.play("piece_delete_pop")
    }

    @ViewBuilder private func stickerImage(_ symbol: String) -> some View {
        if symbol == "skull", let image = StickerShopView.skullImage {
            Image(decorative: image, scale: 1).resizable().scaledToFit()
        } else { Image(systemName: symbol).font(.system(size: 38, weight: .bold)) }
    }

    private func stickerName(_ symbol: String) -> String {
        switch symbol {
        case "star.fill": "Star"
        case "heart.fill": "Heart"
        case "bolt.fill": "Lightning Bolt"
        case "flame.fill": "Flame"
        case "eyes": "Eyes"
        case "mouth.fill": "Mouth"
        case "pawprint.fill": "Paw Print"
        case "rainbow": "Rainbow"
        case "skull": "Skull"
        default: "Number \(symbol.prefix(1))"
        }
    }
}

/// Selectable direction tools provide drawing without touch or PencilKit.
/// The same capped PNG drawing layer travels with the car and races on iPad.
struct TVDrawingPadView: View {
    @Binding var drawingPNG: Data?
    @Binding var drawingStrokes: Data?
    @State private var cursor = CGPoint(x: 0.5, y: 0.5)
    @State private var penDown = false
    @State private var erasing = false
    @State private var inkColor = "#F2F2F7"
    @State private var inkWidth: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            GeometryReader { geometry in
                ZStack {
                    Rectangle().fill(.white.opacity(0.08))
                    if let data = drawingPNG, let image = UIImage(data: data) {
                        Image(uiImage: image).resizable()
                    }
                    Image(systemName: erasing ? "eraser.fill" : "pencil.tip.crop.circle.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.yellow)
                        .background(.black.opacity(0.8), in: Circle())
                        .position(x: cursor.x * geometry.size.width, y: cursor.y * geometry.size.height)
                }
            }
            .frame(height: 220)
            .accessibilityLabel("Car drawing preview")
            HStack(spacing: 16) {
                Button { penDown.toggle(); if penDown { draw(from: cursor, to: cursor) } } label: {
                    Label(penDown ? "Pen Down" : "Pen Up", systemImage: penDown ? "pencil.tip" : "pencil.slash")
                }
                .buttonStyle(TVWorkshopButtonStyle(selected: penDown))
                .accessibilityIdentifier("tv-drawing-pen")
                Button { erasing.toggle() } label: { Label("Eraser", systemImage: "eraser.fill") }
                    .buttonStyle(TVWorkshopButtonStyle(selected: erasing))
            }
            HStack(spacing: 16) {
                moveButton("Left", symbol: "arrow.left", dx: -0.025, dy: 0)
                moveButton("Up", symbol: "arrow.up", dx: 0, dy: -0.025)
                moveButton("Down", symbol: "arrow.down", dx: 0, dy: 0.025)
                moveButton("Right", symbol: "arrow.right", dx: 0.025, dy: 0)
            }
            Text(penDown ? "Move to draw. Lift the pen to move without a mark." : "Move to a spot, then lower the pen.")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
            TVAdjustmentRow(title: "Brush Width", value: "\(Int(inkWidth))",
                            canDecrease: inkWidth > 4, canIncrease: inkWidth < 48,
                            decrease: { inkWidth = max(4, inkWidth - 4) }, increase: { inkWidth = min(48, inkWidth + 4) })
            TVColorPalette(title: "Ink", options: PaintShopView.swatches, selection: $inkColor)
            Button(role: .destructive) {
                drawingPNG = nil
                drawingStrokes = nil
                SoundBank.shared.play("piece_delete_pop")
            } label: { Label("Clear Drawing", systemImage: "trash.fill") }
            .buttonStyle(TVWorkshopButtonStyle())
        }
        .font(.system(size: 24, weight: .heavy, design: .rounded))
    }

    private func moveButton(_ title: String, symbol: String, dx: CGFloat, dy: CGFloat) -> some View {
        Button {
            let next = CGPoint(x: min(0.98, max(0.02, cursor.x + dx)), y: min(0.98, max(0.02, cursor.y + dy)))
            if penDown { draw(from: cursor, to: next) }
            cursor = next
        } label: { Label(title, systemImage: symbol) }
        .buttonStyle(TVWorkshopButtonStyle())
    }

    private func draw(from start: CGPoint, to end: CGPoint) {
        let side: CGFloat = 1024
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { rendered in
            if let drawingPNG, let old = UIImage(data: drawingPNG) {
                old.draw(in: CGRect(x: 0, y: 0, width: side, height: side))
            }
            let context = rendered.cgContext
            context.setBlendMode(erasing ? .clear : .normal)
            context.setStrokeColor(UIColor(Color(hex: inkColor)).cgColor)
            context.setFillColor(UIColor(Color(hex: inkColor)).cgColor)
            context.setLineWidth(inkWidth)
            context.setLineCap(.round)
            if start == end {
                context.fillEllipse(in: CGRect(x: end.x * side - inkWidth / 2, y: end.y * side - inkWidth / 2, width: inkWidth, height: inkWidth))
            } else {
                context.move(to: CGPoint(x: start.x * side, y: start.y * side))
                context.addLine(to: CGPoint(x: end.x * side, y: end.y * side))
                context.strokePath()
            }
        }
        guard let cg = image.cgImage, let encoded = OverlayComposer.encodePNGCapped(cg) else { return }
        drawingPNG = encoded
        // A TV raster edit supersedes the old PencilKit stroke representation.
        // Keeping it would restore an older drawing when the car is edited on iPad.
        drawingStrokes = nil
        SoundBank.shared.play("paint_spray")
    }
}
#endif
