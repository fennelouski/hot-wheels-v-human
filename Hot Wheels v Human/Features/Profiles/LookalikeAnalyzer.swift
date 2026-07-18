//
//  LookalikeAnalyzer.swift
//  Hot Wheels v Human
//
//  "Make it look like ME!": one photo → skin, hair, and eye colors snapped
//  to the DriverPalette. Everything runs on-device with Vision; the image
//  lives only in memory and is discarded after analysis. iPad only.
//

import CoreGraphics
import Foundation

#if os(iOS)
import Vision
#endif

enum LookalikeAnalyzer {

    nonisolated struct Result: Equatable, Sendable {
        var skinToneHex: String
        var hairColorHex: String
        var eyeColorHex: String
        /// The band above the face matched skin better than any hair color.
        var suggestBald: Bool
    }

    // MARK: Pure geometry + color math (unit-tested)

    /// Sample patches in Vision coordinates (origin bottom-left): two cheek
    /// squares under the pupils, small squares at each pupil, and a hair
    /// band above the face box.
    nonisolated static func patchRects(faceBox: CGRect, leftPupil: CGPoint,
                                       rightPupil: CGPoint)
        -> (cheeks: [CGRect], eyes: [CGRect], hair: CGRect) {
        let cheekSide = faceBox.width * 0.14
        let eyeSide = faceBox.width * 0.07
        let cheeks = [leftPupil, rightPupil].map { pupil in
            CGRect(x: pupil.x - cheekSide / 2,
                   y: pupil.y - faceBox.height * 0.28 - cheekSide / 2,
                   width: cheekSide, height: cheekSide)
        }
        let eyes = [leftPupil, rightPupil].map { pupil in
            CGRect(x: pupil.x - eyeSide / 2, y: pupil.y - eyeSide / 2,
                   width: eyeSide, height: eyeSide)
        }
        let hair = CGRect(x: faceBox.midX - faceBox.width * 0.3,
                          y: faceBox.maxY + faceBox.height * 0.02,
                          width: faceBox.width * 0.6,
                          height: faceBox.height * 0.14)
        return (cheeks, eyes, hair)
    }

    nonisolated static func average(_ pixels: [SIMD3<Float>]) -> SIMD3<Float>? {
        guard !pixels.isEmpty else { return nil }
        return pixels.reduce(SIMD3<Float>.zero, +) / Float(pixels.count)
    }

    /// Average after dropping the darkest fraction — for pupils, where the
    /// black pupil and lashes would swamp the iris color.
    nonisolated static func averageDroppingDarkest(_ pixels: [SIMD3<Float>],
                                                   fraction: Float) -> SIMD3<Float>? {
        guard !pixels.isEmpty else { return nil }
        let sorted = pixels.sorted { luminance($0) < luminance($1) }
        let dropped = Array(sorted.dropFirst(Int(Float(sorted.count) * fraction)))
        return average(dropped)
    }

    nonisolated static func luminance(_ rgb: SIMD3<Float>) -> Float {
        0.299 * rgb.x + 0.587 * rgb.y + 0.114 * rgb.z
    }

    nonisolated static func hex(_ rgb: SIMD3<Float>) -> String {
        String(format: "#%02X%02X%02X",
               Int((rgb.x * 255).rounded()), Int((rgb.y * 255).rounded()),
               Int((rgb.z * 255).rounded()))
    }

    /// Snap sampled colors to the palette; hair that reads closer to skin
    /// than to any hair swatch suggests bald.
    nonisolated static func result(cheek: SIMD3<Float>, eye: SIMD3<Float>,
                                   hair: SIMD3<Float>) -> Result {
        let skin = DriverPalette.nearest(hex: hex(cheek), in: DriverPalette.skinTones)
        let eyeColor = DriverPalette.nearest(hex: hex(eye), in: DriverPalette.eyeColors)
        let hairColor = DriverPalette.nearest(hex: hex(hair), in: DriverPalette.hairColors)
        let nearestOverall = DriverPalette.nearest(
            hex: hex(hair), in: DriverPalette.hairColors + DriverPalette.skinTones)
        return Result(skinToneHex: skin, hairColorHex: hairColor,
                      eyeColorHex: eyeColor,
                      suggestBald: DriverPalette.skinTones.contains(nearestOverall))
    }

    /// 16×16 downsample of a patch (Vision coordinates, origin bottom-left)
    /// as linear pixel values.
    nonisolated static func pixels(of image: CGImage, visionRect: CGRect) -> [SIMD3<Float>] {
        let flipped = CGRect(x: visionRect.origin.x,
                             y: CGFloat(image.height) - visionRect.maxY,
                             width: visionRect.width, height: visionRect.height)
        let clamped = flipped.intersection(
            CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard !clamped.isEmpty, let crop = image.cropping(to: clamped) else { return [] }
        let side = 16
        var data = [UInt8](repeating: 0, count: side * side * 4)
        let ok: Bool = data.withUnsafeMutableBytes { buffer in
            guard let ctx = CGContext(data: buffer.baseAddress, width: side, height: side,
                                      bitsPerComponent: 8, bytesPerRow: side * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            ctx.interpolationQuality = .medium
            ctx.draw(crop, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard ok else { return [] }
        return (0..<(side * side)).map { (i: Int) -> SIMD3<Float> in
            let r = Float(data[i * 4]) / 255
            let g = Float(data[i * 4 + 1]) / 255
            let b = Float(data[i * 4 + 2]) / 255
            return SIMD3(r, g, b)
        }
    }

    // MARK: The Vision call (human-tested — needs a real face)

    #if os(iOS)
    /// nil = no face found. The CGImage is released by the caller after this
    /// returns; nothing is written to disk.
    nonisolated static func analyze(_ image: CGImage) -> Result? {
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try? handler.perform([request])
        guard let face = request.results?.first,
              let landmarks = face.landmarks,
              let leftPupil = landmarks.leftPupil?.pointsInImage(
                  imageSize: CGSize(width: image.width, height: image.height)).first,
              let rightPupil = landmarks.rightPupil?.pointsInImage(
                  imageSize: CGSize(width: image.width, height: image.height)).first
        else { return nil }

        let box = VNImageRectForNormalizedRect(
            face.boundingBox, image.width, image.height)
        let patches = patchRects(faceBox: box, leftPupil: leftPupil, rightPupil: rightPupil)
        guard let cheek = average(patches.cheeks.flatMap { pixels(of: image, visionRect: $0) }),
              let eye = averageDroppingDarkest(
                  patches.eyes.flatMap { pixels(of: image, visionRect: $0) }, fraction: 0.3),
              let hair = average(pixels(of: image, visionRect: patches.hair))
        else { return nil }
        return result(cheek: cheek, eye: eye, hair: hair)
    }
    #endif
}
