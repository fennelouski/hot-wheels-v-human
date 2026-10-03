import Foundation
import Testing
@testable import Hot_Wheels_v_Human

#if canImport(PencilKit) && os(iOS)
import PencilKit
import UIKit

@MainActor
struct CarDrawingSessionTests {
    private let canvas = CGSize(width: 100, height: 100)

    /// A PNG-only TV drawing plus iPad strokes must keep both layers when
    /// the Draw child is recreated twice and then receives another stroke.
    @Test func rasterSurvivesTwoTabReentriesAndLaterPencilStroke() throws {
        let original = try basePNG()
        var session = CarDrawingSession()
        session.prepareIfNeeded(png: original, editableStrokes: nil)
        session.strokes = PKDrawing(strokes: [stroke(from: 60, to: 66)])
        let first = try #require(session.export(canvasSize: canvas))

        // These are the same restore calls new Draw views make on appearance.
        session.prepareIfNeeded(png: first.png, editableStrokes: first.editableStrokes)
        session.prepareIfNeeded(png: first.png, editableStrokes: first.editableStrokes)
        session.strokes.append(PKDrawing(strokes: [stroke(from: 78, to: 84)]))
        let final = try #require(session.export(canvasSize: canvas))
        let image = try pngImage(final.png)

        #expect(session.rasterBase == original)
        #expect(final.editableStrokes == nil)
        #expect(pixel(at: 0.20, in: image)[0] > 180) // original red raster
        #expect(pixel(at: 0.63, in: image)[2] > 180) // first blue pencil stroke
        #expect(pixel(at: 0.81, in: image)[2] > 180) // second blue pencil stroke
    }

    @Test func undoSnapshotRemovesLaterStrokesAndClearDoesNotResurrectRaster() throws {
        var session = CarDrawingSession()
        session.prepareIfNeeded(png: try basePNG(), editableStrokes: nil)
        session.strokes = PKDrawing(strokes: [stroke(from: 60, to: 66)])
        let beforeLaterStroke = try #require(session.export(canvasSize: canvas))
        session.strokes.append(PKDrawing(strokes: [stroke(from: 78, to: 84)]))
        session.restore(png: beforeLaterStroke.png, editableStrokes: beforeLaterStroke.editableStrokes)
        #expect(session.strokes.strokes.isEmpty)
        session.strokes.append(PKDrawing(strokes: [stroke(from: 90, to: 96)]))
        let afterUndo = try pngImage(try #require(session.export(canvasSize: canvas)).png)

        #expect(pixel(at: 0.20, in: afterUndo)[0] > 180)
        #expect(pixel(at: 0.63, in: afterUndo)[2] > 180)
        #expect(pixel(at: 0.81, in: afterUndo)[3] == 0) // undone stroke stays gone
        #expect(pixel(at: 0.93, in: afterUndo)[2] > 180)

        session.clear()
        session.prepareIfNeeded(png: beforeLaterStroke.png, editableStrokes: nil)
        let cleared = try #require(session.export(canvasSize: canvas))
        #expect(cleared.png == nil)
        #expect(cleared.editableStrokes == nil)
        #expect(session.rasterBase == nil)
        #expect(session.strokes.strokes.isEmpty)
    }

    private func stroke(from x1: CGFloat, to x2: CGFloat) -> PKStroke {
        let points = [x1, x2].enumerated().map { index, x in
            PKStrokePoint(location: CGPoint(x: x, y: 50), timeOffset: Double(index) * 0.1,
                          size: CGSize(width: 8, height: 8), opacity: 1, force: 1,
                          azimuth: 0, altitude: .pi / 2)
        }
        return PKStroke(ink: PKInk(.pen, color: .blue),
                        path: PKStrokePath(controlPoints: points, creationDate: Date(timeIntervalSince1970: 0)))
    }

    private func basePNG() throws -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: canvas, format: format).image { context in
            context.cgContext.setFillColor(UIColor.red.cgColor)
            context.cgContext.fill(CGRect(x: 10, y: 45, width: 20, height: 10))
        }
        return try #require(image.pngData())
    }

    private func pngImage(_ data: Data?) throws -> CGImage {
        let png = try #require(data)
        return try #require(UIImage(data: png)?.cgImage)
    }

    private func pixel(at u: CGFloat, in image: CGImage) -> [UInt8] {
        let x = min(image.width - 1, Int(u * CGFloat(image.width)))
        let y = image.height / 2
        var rgba = [UInt8](repeating: 0, count: 4)
        let context = CGContext(data: &rgba, width: 1, height: 1, bitsPerComponent: 8,
                                bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: -x, y: -y, width: image.width, height: image.height))
        return rgba
    }
}
#endif
