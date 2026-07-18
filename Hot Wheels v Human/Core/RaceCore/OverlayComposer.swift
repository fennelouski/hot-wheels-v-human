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

nonisolated enum OverlayComposer {

    static let textureSize = 1024

    /// Composite the full overlay. Nil when there is nothing to draw —
    /// callers then remove the shell entirely.
    static func render(livery: LiverySpec?, size: Int = textureSize) -> CGImage? {
        guard livery != nil else { return nil }
        guard let ctx = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        // Map UV [0,1]² onto the pixel grid (CG origin is bottom-left,
        // matching v = 0 at the car's bottom).
        ctx.scaleBy(x: CGFloat(size), y: CGFloat(size))

        if let livery {
            draw(livery: livery, in: ctx)
        }
        return ctx.makeImage()
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

    static func cgColor(hex: String, alpha: CGFloat = 1) -> CGColor {
        var value: UInt64 = 0
        Scanner(string: hex.replacingOccurrences(of: "#", with: "")).scanHexInt64(&value)
        return CGColor(red: CGFloat((value >> 16) & 0xFF) / 255,
                       green: CGFloat((value >> 8) & 0xFF) / 255,
                       blue: CGFloat(value & 0xFF) / 255, alpha: alpha)
    }
}
