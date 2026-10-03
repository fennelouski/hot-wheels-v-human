import Foundation

#if canImport(PencilKit) && !os(tvOS) && !os(macOS)
import PencilKit
import UIKit

/// Owned by the car editor, not the disposable Draw tab. An imported raster
/// and the strokes above it must share the same lifetime.
struct CarDrawingSession {
    var strokes = PKDrawing()
    private(set) var rasterBase: Data?
    private var restored = false

    struct Export {
        let png: Data?
        let editableStrokes: Data?
    }

    mutating func prepareIfNeeded(png: Data?, editableStrokes: Data?) {
        guard !restored else { return }
        restore(png: png, editableStrokes: editableStrokes)
    }

    /// Also used after Undo: its saved PNG is authoritative. A raster-backed
    /// snapshot is restored as one base, so undone session strokes stay gone.
    mutating func restore(png: Data?, editableStrokes: Data?) {
        restored = true
        if let editableStrokes, let drawing = try? PKDrawing(data: editableStrokes) {
            strokes = drawing
            rasterBase = nil
        } else {
            strokes = PKDrawing()
            rasterBase = png
        }
    }

    mutating func clear() {
        strokes = PKDrawing()
        rasterBase = nil
        restored = true
    }

    func export(canvasSize: CGSize) -> Export? {
        guard !strokes.strokes.isEmpty else {
            return Export(png: rasterBase, editableStrokes: nil)
        }
        guard canvasSize.width > 0, canvasSize.height > 0 else { return nil }
        let drawn = strokes.image(from: CGRect(origin: .zero, size: canvasSize),
                                  scale: max(1, 1024 / canvasSize.width))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let rect = CGRect(x: 0, y: 0, width: 1024, height: 1024)
        let image = UIGraphicsImageRenderer(size: rect.size, format: format).image { _ in
            if let rasterBase, let base = UIImage(data: rasterBase) { base.draw(in: rect) }
            drawn.draw(in: rect)
        }
        guard let cg = image.cgImage, let png = OverlayComposer.encodePNGCapped(cg) else { return nil }
        let data = strokes.dataRepresentation()
        // PKDrawing alone cannot reconstruct an imported raster. Preserve the
        // merged PNG when reopening, rather than restoring only its top layer.
        return Export(png: png, editableStrokes: rasterBase == nil && data.count <= 200_000 ? data : nil)
    }
}
#endif
