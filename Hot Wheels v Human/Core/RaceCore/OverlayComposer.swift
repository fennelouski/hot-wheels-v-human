//
//  OverlayComposer.swift
//  Hot Wheels v Human
//
//  Renders the paint-shell overlay texture (CUSTOMIZATION-GRAPHICS.md):
//  livery + stickers + drawing composited in layers with CGContext.
//  Pure CoreGraphics, no SwiftUI — unit-testable off-main.
//
//  Coordinates: UV space, u = along the car (0 = nose), v = height
//  (0 = bottom). The CG context is set up so drawing uses that space.
//

import CoreGraphics
import Foundation
#if canImport(UIKit)
import UIKit
#endif

nonisolated enum OverlayComposer {

    static let textureSize = 1024

    /// Composite the full overlay (livery, then stickers on top). Nil when
    /// there is nothing to draw — callers then remove the shell entirely.
    /// `bodyAspect` = car length / height; stickers shrink on the u axis by
    /// it so they stay round on the car instead of smearing lengthwise.
    /// `sparkleFillHex`: sparkle paint fills the whole overlay with this
    /// color at low alpha first — an alpha-blended shell contributes no
    /// specular where it's fully transparent, so without the film the
    /// glitter would only appear on livery/sticker pixels.
    static func render(livery: LiverySpec?, stickers: [StickerPlacement]? = nil,
                       drawing: Data? = nil, bodyAspect: CGFloat = 1,
                       sparkleFillHex: String? = nil,
                       size: Int = textureSize) -> CGImage? {
        let stickers = stickers ?? []
        guard livery != nil || !stickers.isEmpty || drawing != nil
                || sparkleFillHex != nil else { return nil }
        guard let ctx = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        // Map UV [0,1]² onto the pixel grid (CG origin is bottom-left,
        // matching v = 0 at the car's bottom).
        ctx.scaleBy(x: CGFloat(size), y: CGFloat(size))

        if let sparkleFillHex {
            ctx.setFillColor(cgColor(hex: sparkleFillHex, alpha: 0.32))
            ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        // Bottom layer: the kid's drawing (canvas y-down → flip into UV space).
        if let drawing, let provider = CGDataProvider(data: drawing as CFData),
           let image = CGImage(pngDataProviderSource: provider, decode: nil,
                               shouldInterpolate: true, intent: .defaultIntent) {
            ctx.saveGState()
            ctx.translateBy(x: 0, y: 1)
            ctx.scaleBy(x: 1, y: -1)
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            ctx.restoreGState()
        }
        if let livery {
            draw(livery: livery, in: ctx)
        }
        for sticker in stickers {
            draw(sticker: sticker, bodyAspect: bodyAspect, in: ctx)
        }
        return ctx.makeImage()
    }

    // MARK: Stickers

    /// The sticker sheet (SF Symbols; "skull" is drawn by hand — no cute
    /// skull in SF Symbols). No emoji (CLAUDE.md).
    static let stickerSheet: [String] = [
        "star.fill", "heart.fill", "bolt.fill", "flame.fill",
        "eyes", "mouth.fill", "pawprint.fill", "rainbow", "skull",
    ] + (0...9).map { "\($0).circle.fill" }

    /// Base sticker footprint as a fraction of the car side (× placement.scale).
    static let stickerBaseSize: CGFloat = 0.22

    static func draw(sticker: StickerPlacement, bodyAspect: CGFloat = 1,
                     in ctx: CGContext) {
        let side = stickerBaseSize * CGFloat(max(0.3, min(sticker.scale, 4)))
        ctx.saveGState()
        ctx.translateBy(x: CGFloat(sticker.uv.x), y: CGFloat(sticker.uv.y))
        // Undo the u-axis stretch first so rotation happens in square space.
        ctx.scaleBy(x: 1 / max(bodyAspect, 0.1), y: 1)
        ctx.rotate(by: CGFloat(sticker.rotation))
        let rect = CGRect(x: -side / 2, y: -side / 2, width: side, height: side)
        if sticker.symbol == "skull" {
            drawSkull(in: rect, color: cgColor(hex: sticker.colorHex), ctx: ctx)
        } else {
            #if canImport(UIKit)
            if let cgImage = symbolImage(sticker.symbol, hex: sticker.colorHex) {
                ctx.draw(cgImage, in: rect)
            }
            #endif
        }
        ctx.restoreGState()
    }

    #if canImport(UIKit)
    private static func symbolImage(_ name: String, hex: String) -> CGImage? {
        let config = UIImage.SymbolConfiguration(pointSize: 200)
        guard let image = UIImage(systemName: name, withConfiguration: config)?
            .withTintColor(UIColor(cgColor: cgColor(hex: hex))) else { return nil }
        // Re-render so the tint bakes into the bitmap, flipped so it lands
        // upright in our bottom-left-origin UV space.
        let renderer = UIGraphicsImageRenderer(size: image.size)
        let flipped = renderer.image { rendererCtx in
            rendererCtx.cgContext.translateBy(x: 0, y: image.size.height)
            rendererCtx.cgContext.scaleBy(x: 1, y: -1)
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        return flipped.cgImage
    }
    #endif

    /// Skull-but-cute: round head, big eye dots, tiny grin teeth.
    static func drawSkull(in rect: CGRect, color: CGColor, ctx: CGContext) {
        let w = rect.width, h = rect.height
        ctx.setFillColor(color)
        // Head (upper 2/3) + jaw block.
        ctx.fillEllipse(in: CGRect(x: rect.minX, y: rect.minY + h * 0.3,
                                   width: w, height: h * 0.7))
        ctx.fill(CGRect(x: rect.minX + w * 0.22, y: rect.minY + h * 0.08,
                        width: w * 0.56, height: h * 0.34))
        // Punch out eyes + teeth gaps.
        ctx.setBlendMode(.clear)
        let eye = w * 0.2
        ctx.fillEllipse(in: CGRect(x: rect.minX + w * 0.2, y: rect.minY + h * 0.5,
                                   width: eye, height: eye * 1.15))
        ctx.fillEllipse(in: CGRect(x: rect.maxX - w * 0.2 - eye, y: rect.minY + h * 0.5,
                                   width: eye, height: eye * 1.15))
        for i in 1...2 {
            ctx.fill(CGRect(x: rect.minX + w * (0.22 + 0.19 * CGFloat(i)),
                            y: rect.minY + h * 0.08, width: w * 0.025, height: h * 0.3))
        }
        ctx.setBlendMode(.normal)
    }

    static func draw(livery: LiverySpec, in ctx: CGContext) {
        let color = cgColor(hex: livery.colorHex, alpha: 0.92)
        let s = CGFloat(max(0.25, min(livery.scale, 3)))
        ctx.setFillColor(color)
        ctx.setStrokeColor(color)

        switch livery.pattern {
        case .racingStripes:
            // Two lengthwise stripes across the upper body.
            let w = 0.055 * s
            ctx.fill(CGRect(x: 0, y: 0.58, width: 1, height: w))
            ctx.fill(CGRect(x: 0, y: 0.58 + w * 1.8, width: 1, height: w))

        case .flames:
            // Flame teeth licking back from the nose (u = 0).
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 0, y: 0.62))
            let teeth = 5
            for i in 0..<teeth {
                let base = 0.62 - CGFloat(i) * 0.62 / CGFloat(teeth)
                let next = 0.62 - CGFloat(i + 1) * 0.62 / CGFloat(teeth)
                let reach = (0.18 + 0.16 * CGFloat(teeth - i)) * s
                path.addCurve(to: CGPoint(x: reach, y: (base + next) / 2),
                              control1: CGPoint(x: reach * 0.4, y: base),
                              control2: CGPoint(x: reach * 0.9, y: base))
                path.addCurve(to: CGPoint(x: 0.02, y: next),
                              control1: CGPoint(x: reach * 0.5, y: next),
                              control2: CGPoint(x: 0.1, y: next))
            }
            path.closeSubpath()
            ctx.addPath(path)
            ctx.fillPath()

        case .polkaDots:
            let r = 0.05 * s
            for row in 0..<6 {
                for col in 0..<8 {
                    let offset = row.isMultiple(of: 2) ? 0.0 : 0.0625
                    let center = CGPoint(x: CGFloat(col) * 0.125 + offset + 0.03,
                                         y: CGFloat(row) * 0.16 + 0.08)
                    ctx.fillEllipse(in: CGRect(x: center.x - r, y: center.y - r,
                                               width: r * 2, height: r * 2))
                }
            }

        case .lightningBolt:
            // One chunky bolt, nose-high to tail-low.
            let path = CGMutablePath()
            let points: [(CGFloat, CGFloat)] = [
                (0.15, 0.9), (0.55, 0.9), (0.45, 0.62), (0.85, 0.62),
                (0.35, 0.12), (0.5, 0.5), (0.15, 0.5),
            ]
            path.move(to: CGPoint(x: points[0].0, y: points[0].1))
            for (x, y) in points.dropFirst() {
                path.addLine(to: CGPoint(x: 0.5 + (x - 0.5) * s, y: 0.5 + (y - 0.5) * s))
            }
            path.closeSubpath()
            ctx.addPath(path)
            ctx.fillPath()

        case .checkerboard:
            let cell = 0.11 * s
            var y: CGFloat = 0
            var row = 0
            while y < 1 {
                var x: CGFloat = row.isMultiple(of: 2) ? 0 : cell
                while x < 1 {
                    ctx.fill(CGRect(x: x, y: y, width: cell, height: cell))
                    x += cell * 2
                }
                y += cell
                row += 1
            }

        case .starField:
            // Deterministic scatter — same design renders the same texture.
            var seed: UInt64 = 0x5EED
            func rand() -> CGFloat {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                return CGFloat(seed >> 33) / CGFloat(UInt32.max)
            }
            for _ in 0..<14 {
                star(center: CGPoint(x: rand(), y: rand() * 0.9 + 0.05),
                     radius: (0.03 + rand() * 0.05) * s, in: ctx)
            }

        case .zigzag:
            let path = CGMutablePath()
            let amplitude = 0.09 * s
            let mid: CGFloat = 0.5
            path.move(to: CGPoint(x: 0, y: mid - amplitude))
            var x: CGFloat = 0
            var up = true
            while x < 1 {
                x += 0.125
                path.addLine(to: CGPoint(x: x, y: up ? mid + amplitude : mid - amplitude))
                up.toggle()
            }
            ctx.addPath(path)
            ctx.setLineWidth(0.05 * s)
            ctx.setLineJoin(.miter)
            ctx.strokePath()
        }
    }

    private static func star(center: CGPoint, radius: CGFloat, in ctx: CGContext) {
        let path = CGMutablePath()
        for i in 0..<10 {
            let angle = CGFloat(i) * .pi / 5 - .pi / 2
            let r = i.isMultiple(of: 2) ? radius : radius * 0.45
            let pt = CGPoint(x: center.x + cos(angle) * r,
                             y: center.y + sin(angle) * r)
            i == 0 ? path.move(to: pt) : path.addLine(to: pt)
        }
        path.closeSubpath()
        ctx.addPath(path)
        ctx.fillPath()
    }

    #if canImport(UIKit)
    /// PNG-encode at most `maxBytes`, downscaling ×0.7 until it fits
    /// (CUSTOMIZATION-GRAPHICS.md: 200 KB cap, enforced at save time).
    static func encodePNGCapped(_ image: UIImage, maxBytes: Int = 200_000,
                                maxWidth: CGFloat = 1024) -> Data? {
        var current = image
        if current.size.width > maxWidth {
            current = resized(current, width: maxWidth)
        }
        for _ in 0..<8 {
            guard let data = current.pngData() else { return nil }
            if data.count <= maxBytes { return data }
            current = resized(current, width: current.size.width * 0.7)
        }
        return nil
    }

    private static func resized(_ image: UIImage, width: CGFloat) -> UIImage {
        let size = CGSize(width: width,
                          height: width * image.size.height / max(image.size.width, 1))
        return UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    #endif

    static func cgColor(hex: String, alpha: CGFloat = 1) -> CGColor {
        var value: UInt64 = 0
        Scanner(string: hex.replacingOccurrences(of: "#", with: "")).scanHexInt64(&value)
        return CGColor(red: CGFloat((value >> 16) & 0xFF) / 255,
                       green: CGFloat((value >> 8) & 0xFF) / 255,
                       blue: CGFloat(value & 0xFF) / 255, alpha: alpha)
    }
}
