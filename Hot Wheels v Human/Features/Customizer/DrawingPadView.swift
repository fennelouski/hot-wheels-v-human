//
//  DrawingPadView.swift
//  Hot Wheels v Human
//
//  Freehand drawing (G4, the flagship): PencilKit canvas over a toy-car
//  side silhouette. The drawing becomes the bottom layer of the paint-shell
//  overlay, mirrored on both sides (the side projection mirrors by
//  construction). Strokes stay editable for the session; the design stores
//  only the capped PNG.
//

import SwiftUI
// PKCanvasView (the interactive canvas) is a UIView — it exists on iOS,
// Catalyst and visionOS, but NOT on tvOS or a native macOS (AppKit) build.
// A drawing MADE on iPad still races and shows on every platform (it's stored
// as a PNG the paint shell decodes); only creating one needs this pad.
#if canImport(PencilKit) && !os(tvOS) && !os(macOS)
import PencilKit

struct DrawingPadView: View {
    @Binding var drawingPNG: Data?
    @Binding var drawingStrokes: Data?
    /// Session-held strokes so reopening the tab keeps the drawing editable.
    @Binding var strokes: PKDrawing
    /// Stamps placed from the pad — the design's sticker list (same layer
    /// the Stickers tab stamps onto the 3D car).
    @Binding var stickers: [StickerPlacement]?
    /// Length/height of the selected car's body mesh (PaintShell.bodyAspect).
    /// The pad matches it so what you draw keeps its shape on the car.
    var bodyAspect: CGFloat = 2.4

    @State private var inkColor = "#F2F2F7"
    @State private var inkWidth: CGFloat = 14
    @State private var erasing = false
    /// Armed stamp symbol: pad taps stamp instead of the pen drawing.
    @State private var armedStamp: String? = nil

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 16) {
                canvas
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                tools
            }
            stampStrip
        }
        .padding(.horizontal, 12)
    }

    private var tools: some View {
            LazyVGrid(columns: [GridItem(.fixed(52)), GridItem(.fixed(52))], spacing: 8) {
                ForEach(["#F2F2F7", "#FF3B30", "#FFD500", "#34C759", "#2266FF", "#1C1C1E"],
                        id: \.self) { hex in
                    Button {
                        inkColor = hex
                        erasing = false
                        SoundBank.shared.play("paint_spray")
                    } label: {
                        Circle().fill(Color(hex: hex))
                            .frame(width: 44, height: 44)
                            .overlay(Circle().stroke(
                                inkColor == hex && !erasing ? .yellow : .white.opacity(0.3),
                                lineWidth: inkColor == hex && !erasing ? 4 : 1))
                            .padding(4)   // with grid cell ≈ 60 pt target
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    erasing.toggle()
                    armedStamp = nil
                    SoundBank.shared.play("ui_tap")
                } label: {
                    Image(systemName: "eraser.fill")
                        .font(.system(size: 22))
                        .frame(width: 48, height: 48)
                        .background(erasing ? Color.yellow.opacity(0.3) : .white.opacity(0.08),
                                    in: Circle())
                }
                .buttonStyle(.plain)
                Button {
                    strokes = PKDrawing()
                    drawingPNG = nil
                    drawingStrokes = nil
                    SoundBank.shared.play("piece_delete_pop")
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 20))
                        .frame(width: 48, height: 48)
                        .background(.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .frame(width: 120)
            .padding(.trailing, 8)
    }

    /// The stamp shelf: arm one, then tap the pad to stamp it in the ink
    /// color. Stamps join the design's sticker list, so they show on the
    /// car like any sticker and the Undo button removes them.
    private var stampStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(OverlayComposer.stickerSheet, id: \.self) { symbol in
                    Button {
                        armedStamp = armedStamp == symbol ? nil : symbol
                        SoundBank.shared.play("ui_tap")
                    } label: {
                        Group {
                            if symbol == "skull", let skull = StickerShopView.skullImage {
                                Image(decorative: skull, scale: 1)
                                    .resizable()
                                    .scaledToFit()
                                    .padding(12)
                            } else {
                                Image(systemName: symbol)
                                    .font(.system(size: 26, weight: .bold))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(armedStamp == symbol ? Color.yellow.opacity(0.3) : .white.opacity(0.08),
                                    in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(
                            armedStamp == symbol ? .yellow : .white.opacity(0.2),
                            lineWidth: armedStamp == symbol ? 3 : 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private var canvas: some View {
        GeometryReader { geo in
            ZStack {
                CarSilhouette()
                    .fill(.white.opacity(0.10))
                CarSilhouette()
                    .stroke(.white.opacity(0.35), style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
                PencilCanvas(drawing: $strokes,
                             tool: erasing
                                ? PKEraserTool(.bitmap)
                                : PKInkingTool(.marker,
                                               color: PlatformColor(Color(hex: inkColor)),
                                               width: inkWidth),
                             onStrokesChanged: { commit(canvasSize: geo.size) })
                    .allowsHitTesting(armedStamp == nil)
                // Placed stamps, exactly where they sit on the car: the pad
                // IS the shell's UV square, so uv maps straight to the pad
                // (v flips — pad y is down). Sized/stretched like
                // OverlayComposer.draw(sticker:) renders them.
                ForEach(Array((stickers ?? []).enumerated()), id: \.offset) { _, sticker in
                    stampImage(sticker.symbol)
                        .foregroundStyle(Color(hex: sticker.colorHex))
                        .frame(width: stampSide(sticker, in: geo.size),
                               height: stampSide(sticker, in: geo.size))
                        .rotationEffect(.radians(-Double(sticker.rotation)))
                        .position(x: CGFloat(sticker.uv.x) * geo.size.width,
                                  y: (1 - CGFloat(sticker.uv.y)) * geo.size.height)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
                stamp(at: location, canvasSize: geo.size)
            }
        }
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
        .aspectRatio(max(1, min(bodyAspect, 5)), contentMode: .fit)
        .onAppear {
            // Reopened saved design: restore the editable strokes.
            if strokes.strokes.isEmpty, let data = drawingStrokes,
               let restored = try? PKDrawing(data: data) {
                strokes = restored
            }
        }
    }

    /// Tap with a stamp armed → sticker at that spot. Pad point == shell UV
    /// (v flipped), same clamp as stamping on the 3D car.
    private func stamp(at point: CGPoint, canvasSize: CGSize) {
        guard let symbol = armedStamp,
              canvasSize.width > 0, canvasSize.height > 0 else { return }
        let uv = SIMD2<Float>(Float(point.x / canvasSize.width),
                              Float(1 - point.y / canvasSize.height))
        var placed = stickers ?? []
        placed.append(StickerPlacement(symbol: symbol,
                                       uv: ShellGeometry.clampStickerUV(uv),
                                       scale: 1, rotation: 0, colorHex: inkColor))
        stickers = placed
        SoundBank.shared.play("customize_confirm_pop")
    }

    @ViewBuilder
    private func stampImage(_ symbol: String) -> some View {
        if symbol == "skull", let skull = StickerShopView.skullImage {
            Image(decorative: skull, scale: 1).resizable()
        } else {
            // Stretched to the square frame, matching how the overlay
            // renders the glyph into a square rect.
            Image(systemName: symbol).resizable()
        }
    }

    /// Sticker footprint on the pad: 0.22 of car height × scale — the pad's
    /// aspect already equals the body's, so a square here lands square on
    /// the car (same u-compression as OverlayComposer applies).
    private func stampSide(_ sticker: StickerPlacement, in size: CGSize) -> CGFloat {
        OverlayComposer.stickerBaseSize
            * CGFloat(max(0.3, min(sticker.scale, 4)))
            * size.height
    }

    /// Every stroke updates the design (kid sees the car change instantly);
    /// the 200 KB cap downsizes as needed. Output: a 1024² PNG of the whole
    /// pad stretched to fill UV [0,1]² — the paint shell maps that square
    /// onto the full body bounds (u = length, v = height), so a stroke lands
    /// on the car exactly where it sits over the silhouette. Stroke coords
    /// are in the canvas view's point space, hence the size parameter.
    private func commit(canvasSize: CGSize) {
        SoundBank.shared.play("paint_spray")
        guard !strokes.strokes.isEmpty else {
            drawingPNG = nil
            drawingStrokes = nil
            return
        }
        guard canvasSize.width > 0, canvasSize.height > 0 else { return }
        let drawn = strokes.image(from: CGRect(origin: .zero, size: canvasSize),
                                  scale: max(1, 1024 / canvasSize.width))
        // Through a CGImage so the PNG cap is the one shared cross-platform
        // path in OverlayComposer.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let square = UIGraphicsImageRenderer(size: CGSize(width: 1024, height: 1024),
                                             format: format)
            .image { _ in
                drawn.draw(in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
            }
        if let cg = square.cgImage {
            drawingPNG = OverlayComposer.encodePNGCapped(cg)
        }
        let data = strokes.dataRepresentation()
        drawingStrokes = data.count <= 200_000 ? data : nil
    }
}

/// Toy-car side profile used as the stencil background.
struct CarSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + w * 0.02, y: rect.minY + h * 0.78))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.05, y: rect.minY + h * 0.5))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.25, y: rect.minY + h * 0.45))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.35, y: rect.minY + h * 0.18))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.68, y: rect.minY + h * 0.18))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.78, y: rect.minY + h * 0.45))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.96, y: rect.minY + h * 0.52))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.98, y: rect.minY + h * 0.78))
        p.closeSubpath()
        // Wheels
        p.addEllipse(in: CGRect(x: rect.minX + w * 0.16, y: rect.minY + h * 0.62,
                                width: w * 0.16, height: w * 0.16))
        p.addEllipse(in: CGRect(x: rect.minX + w * 0.66, y: rect.minY + h * 0.62,
                                width: w * 0.16, height: w * 0.16))
        return p
    }
}

/// Thin PKCanvasView wrapper: transparent, finger/pointer drawing allowed.
/// Shared by the car drawing pad and the driver face pad. PKCanvasView is a
/// UIView, so this whole file is UIKit-only (see the top-of-file guard).
struct PencilCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    let tool: any PKTool
    let onStrokesChanged: () -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        let view = PKCanvasView()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.drawingPolicy = .anyInput
        view.drawing = drawing
        view.tool = tool
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ view: PKCanvasView, context: Context) {
        view.tool = tool
        if view.drawing != drawing {
            view.drawing = drawing
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let parent: PencilCanvas
        init(_ parent: PencilCanvas) { self.parent = parent }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard canvasView.drawing != parent.drawing else { return }
            parent.drawing = canvasView.drawing
            parent.onStrokesChanged()
        }
    }
}
#endif
