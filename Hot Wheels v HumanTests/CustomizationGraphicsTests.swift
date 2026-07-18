//
//  CustomizationGraphicsTests.swift
//  Hot Wheels v HumanTests
//
//  Pure-logic tests for the paint shell (UV projection, crack-free
//  inflation) and the overlay compositor — CUSTOMIZATION-GRAPHICS.md says
//  to unit-test exactly these; the *look* is human-tested.
//

import CoreGraphics
import Foundation
import simd
import Testing
@testable import Hot_Wheels_v_Human

struct ShellGeometryTests {

    let boundsMin = SIMD3<Float>(-0.5, 0, -1)
    let boundsMax = SIMD3<Float>(0.5, 0.6, 1)

    @Test func uvCornersMapToUnitSquare() {
        let nose = ShellGeometry.projectUV([0, 0, -1], boundsMin: boundsMin, boundsMax: boundsMax)
        #expect(nose == [0, 0])
        let tailTop = ShellGeometry.projectUV([0, 0.6, 1], boundsMin: boundsMin, boundsMax: boundsMax)
        #expect(tailTop == [1, 1])
        let mid = ShellGeometry.projectUV([0.5, 0.3, 0], boundsMin: boundsMin, boundsMax: boundsMax)
        #expect(abs(mid.x - 0.5) < 1e-5 && abs(mid.y - 0.5) < 1e-5)
    }

    @Test func mirroredSidesShareUV() {
        // x is ignored → left and right side of the car sample the same texel.
        let left = ShellGeometry.projectUV([-0.5, 0.3, 0.2], boundsMin: boundsMin, boundsMax: boundsMax)
        let right = ShellGeometry.projectUV([0.5, 0.3, 0.2], boundsMin: boundsMin, boundsMax: boundsMax)
        #expect(left == right)
    }

    @Test func degenerateBoundsDoNotDivideByZero() {
        let uv = ShellGeometry.projectUV(.zero, boundsMin: .zero, boundsMax: .zero)
        #expect(uv == [0.5, 0.5])
    }

    @Test func colocatedVerticesInflateTogether() {
        // A hard edge: same position, two very different face normals.
        // Smoothed inflation must move both copies identically (no cracks).
        let p = SIMD3<Float>(1, 1, 0)
        let positions = [p, p, SIMD3<Float>(0, 0, 0)]
        let normals: [SIMD3<Float>] = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
        let inflated = ShellGeometry.inflate(positions: positions, normals: normals, offset: 0.1)
        #expect(inflated[0] == inflated[1])
        // And the shared offset points along the averaged (smoothed) normal.
        let offset = inflated[0] - p
        #expect(abs(offset.x - offset.y) < 1e-5 && abs(offset.z) < 1e-5)
        #expect(abs(simd_length(offset) - 0.1) < 1e-5)
    }

    @Test func inflationPushesOutward() {
        let positions: [SIMD3<Float>] = [[0, 1, 0]]
        let normals: [SIMD3<Float>] = [[0, 1, 0]]
        let inflated = ShellGeometry.inflate(positions: positions, normals: normals, offset: 0.05)
        #expect(abs(inflated[0].y - 1.05) < 1e-5)
    }
}

struct OverlayComposerTests {

    private func alpha(at u: CGFloat, _ v: CGFloat, in image: CGImage) -> UInt8 {
        let x = min(image.width - 1, Int(u * CGFloat(image.width)))
        let y = min(image.height - 1, Int((1 - v) * CGFloat(image.height)))  // CG rows are top-down
        var pixel = [UInt8](repeating: 0, count: 4)
        let ctx = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8,
                            bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(image, in: CGRect(x: -x, y: -(image.height - 1 - y),
                                   width: image.width, height: image.height))
        return pixel[3]
    }

    @Test func nothingToDrawRendersNil() {
        #expect(OverlayComposer.render(livery: nil) == nil)
    }

    @Test func everyPatternDrawsSomething() throws {
        for pattern in LiveryPattern.allCases {
            let spec = LiverySpec(pattern: pattern, colorHex: "#FF3B30", scale: 1)
            let image = try #require(OverlayComposer.render(livery: spec, size: 128),
                                     "pattern \(pattern) rendered nil")
            var covered = 0
            for u in stride(from: 0.05, to: 1.0, by: 0.05) {
                for v in stride(from: 0.05, to: 1.0, by: 0.05)
                where alpha(at: u, v, in: image) > 32 { covered += 1 }
            }
            #expect(covered > 5, "pattern \(pattern) drew almost nothing")
            #expect(covered < 340, "pattern \(pattern) floods the whole car")
        }
    }

    @Test func checkerboardAlternates() throws {
        let spec = LiverySpec(pattern: .checkerboard, colorHex: "#1C1C1E", scale: 1)
        let image = try #require(OverlayComposer.render(livery: spec, size: 256))
        // cell = 0.11: (0.055, 0.055) is inside a filled cell, (0.165, 0.055) empty.
        #expect(alpha(at: 0.055, 0.055, in: image) > 128)
        #expect(alpha(at: 0.165, 0.055, in: image) < 16)
    }

    @Test func stickersDrawIntoOverlay() throws {
        // A big star at a known UV: alpha appears there, not far away.
        let sticker = StickerPlacement(symbol: "star.fill", uv: [0.5, 0.5],
                                       scale: 1.5, rotation: 0, colorHex: "#FFD500")
        let image = try #require(OverlayComposer.render(livery: nil, stickers: [sticker],
                                                        size: 256))
        #expect(alpha(at: 0.5, 0.5, in: image) > 64)
        #expect(alpha(at: 0.06, 0.06, in: image) < 16)
    }

    @Test func skullStickerDrawsWithoutUIKit() throws {
        let sticker = StickerPlacement(symbol: "skull", uv: [0.5, 0.5],
                                       scale: 2, rotation: 0, colorHex: "#F2F2F7")
        let image = try #require(OverlayComposer.render(livery: nil, stickers: [sticker],
                                                        size: 256))
        // Head is solid at center-top; the punched-out eye is transparent.
        #expect(alpha(at: 0.5, 0.62, in: image) > 128)
    }

    @Test func stickerPlacementRoundTrips() throws {
        var design = ModelTests.car
        design.stickers = [StickerPlacement(symbol: "pawprint.fill", uv: [0.25, 0.75],
                                            scale: 0.5, rotation: 1.2, colorHex: "#1C1C1E")]
        let decoded = try JSONDecoder().decode(
            CarDesign.self, from: JSONEncoder().encode(design))
        #expect(decoded == design)
    }

    @Test func cameraRayCenterLooksAlongForward() {
        // Identity camera transform → center of view rays straight down -z.
        let dir = CameraRay.direction(point: CGPoint(x: 200, y: 150),
                                      viewSize: CGSize(width: 400, height: 300),
                                      fovDegrees: 60, cameraTransform: matrix_identity_float4x4)
        #expect(abs(dir.x) < 1e-5 && abs(dir.y) < 1e-5 && abs(dir.z + 1) < 1e-5)
    }

    @Test func cameraRayCornersDiverge() {
        let size = CGSize(width: 400, height: 300)
        let topLeft = CameraRay.direction(point: .zero, viewSize: size, fovDegrees: 60,
                                          cameraTransform: matrix_identity_float4x4)
        // Top-left of screen → ray leans left (-x) and up (+y).
        #expect(topLeft.x < 0 && topLeft.y > 0 && topLeft.z < 0)
    }

    @Test func liveryRoundTripsInCarDesign() throws {
        var design = ModelTests.car
        design.livery = LiverySpec(pattern: .flames, colorHex: "#FF3B30", scale: 1.5)
        let decoded = try JSONDecoder().decode(
            CarDesign.self, from: JSONEncoder().encode(design))
        #expect(decoded == design)
    }
}
