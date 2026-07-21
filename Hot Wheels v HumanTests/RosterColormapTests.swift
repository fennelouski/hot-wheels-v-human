//
//  RosterColormapTests.swift
//  Hot Wheels v HumanTests
//
//  The roster characters' Skin/Shirt/Pants swatches are a texture rewrite,
//  and the thing that made them dead UI for so long is that nothing failed —
//  the value saved, the render just ignored it. So these assert the parts a
//  silent regression would go through: the patch table covers everyone, the
//  bundled sheet still has the geometry the table indexes into, and a repaint
//  actually lands inside its patch and nowhere else.
//

import Foundation
import ImageIO
import Testing
@testable import Hot_Wheels_v_Human

struct RosterColormapTests {

    /// The bundled sheet, as premultiplied-last RGBA — same layout
    /// DriverPainter feeds to `repaint`.
    static func colormap() throws -> (pixels: [UInt8], width: Int, height: Int) {
        let url = try #require(Bundle.main.url(forResource: RosterColormap.resourceName,
                                               withExtension: "png"),
                               "roster-colormap.png is not in the bundle")
        let data = try Data(contentsOf: url)
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let context = try #require(CGContext(
            data: &pixels, width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0,
                                       width: image.width, height: image.height))
        return (pixels, image.width, image.height)
    }

    @Test func sheetIsBundledAndDivisibleByTheGrid() throws {
        let map = try Self.colormap()
        #expect(map.width == map.height)
        #expect(map.width % RosterColormap.grid == 0)
        #expect((map.height / RosterColormap.grid) % RosterColormap.rowsPerPatch == 0)
    }

    @Test func everyRosterCharacterHasPatches() throws {
        for body in BodyType.allCases {
            for variant in body.variants {
                var profile = DriverProfile.presets[0]
                profile.bodyType = body
                profile.characterVariant = variant
                let key = RosterColormap.key(for: profile)
                let patches = try #require(RosterColormap.patches[key], "no patch table for \(key)")
                // skin + pants + shirt, plus eyes on the characters that have
                // a separable eye cell.
                #expect(RosterColormap.repaints(for: profile).count == (patches.eyes == nil ? 3 : 4),
                        "\(key) repaint count doesn't match its patches")
            }
        }
        #expect(RosterColormap.patches.count == 12)
    }

    /// The reported bug: on a character whose eye cell is separable, the Eyes
    /// swatch must actually land as the LAST repaint (so it wins any shared
    /// cell). On a collision character it must stay absent rather than recolour
    /// the garment it shares texels with.
    @Test func eyesRepaintOnlyWhereSeparable() {
        var separable = DriverProfile.presets[0]           // female-b: eyes [3,0]
        separable.bodyType = .woman
        separable.characterVariant = "b"
        separable.eyeColorHex = "#00FF00"
        let eyed = RosterColormap.repaints(for: separable)
        #expect(eyed.last?.patch == RosterColormap.Patch(3, 0))
        #expect(eyed.last?.hex == "#00FF00")

        var collision = DriverProfile.presets[0]           // male-d: eyes == shirt
        collision.bodyType = .man
        collision.characterVariant = "d"
        collision.eyeColorHex = "#00FF00"
        #expect(RosterColormap.patches["character-male-d"]?.eyes == nil)
        #expect(!RosterColormap.repaints(for: collision).contains { $0.hex == "#00FF00" })
    }

    /// The boy can't wear the bearded man, so his key must never name him —
    /// the same clamp `modelName` applies, or the mesh and the texture would
    /// disagree about who this is.
    @Test func keyClampsToAVariantTheBodyCanWear() {
        var profile = DriverProfile.presets[0]
        profile.bodyType = .boy
        profile.characterVariant = "b"
        #expect(RosterColormap.key(for: profile) == "character-male-d")
    }

    @Test func repaintOnlyTouchesItsOwnPatch() throws {
        var map = try Self.colormap()
        let before = map.pixels
        let patch = RosterColormap.Patch(2, 1)   // male-a's shirt
        RosterColormap.repaint(&map.pixels, width: map.width, height: map.height,
                               patch: patch, hex: "#FF00FF")

        let cell = map.width / RosterColormap.grid
        let rows = (map.height / RosterColormap.grid) * RosterColormap.rowsPerPatch
        var changedInside = 0
        for y in 0..<map.height {
            for x in 0..<map.width {
                let i = (y * map.width + x) * 4
                let inside = (patch.col * cell..<(patch.col + 1) * cell).contains(x)
                    && (patch.row * rows..<(patch.row + 1) * rows).contains(y)
                let changed = Array(before[i..<i + 3]) != Array(map.pixels[i..<i + 3])
                if changed {
                    #expect(inside, "repaint escaped its patch at \(x),\(y)")
                    changedInside += 1
                }
            }
        }
        #expect(changedInside > 0, "repaint did nothing")
    }

    /// Shading survives: the ramp's light row stays lighter than its dark row
    /// after a repaint. A flat fill would pass "the colour changed" and still
    /// flatten the model.
    @Test func repaintKeepsTheRamp() throws {
        var map = try Self.colormap()
        let patch = RosterColormap.Patch(2, 1)
        let cell = map.width / RosterColormap.grid
        let rows = map.height / RosterColormap.grid
        let x = patch.col * cell + cell / 2

        func green(_ y: Int) -> UInt8 { map.pixels[(y * map.width + x) * 4 + 1] }
        let lightRow = patch.row * rows * RosterColormap.rowsPerPatch + rows / 2
        let darkRow = lightRow + rows
        let wasLighter = green(lightRow) > green(darkRow)

        RosterColormap.repaint(&map.pixels, width: map.width, height: map.height,
                               patch: patch, hex: "#00FF00")
        #expect(green(lightRow) > 0, "the patch should now be green")
        #expect((green(lightRow) > green(darkRow)) == wasLighter,
                "the light/dark ramp inverted or flattened")
    }

    /// An unused (all-black) cell has no peak to normalise against; painting
    /// it would put a solid square in the middle of the sheet.
    @Test func repaintSkipsAnEmptyPatch() throws {
        var map = try Self.colormap()
        let before = map.pixels
        RosterColormap.repaint(&map.pixels, width: map.width, height: map.height,
                               patch: RosterColormap.Patch(0, 7), hex: "#FF00FF")
        #expect(map.pixels == before)
    }
}
