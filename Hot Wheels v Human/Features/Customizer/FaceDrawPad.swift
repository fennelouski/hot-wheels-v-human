//
//  FaceDrawPad.swift
//  Hot Wheels v Human
//
//  Face paint for the driver (G4 follow-up): kid draws over the cartoon
//  reaction face; the PNG rides on CarDesign and the reaction cam
//  composites it over every expression. iPad only.
//

import SwiftUI
#if canImport(PencilKit) && !os(tvOS)
import PencilKit

struct FaceDrawPad: View {
    @Binding var faceDrawingPNG: Data?
    /// Session-held strokes (the design stores only the PNG).
    @Binding var strokes: PKDrawing

    @State private var inkColor = "#1C1C1E"

    private static let padSide: CGFloat = 190
    private static let pngSide: CGFloat = 512

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                DriverFaceView(state: .idle)
                PencilCanvas(drawing: $strokes,
                             tool: PKInkingTool(.marker,
                                                color: UIColor(Color(hex: inkColor)),
                                                width: 9),
                             onStrokesChanged: commit)
            }
            .frame(width: Self.padSide, height: Self.padSide)
            .background(.white.opacity(0.06), in: Circle())
            VStack(spacing: 8) {
                ForEach(["#1C1C1E", "#FF3B30", "#2266FF", "#F2F2F7"], id: \.self) { hex in
                    Button {
                        inkColor = hex
                        SoundBank.shared.play("paint_spray")
                    } label: {
                        Circle().fill(Color(hex: hex))
                            .frame(width: 36, height: 36)
                            .overlay(Circle().stroke(
                                inkColor == hex ? .yellow : .white.opacity(0.3),
                                lineWidth: inkColor == hex ? 3 : 1))
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    strokes = PKDrawing()
                    faceDrawingPNG = nil
                    SoundBank.shared.play("piece_delete_pop")
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 17))
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func commit() {
        SoundBank.shared.play("paint_spray")
        if strokes.strokes.isEmpty {
            faceDrawingPNG = nil
            return
        }
        let image = strokes.image(
            from: CGRect(x: 0, y: 0, width: Self.padSide, height: Self.padSide),
            scale: Self.pngSide / Self.padSide)
        faceDrawingPNG = OverlayComposer.encodePNGCapped(
            image, maxBytes: 64_000, maxWidth: Self.pngSide)
    }
}
#endif
