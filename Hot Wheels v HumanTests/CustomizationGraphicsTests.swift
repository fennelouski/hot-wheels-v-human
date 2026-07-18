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

    @Test func liveryRoundTripsInCarDesign() throws {
        var design = ModelTests.car
        design.livery = LiverySpec(pattern: .flames, colorHex: "#FF3B30", scale: 1.5)
        let decoded = try JSONDecoder().decode(
            CarDesign.self, from: JSONEncoder().encode(design))
        #expect(decoded == design)
    }
}
