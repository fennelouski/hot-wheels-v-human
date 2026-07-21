//
//  PlatformShims.swift
//  Hot Wheels v Human
//
//  Cross-platform image/colour aliases so the customizer's CoreGraphics
//  helpers build on a NATIVE macOS target (AppKit) as well as iOS/tvOS
//  (UIKit). tvOS ships UIKit, so the UIKit branch already covers it — only a
//  native macOS build (no UIKit) takes the AppKit side. The PNG/scale helpers
//  are pure ImageIO/CoreGraphics, so they're one path on every OS.
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
typealias PlatformColor = UIColor
typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
typealias PlatformColor = NSColor
typealias PlatformImage = NSImage
#endif

/// PNG-encode a CGImage. Pure ImageIO — no UIKit/AppKit, so the paint-shell
/// export is identical on every platform.
func encodePNG(_ image: CGImage) -> Data? {
    let data = NSMutableData()
    guard let dest = CGImageDestinationCreateWithData(
        data as CFMutableData, UTType.png.identifier as CFString, 1, nil) else { return nil }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { return nil }
    return data as Data
}

/// Redraw a CGImage at `width` px, aspect-preserved. CoreGraphics only.
func scaledCGImage(_ image: CGImage, width: Int) -> CGImage? {
    let w = max(1, width)
    let h = max(1, Int((CGFloat(w) * CGFloat(image.height) / CGFloat(max(image.width, 1))).rounded()))
    guard let ctx = CGContext(
        data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    ctx.interpolationQuality = .high
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    return ctx.makeImage()
}
