//
//  CustomizerModel.swift
//  Hot Wheels v Human
//
//  Working copy of a car (+driver) being designed. save() → SwiftData.
//

import CoreGraphics
import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class CustomizerModel {
    var design: CarDesign

    init(design: CarDesign? = nil) {
        self.design = design ?? Self.startingDesign()
    }

    /// Dev deep link `--demo-design` opens the customizer showing every
    /// customization feature at once — the screenshot-verification loop.
    private static func startingDesign() -> CarDesign {
        var design = CarDesign(
            id: UUID(), name: CustomizerModel.randomCarName(),
            chassis: .balancedFormula, tires: .standard,
            paint: PaintSpec(colorHex: "#FF6600", finish: .glossy))
        if ProcessInfo.processInfo.arguments.contains("--demo-design") {
            design.name = "Demo Dazzler"
            design.paint = PaintSpec(colorHex: "#2266FF", finish: .sparkle)
            design.partColors = [CarPaintSlot.wheels: "#FFD500"]
            design.wheelFinish = .metallic
            design.livery = LiverySpec(pattern: .flames, colorHex: "#FF3B30", scale: 1)
            design.stickers = [
                StickerPlacement(symbol: "star.fill", uv: [0.45, 0.5],
                                 scale: 1, rotation: 0.3, colorHex: "#FFD500"),
                StickerPlacement(symbol: "7.circle.fill", uv: [0.72, 0.42],
                                 scale: 1.2, rotation: 0, colorHex: "#F2F2F7"),
                StickerPlacement(symbol: "skull", uv: [0.18, 0.45],
                                 scale: 0.8, rotation: -0.2, colorHex: "#F2F2F7"),
            ]
            design.drawingPNG = Self.demoScribble()
        }
        return design
    }

    /// A crayon-style squiggle + smiley, standing in for a kid's drawing in
    /// the `--demo-design` screenshot loop.
    private static func demoScribble() -> Data? {
        let size = 512
        guard let ctx = CGContext(data: nil, width: size, height: size,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.setLineCap(.round)
        // Wavy green crayon stroke along the lower half (PNG top = car top,
        // so canvas rows map top-down; keep marks mid-band).
        ctx.setStrokeColor(CGColor(red: 0.2, green: 0.8, blue: 0.35, alpha: 0.95))
        ctx.setLineWidth(16)
        ctx.move(to: CGPoint(x: 30, y: 250))
        for i in 1...12 {
            ctx.addLine(to: CGPoint(x: 30 + i * 38, y: 250 + (i.isMultiple(of: 2) ? 34 : -34)))
        }
        ctx.strokePath()
        // Smiley, kid-wobbly.
        ctx.setStrokeColor(CGColor(red: 1, green: 0.85, blue: 0.1, alpha: 0.95))
        ctx.setLineWidth(12)
        ctx.strokeEllipse(in: CGRect(x: 350, y: 300, width: 90, height: 86))
        ctx.fillEllipse(in: CGRect(x: 375, y: 350, width: 12, height: 14))
        ctx.fillEllipse(in: CGRect(x: 405, y: 350, width: 12, height: 14))
        ctx.setLineWidth(8)
        ctx.addArc(center: CGPoint(x: 395, y: 336), radius: 24,
                   startAngle: .pi * 1.15, endAngle: .pi * 1.85, clockwise: false)
        ctx.strokePath()
        guard let image = ctx.makeImage() else { return nil }
        return OverlayComposer.encodePNGCapped(image)
    }

    // MARK: Undo (kid-first rule: always visible, unlimited, no confirmations)

    private(set) var undoStack: [CarDesign] = []
    private var restoring = false

    /// Called from the view's `.onChange(of: design)` with the old value.
    func designChanged(from old: CarDesign) {
        if restoring { restoring = false; return }
        undoStack.append(old)
        // drawingPNG (G4) makes snapshots up to 200 KB — cap the stack.
        if undoStack.count > 100 { undoStack.removeFirst() }
    }

    func undo() {
        guard let previous = undoStack.popLast() else {
            SoundBank.shared.play("nope_wobble")
            return
        }
        restoring = true
        design = previous
        SoundBank.shared.play("ui_back")
    }

    func save(into context: ModelContext) {
        context.saveDesign(design)
    }

    static func randomCarName() -> String {
        let first = ["Turbo", "Mega", "Rocket", "Thunder", "Blazing", "Wild",
                     "Lucky", "Cosmic", "Atomic", "Rapid"].randomElement()!
        let second = ["Comet", "Falcon", "Dragon", "Cheetah", "Lightning",
                      "Racer", "Streak", "Flash", "Bandit", "Zoomer"].randomElement()!
        return "\(first) \(second)"
    }
}
