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
#if canImport(PencilKit) && !os(tvOS)
import PencilKit

struct DrawingPadView: View {
    @Binding var drawingPNG: Data?
    @Binding var drawingStrokes: Data?
    /// Session-held strokes so reopening the tab keeps the drawing editable.
    @Binding var strokes: PKDrawing

    @State private var inkColor = "#F2F2F7"
    @State private var inkWidth: CGFloat = 14
    @State private var erasing = false

    var body: some View {
        HStack(spacing: 16) {
            canvas
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .padding(.horizontal, 12)
    }

    private var canvas: some View {
        ZStack {
            CarSilhouette()
                .fill(.white.opacity(0.10))
            CarSilhouette()
                .stroke(.white.opacity(0.35), style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
            PencilCanvas(drawing: $strokes,
                         tool: erasing
                            ? PKEraserTool(.bitmap)
                            : PKInkingTool(.marker,
                                           color: UIColor(Color(hex: inkColor)),
                                           width: inkWidth),
                         onStrokesChanged: commit)
        }
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
        .aspectRatio(2.4, contentMode: .fit)
        .onAppear {
            // Reopened saved design: restore the editable strokes.
            if strokes.strokes.isEmpty, let data = drawingStrokes,
               let restored = try? PKDrawing(data: data) {
                strokes = restored
            }
        }
    }

    /// Every stroke updates the design (kid sees the car change instantly);
    /// the 200 KB cap downsizes as needed.
    private func commit() {
        SoundBank.shared.play("paint_spray")
        let bounds = CGRect(x: 0, y: 0, width: 1024, height: 1024 / 2.4)
        var image = strokes.image(from: bounds, scale: 1)
        // Pad onto a square so UV [0,1]² lines up: drawing occupies the
        // vertical middle band of the car side.
        image = UIGraphicsImageRenderer(size: CGSize(width: 1024, height: 1024))
            .image { _ in
                image.draw(in: CGRect(x: 0, y: (1024 - bounds.height) / 2,
                                      width: 1024, height: bounds.height))
            }
        if strokes.strokes.isEmpty {
            drawingPNG = nil
            drawingStrokes = nil
        } else {
            drawingPNG = OverlayComposer.encodePNGCapped(image)
            let data = strokes.dataRepresentation()
            drawingStrokes = data.count <= 200_000 ? data : nil
        }
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

/// Thin PKCanvasView wrapper: transparent, finger drawing allowed.
/// Shared by the car drawing pad and the driver face pad.
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
