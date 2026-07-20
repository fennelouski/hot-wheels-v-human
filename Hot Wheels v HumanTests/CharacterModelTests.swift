//
//  CharacterModelTests.swift
//  Hot Wheels v HumanTests
//
//  Guardrails for the character-creation models (C-series): old saved JSON
//  keeps decoding, the driver rides the wire inside CarDesign, starter
//  characters only use palette colors, and palette snapping behaves.
//

import CoreGraphics
import Foundation
import SwiftData
import Testing
@testable import Hot_Wheels_v_Human

struct CharacterModelTests {

    // MARK: Backward compatibility — old JSON must keep decoding

    @Test func legacyDriverProfileJSONDecodes() throws {
        let legacy = """
        {"id":"11111111-2222-3333-4444-555555555555","name":"Racer",
         "helmetColorHex":"#FFD500","suitColorHex":"#2266FF",
         "skinToneHex":"#E0AC69","hair":"short"}
        """
        let profile = try JSONDecoder().decode(DriverProfile.self,
                                               from: Data(legacy.utf8))
        #expect(profile.name == "Racer")
        #expect(profile.hairColorHex == nil)
        #expect(profile.eyeColorHex == nil)
        #expect(profile.hat == nil)
        #expect(profile.glasses == nil)
        #expect(profile.bodyType == nil)
    }

    @Test func retiredEnumValuesStillDecode() throws {
        // "star" glasses shipped in C-series then got retired; profiles
        // wearing them (and any future unknown style) must keep decoding.
        let saved = """
        {"id":"11111111-2222-3333-4444-555555555555","name":"Racer",
         "helmetColorHex":"#FFD500","suitColorHex":"#2266FF",
         "skinToneHex":"#E0AC69","hair":"mohawk","glasses":"star"}
        """
        let profile = try JSONDecoder().decode(DriverProfile.self,
                                               from: Data(saved.utf8))
        #expect(profile.glasses == .roundShades)
        #expect(profile.hair == .character)
    }

    @Test func legacyCarDesignJSONDecodesWithoutDriver() throws {
        let legacy = """
        {"id":"11111111-2222-3333-4444-555555555555","name":"Old Car",
         "chassis":"heavyMuscle","tires":"standard",
         "paint":{"colorHex":"#D62718","finish":"glossy"}}
        """
        let design = try JSONDecoder().decode(CarDesign.self, from: Data(legacy.utf8))
        #expect(design.driver == nil)
    }

    // MARK: Wire round-trip — the driver travels inside the design

    @Test func carDesignRoundTripsWithDriver() throws {
        var design = CarDesign.presets[0]
        design.driver = DriverProfile.presets[1]
        let decoded = try JSONDecoder().decode(
            CarDesign.self, from: JSONEncoder().encode(design))
        #expect(decoded == design)
        #expect(decoded.driver == DriverProfile.presets[1])
    }

    // MARK: Starter characters

    @Test func starterCharactersHaveUniqueIdsAndNames() {
        #expect(Set(DriverProfile.presets.map(\.id)).count == DriverProfile.presets.count)
        #expect(Set(DriverProfile.presets.map(\.name)).count == DriverProfile.presets.count)
    }

    @Test func starterCharactersOnlyUsePaletteColors() {
        for driver in DriverProfile.presets {
            #expect(DriverPalette.skinTones.contains(driver.skinToneHex), "\(driver.name)")
            #expect(DriverPalette.hairColors.contains(driver.hairColorHex ?? ""), "\(driver.name)")
            #expect(DriverPalette.eyeColors.contains(driver.eyeColorHex ?? ""), "\(driver.name)")
            #expect(DriverPalette.outfitColors.contains(driver.suitColorHex), "\(driver.name)")
            #expect(DriverPalette.outfitColors.contains(driver.pantsColorHex ?? ""), "\(driver.name)")
            #expect(DriverPalette.outfitColors.contains(driver.helmetColorHex), "\(driver.name)")
        }
    }

    @Test func starterCharactersRoundTrip() throws {
        for driver in DriverProfile.presets {
            let decoded = try JSONDecoder().decode(
                DriverProfile.self, from: JSONEncoder().encode(driver))
            #expect(decoded == driver)
        }
    }

    @Test func starterCharactersShowOffTheWardrobe() {
        // At least one hat wearer, one glasses wearer, one bald, one with a
        // hair volume — and every body type in the gallery.
        #expect(DriverProfile.presets.contains { ($0.hat ?? .none) != HatStyle.none })
        #expect(DriverProfile.presets.contains { ($0.glasses ?? .none) != GlassesStyle.none })
        #expect(DriverProfile.presets.contains { $0.hair == .bald })
        #expect(DriverProfile.presets.contains { $0.hair == .character })
        // ...and at least one wearing hair lifted off a different character.
        #expect(DriverProfile.presets.contains { $0.hair.modelName != nil })
        #expect(Set(DriverProfile.presets.compactMap(\.bodyType)) == Set(BodyType.allCases))
    }

    // MARK: Palette snapping

    @Test func nearestReturnsExactMatch() {
        for swatch in DriverPalette.skinTones {
            #expect(DriverPalette.nearest(hex: swatch, in: DriverPalette.skinTones) == swatch)
        }
    }

    @Test func nearestSnapsToClosestSwatch() {
        // Near-black hair → the black swatch, not the blond one.
        #expect(DriverPalette.nearest(hex: "#0A0A0C", in: DriverPalette.hairColors) == "#1C1C1E")
        // A warm light tone → the lightest skin swatch.
        #expect(DriverPalette.nearest(hex: "#FFE0BE", in: DriverPalette.skinTones) == "#FFDBB4")
    }

    @Test func nearestKeepsMalformedInputUnchanged() {
        #expect(DriverPalette.nearest(hex: "not-a-color", in: DriverPalette.skinTones) == "not-a-color")
    }

    @Test func rgbParsesHexChannels() throws {
        let white = try #require(DriverPalette.rgb(hex: "#FFFFFF"))
        #expect(white == SIMD3<Float>(1, 1, 1))
        let red = try #require(DriverPalette.rgb(hex: "#FF0000"))
        #expect(red == SIMD3<Float>(1, 0, 0))
        #expect(DriverPalette.rgb(hex: "#12345") == nil)
    }

    // MARK: DriverPainter stripe palette

    @Test func paletteImageRowsMatchTheStripeTable() throws {
        var driver = DriverProfile.presets[0]
        driver.hair = .character
        let image = try #require(DriverPainter.paletteImage(for: driver))
        #expect(image.width == 32 && image.height == 32)
        // Sample one row per stripe (top-down) and compare to the profile.
        let expectations: [(Int, String)] = [
            (2, driver.skinToneHex),
            (8, driver.eyeColorHex!),
            (13, driver.hairColorHex!),
            (19, driver.suitColorHex),
            (27, DriverPalette.darkened(driver.pantsColorHex!,
                                        by: DriverPalette.pantsDarkening)),
        ]
        for (row, hex) in expectations {
            let pixel = try #require(Self.pixel(of: image, x: 16, y: row))
            let expected = try #require(DriverPalette.rgb(hex: hex))
            #expect(abs(pixel.x - expected.x) < 0.02
                    && abs(pixel.y - expected.y) < 0.02
                    && abs(pixel.z - expected.z) < 0.02,
                    "row \(row) should be \(hex)")
        }
    }

    @Test func matchingShirtAndPantsDoNotReadAsPajamas() throws {
        var driver = DriverProfile.presets[0]
        driver.suitColorHex = "#FF3B30"
        driver.pantsColorHex = "#FF3B30"
        let image = try #require(DriverPainter.paletteImage(for: driver))
        let shirt = try #require(Self.pixel(of: image, x: 16, y: 19))
        let pants = try #require(Self.pixel(of: image, x: 16, y: 27))
        // Darker, and by enough to see — but still the same color family.
        #expect(pants.x < shirt.x - 0.05)
        #expect(pants.x > shirt.x - 0.3)
    }

    @Test func baldPaintsTheHairStripeSkinTone() throws {
        var driver = DriverProfile.presets[0]
        driver.hair = .bald
        let image = try #require(DriverPainter.paletteImage(for: driver))
        let pixel = try #require(Self.pixel(of: image, x: 16, y: 13))
        let skin = try #require(DriverPalette.rgb(hex: driver.skinToneHex))
        #expect(abs(pixel.x - skin.x) < 0.02 && abs(pixel.y - skin.y) < 0.02
                && abs(pixel.z - skin.z) < 0.02)
    }

    /// Reads one RGBA pixel (top-down row `y`) as 0…1 channels.
    private static func pixel(of image: CGImage, x: Int, y: Int) -> SIMD3<Float>? {
        var data = [UInt8](repeating: 0, count: 4)
        guard let ctx = CGContext(data: &data, width: 1, height: 1,
                                  bitsPerComponent: 8, bytesPerRow: 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        // Draw so that (x, y) lands on the 1×1 context (CG origin bottom-left).
        ctx.draw(image, in: CGRect(x: -x, y: -(image.height - 1 - y),
                                   width: image.width, height: image.height))
        return SIMD3(Float(data[0]), Float(data[1]), Float(data[2])) / 255
    }

    // MARK: Camera lookalike — pure analysis math

    @Test func patchRectsLandWhereFacesKeepTheirFeatures() {
        let box = CGRect(x: 100, y: 100, width: 200, height: 240)
        let patches = LookalikeAnalyzer.patchRects(
            faceBox: box, leftPupil: CGPoint(x: 150, y: 250),
            rightPupil: CGPoint(x: 250, y: 250))
        #expect(patches.eyes.count == 2 && patches.cheeks.count == 2)
        // Eyes centered on the pupils.
        #expect(patches.eyes[0].midX == 150 && patches.eyes[0].midY == 250)
        // Cheeks below the pupils (Vision y grows upward).
        #expect(patches.cheeks[0].midY < 250)
        // Hair band above the face box, inside its width.
        #expect(patches.hair.minY > box.maxY)
        #expect(patches.hair.minX > box.minX && patches.hair.maxX < box.maxX)
    }

    @Test func averagesBehave() {
        let pixels: [SIMD3<Float>] = [SIMD3(0, 0, 0), SIMD3(1, 1, 1),
                                      SIMD3(1, 1, 1), SIMD3(1, 1, 1)]
        #expect(LookalikeAnalyzer.average(pixels) == SIMD3(0.75, 0.75, 0.75))
        // Dropping the darkest 30% removes the black pupil pixel.
        #expect(LookalikeAnalyzer.averageDroppingDarkest(pixels, fraction: 0.3)
                == SIMD3(1, 1, 1))
        #expect(LookalikeAnalyzer.average([]) == nil)
    }

    @Test func resultSnapsToPaletteAndSuggestsBald() throws {
        let skin = try #require(DriverPalette.rgb(hex: "#C68642"))
        let blue = try #require(DriverPalette.rgb(hex: "#2266FF"))
        let black = try #require(DriverPalette.rgb(hex: "#1C1C1E"))
        let hairy = LookalikeAnalyzer.result(cheek: skin, eye: blue, hair: black)
        #expect(hairy.skinToneHex == "#C68642")
        #expect(hairy.eyeColorHex == "#2266FF")
        #expect(hairy.hairColorHex == "#1C1C1E")
        #expect(!hairy.suggestBald)
        // A skin-colored "hair" band = no hair up there.
        let bald = LookalikeAnalyzer.result(cheek: skin, eye: blue, hair: skin)
        #expect(bald.suggestBald)
    }

    @Test func pixelSamplerReadsThePatch() throws {
        // Solid red image; any patch must average to red.
        var driver = DriverProfile.presets[0]
        driver.skinToneHex = "#FF0000"
        driver.suitColorHex = "#FF0000"
        driver.pantsColorHex = "#FF0000"
        driver.eyeColorHex = "#FF0000"
        driver.hairColorHex = "#FF0000"
        driver.hair = .character
        let image = try #require(DriverPainter.paletteImage(for: driver))
        let pixels = LookalikeAnalyzer.pixels(
            of: image, visionRect: CGRect(x: 4, y: 4, width: 16, height: 16))
        let avg = try #require(LookalikeAnalyzer.average(pixels))
        #expect(avg.x > 0.95 && avg.y < 0.05 && avg.z < 0.05)
    }

    // MARK: Dress-up prop mapping

    @Test func propsFollowTheProfile() {
        var driver = DriverProfile.presets[0]
        driver.hat = HatStyle.none
        driver.glasses = GlassesStyle.none
        driver.hair = .character  // wears the hair it was modelled with
        #expect(DriverDressUp.props(for: driver).isEmpty)
        driver.hair = .bald       // ...and bald attaches nothing either
        #expect(DriverDressUp.props(for: driver).isEmpty)
        driver.hat = .crown
        driver.glasses = .squareShades
        driver.hair = .bun
        #expect(DriverDressUp.props(for: driver) == ["crown", "square-shades", "hair-female-a"])
        driver.glasses = .round
        driver.hair = .buns
        #expect(DriverDressUp.props(for: driver) == ["crown", "round-glasses", "hair-female-b"])
        driver.hat = nil          // pre-C1 profile: no wardrobe fields at all
        driver.glasses = nil
        driver.hair = .longHair
        #expect(DriverDressUp.props(for: driver) == ["hair-female-f"])
    }

    // MARK: Editor save = upsert (characters edit in place, unlike cars)

    @MainActor @Test func editorSaveUpsertsById() throws {
        let container = try ModelContainer(
            for: DriverProfileRecord.self, KidProfileRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let owner = UUID()
        let model = CharacterEditorModel()
        model.driver.name = "First"
        model.save(into: context, ownerProfileID: owner)
        model.driver.name = "Second"
        model.save(into: context, ownerProfileID: owner)
        let records = try context.fetch(FetchDescriptor<DriverProfileRecord>())
        #expect(records.count == 1)
        #expect(records.first?.profile?.name == "Second")
        #expect(records.first?.ownerProfileID == owner)
    }

    // MARK: AppModel stamping

    @MainActor @Test func stampedRaceDesignCarriesTheSelectedDriver() {
        let appModel = AppModel()
        #expect(appModel.stampedRaceDesign().driver == DriverProfile.presets[0])
        appModel.selectedDriver = DriverProfile.presets[2]
        appModel.selectedDesign = CarDesign.presets[1]
        let stamped = appModel.stampedRaceDesign()
        #expect(stamped.id == CarDesign.presets[1].id)
        #expect(stamped.driver == DriverProfile.presets[2])
    }

    /// The workshops' "try it" buttons race the piece being edited, which is
    /// exactly what hasn't been saved into AppModel yet. If an override ever
    /// silently loses to the saved selection, every test drive quietly shows
    /// the kid someone else's car.
    @MainActor @Test func stampedRaceDesignPrefersWorkshopOverrides() {
        let appModel = AppModel()
        appModel.selectedDesign = CarDesign.presets[1]
        appModel.selectedDriver = DriverProfile.presets[2]

        let unsavedCar = CarDesign.presets[3]
        let unsavedDriver = DriverProfile.presets[1]

        // Car override alone keeps the saved driver, and vice versa.
        let carOnly = appModel.stampedRaceDesign(car: unsavedCar)
        #expect(carOnly.id == unsavedCar.id)
        #expect(carOnly.driver == DriverProfile.presets[2])

        let driverOnly = appModel.stampedRaceDesign(driver: unsavedDriver)
        #expect(driverOnly.id == CarDesign.presets[1].id)
        #expect(driverOnly.driver == unsavedDriver)
    }

    // MARK: Roster — four body types, four actual people

    /// The whole point of the Kenney Mini roster: man/woman/boy/girl used to
    /// be ONE Quaternius mesh at four scales, which read as the same person
    /// resized. Each must now resolve to a genuinely different model.
    @Test func bodyTypesResolveToDifferentModels() {
        var profile = DriverProfile.presets[0]
        var names: Set<String> = []
        for body in BodyType.allCases {
            profile.bodyType = body
            profile.characterVariant = nil     // body's own default
            names.insert(profile.modelName(pose: .idle))
        }
        #expect(names.count == BodyType.allCases.count)
    }

    /// The variant picker's whole job: every one of the twelve roster
    /// characters is reachable from the editor. Before the picker existed
    /// only `bodyType` was settable, so four of the twelve were — the other
    /// eight shipped in the bundle, passed their tests, and could not be
    /// chosen. The four body types × six variants collapse to twelve
    /// because man/boy share the male meshes and woman/girl the female.
    @Test func thePickerReachesAllTwelveRosterCharacters() {
        var profile = DriverProfile.presets[0]
        var reachable: Set<String> = []
        for body in BodyType.allCases {
            for variant in DriverProfile.characterVariants {
                profile.bodyType = body
                profile.characterVariant = variant
                reachable.insert(profile.modelName(pose: .drive))
            }
        }
        #expect(reachable.count == 12)

        // ...and body type alone really does only reach four of them.
        var byBodyOnly: Set<String> = []
        for body in BodyType.allCases {
            profile.bodyType = body
            profile.characterVariant = nil
            byBodyOnly.insert(profile.modelName(pose: .drive))
        }
        #expect(byBodyOnly.count == 4)
    }

    /// Hair is a customization axis now, so every style must resolve to a
    /// bundled mesh AND every character must have a bald cut to wear it on —
    /// 35 files that a bad extraction run would silently drop, leaving a kid
    /// with an invisible hairstyle or a driverless car.
    @Test func everyHairstyleAndBaldHeadIsBundled() {
        for style in HairStyle.allCases {
            guard let mesh = style.modelName else { continue }
            #expect(Bundle.main.url(forResource: mesh, withExtension: "usdz") != nil,
                    Comment(rawValue: "missing \(mesh).usdz for \(style)"))
        }
        var profile = DriverProfile.presets[0]
        profile.hair = .bob                       // any style needing a bald head
        for body in BodyType.allCases {
            for variant in DriverProfile.characterVariants {
                profile.bodyType = body
                profile.characterVariant = variant
                for pose in [DriverPose.idle, .drive] {
                    let name = profile.modelName(pose: pose)
                    #expect(name.contains("-bald-"))
                    #expect(Bundle.main.url(forResource: name, withExtension: "usdz") != nil,
                            Comment(rawValue: "missing \(name).usdz"))
                }
            }
        }
    }

    /// Picking a hairstyle swaps the character for its bald cut; picking
    /// "their own" leaves the character exactly as it was. This is the whole
    /// override rule, and it is one line in modelName(pose:).
    @Test func hairOverridesTheCharactersOwn() {
        var profile = DriverProfile.presets[0]
        profile.hair = .character
        let own = profile.modelName(pose: .drive)
        #expect(!own.contains("bald"))
        for style in HairStyle.allCases where style != .character {
            profile.hair = style
            #expect(profile.modelName(pose: .drive) == own.replacingOccurrences(
                of: "-drive", with: "-bald-drive"))
        }
    }

    /// Both poses exist per character, and the car uses the sitting one.
    @Test func everyRosterModelHasBothPoses() {
        var profile = DriverProfile.presets[0]
        for body in BodyType.allCases {
            for variant in DriverProfile.characterVariants {
                profile.bodyType = body
                profile.characterVariant = variant
                let idle = profile.modelName(pose: .idle)
                let drive = profile.modelName(pose: .drive)
                #expect(idle.hasSuffix("-idle"))
                #expect(drive.hasSuffix("-drive"))
                #expect(idle.replacingOccurrences(of: "-idle", with: "")
                        == drive.replacingOccurrences(of: "-drive", with: ""))
                #expect(idle.contains(body.isFemale ? "female" : "male"))
            }
        }
    }

    /// The reaction cam animates the roster character who is actually
    /// driving, using three clips converted once and retargeted (all twelve
    /// Kenney Mini characters share one skeleton). A missing or typo'd clip
    /// asset doesn't crash — the reaction just silently keeps the drive
    /// pose — so the bundle has to be checked, not trusted.
    @MainActor @Test func everyReactionClipIsBundled() {
        for (state, name) in DriverPoser.clipAssets {
            #expect(Bundle.main.url(forResource: name, withExtension: "usdz") != nil,
                    "missing clip \(name).usdz for \(state.rawValue)")
        }
    }

    /// The states the director can reach either have their own clip or
    /// deliberately fall back to the drive pose. This pins the deliberate
    /// list: adding an eighth ReactionState without a clip is fine, but it
    /// should be a decision, not an oversight.
    @MainActor @Test func reactionStatesWithoutAClipReuseTheDrivePose() {
        let posed = Set(DriverPoser.clipAssets.keys)
        #expect(posed == [.boosted, .crashed, .celebrating])
        #expect(Set(ReactionState.allCases).subtracting(posed)
                == [.idle, .steerLeft, .steerRight, .braced])
    }

    /// Every roster model the profiles can resolve to must actually be a
    /// bundled asset — a typo'd variant would silently give a driverless car.
    @Test func everyRosterModelIsBundled() throws {
        var profile = DriverProfile.presets[0]
        for body in BodyType.allCases {
            for variant in DriverProfile.characterVariants {
                profile.bodyType = body
                profile.characterVariant = variant
                for pose in [DriverPose.idle, .drive] {
                    let name = profile.modelName(pose: pose)
                    #expect(Bundle.main.url(forResource: name, withExtension: "usdz") != nil,
                            "missing asset \(name).usdz")
                }
            }
        }
    }
}
