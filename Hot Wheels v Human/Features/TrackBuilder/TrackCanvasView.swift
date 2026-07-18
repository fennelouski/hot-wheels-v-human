//
//  TrackCanvasView.swift
//  Hot Wheels v Human
//
//  Top-down schematic of the solved track: piece footprints, the lane
//  centerline, start/finish flags. Auto-fits the whole layout — no pan
//  or zoom for little hands to get lost in.
//

import SwiftUI
import simd

struct TrackCanvasView: View {
    let layout: TrackLayout
    /// Thumbnail mode (preset/saved-track chips): no badges, thin centerline.
    var isThumbnail = false

    var body: some View {
        Canvas { context, size in
            let rects = layout.pieces.map(\.worldFootprint)
            guard !rects.isEmpty else { return }

            // World bounds → fit transform (world z = screen up; thumbnails
            // lie sideways so a mostly-straight track fills the wide chip).
            let minX = rects.map(\.minX).min()! - 0.2
            let maxX = rects.map(\.maxX).max()! + 0.2
            let minZ = rects.map(\.minZ).min()! - 0.2
            let maxZ = rects.map(\.maxZ).max()! + 0.2
            let spanX = CGFloat(maxX - minX), spanZ = CGFloat(maxZ - minZ)
            let scale = isThumbnail
                ? min(size.width / spanZ, size.height / spanX)
                : min(size.width / spanX, size.height / spanZ)
            func point(_ x: Float, _ z: Float) -> CGPoint {
                if isThumbnail {
                    // z runs left→right, x runs down (90° turn of the map).
                    return CGPoint(x: CGFloat(z - minZ) * scale
                                       + (size.width - spanZ * scale) / 2,
                                   y: CGFloat(x - minX) * scale
                                       + (size.height - spanX * scale) / 2)
                }
                return CGPoint(x: size.width - (CGFloat(x - minX) * scale
                                   + (size.width - spanX * scale) / 2),
                               y: size.height - (CGFloat(z - minZ) * scale
                                   + (size.height - spanZ * scale) / 2))
            }

            for piece in layout.pieces {
                let f = piece.worldFootprint
                let a = point(f.minX, f.minZ)
                let b = point(f.maxX, f.maxZ)
                let rect = CGRect(x: min(a.x, b.x), y: min(a.y, b.y),
                                  width: abs(b.x - a.x), height: abs(b.y - a.y))
                context.fill(Path(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerRadius: 6),
                             with: .color(color(piece.definition.type)))
            }

            var path = Path()
            let center = layout.lanes.center
            if let first = center.first {
                path.move(to: point(first.x, first.z))
                for p in center.dropFirst() {
                    path.addLine(to: point(p.x, p.z))
                }
            }
            context.stroke(path, with: .color(.white.opacity(0.85)),
                           style: isThumbnail
                               ? StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [3, 3])
                               : StrokeStyle(lineWidth: 3, lineCap: .round, dash: [7, 5]))

            guard !isThumbnail else { return }
            for piece in layout.pieces {
                let f = piece.worldFootprint
                let mid = point((f.minX + f.maxX) / 2, (f.minZ + f.maxZ) / 2)
                if let badge = piece.definition.type.symbolName {
                    context.draw(Text("\(Image(systemName: badge))")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white), at: mid)
                }
            }
        }
        .padding(isThumbnail ? 2 : 8)
    }

    private func color(_ type: PieceType) -> Color {
        switch type {
        case .startGate: .green.opacity(0.75)
        case .finishGate: .white.opacity(0.75)
        case .loop: .red.opacity(0.7)
        case .bump, .rampJump: .purple.opacity(0.65)
        case .hillUp, .hillDown: .brown.opacity(0.7)
        default: .orange.opacity(0.7)
        }
    }

}

/// SF Symbols for palette cards + canvas badges (CLAUDE.md: no emoji iconography).
extension PieceType {
    var symbolName: String? {
        switch self {
        case .straight: "arrow.up"
        case .curve90L: "arrow.turn.up.left"
        case .curve90R: "arrow.turn.up.right"
        case .curveLarge: "arrow.up.right"
        case .startGate: "flag.fill"
        case .finishGate: "flag.checkered"
        case .loop: "arrow.clockwise.circle"
        case .bump: "arrow.up.arrow.down"
        case .rampJump: "airplane.departure"
        case .hillUp: "chevron.up"
        case .hillDown: "chevron.down"
        default: nil
        }
    }
}
