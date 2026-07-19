//
//  CharacterEditorView.swift
//  Hot Wheels v Human
//
//  The character workshop: face, hair, clothes, extras — the kid-favorite
//  screen. Layout mirrors CustomizerView (preview up top, tab strip below).
//  The 2D preview card is a stand-in until DriverPainter's 3D turntable (C4).
//

import SwiftUI
import SwiftData
import UIKit
#if canImport(PencilKit) && !os(tvOS)
import PencilKit
#endif

struct CharacterEditorView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext

    @State private var model: CharacterEditorModel
    @State private var tab: Tab = .face
    @State private var saved = false
    @State private var testing = false
    @State private var showingLookalike = false
    /// Drives the live PiP preview (see `demoDrive`).
    @State private var director = ReactionDirector()
    #if canImport(PencilKit) && !os(tvOS)
    /// Session-held face-paint strokes (the profile stores only the PNG).
    @State private var faceStrokes = PKDrawing()
    #endif

    init(driver: DriverProfile? = nil) {
        _model = State(initialValue: CharacterEditorModel(driver: driver))
    }

    enum Tab: String, CaseIterable {
        case face = "Face"
        case hair = "Hair"
        case clothes = "Clothes"
        case extras = "Extras"
        case camera = "Me!"

        var symbolName: String {
            switch self {
            case .face: "face.smiling"
            case .hair: "comb.fill"
            case .clothes: "tshirt.fill"
            case .extras: "crown.fill"
            case .camera: "camera.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                TextField("Racer name", text: $model.driver.name)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.plain)
                    .fixedSize()
                Button {
                    model.driver.name = DriverProfile.randomName()
                    SoundBank.shared.play("shuffle_dice")
                } label: {
                    Image(systemName: "dice.fill").font(.system(size: 30, weight: .bold))
                }
                .buttonStyle(.plain)
            }

            DriverPreviewView(driver: model.driver)
                .frame(maxHeight: .infinity)
                .overlay(alignment: .bottomTrailing) {
                    // The real reaction-cam PiP, not a stand-in badge: this
                    // is the round window the kid actually stares at during a
                    // race, so every hat, hair and face-paint change should
                    // be judged in it while they're still editing.
                    ReactionCamView(director: director, design: previewDesign)
                        .padding(.trailing, 16)
                        .padding(.bottom, 18)
                }
                .task { await demoDrive() }
                .overlay(alignment: .topLeading) {
                    Button {
                        model.undo()
                    } label: {
                        Label("Undo", systemImage: "arrow.uturn.backward")
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(.white.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 16)
                }

            ChipRow(chips: Tab.allCases.map {
                .init(value: $0, title: $0.rawValue, symbol: $0.symbolName)
            }, selection: $tab)
            .padding(.horizontal)

            Group {
                switch tab {
                case .face: faceTab
                case .hair: hairTab
                case .clothes: clothesTab
                case .extras: extrasTab
                case .camera: cameraTab
                }
            }
            .frame(maxHeight: 250)

            HStack(spacing: 16) {
                // Put this racer in the car and drive off — the fastest way
                // to see whether the hat still reads at racing speed.
                TryItButton(title: "Test Drive!") {
                    testing = true
                }
                SaveItButton(saved: saved) { save() }
            }
            .onChange(of: model.driver) { old, _ in
                saved = false
                model.driverChanged(from: old)
            }
        }
        .padding(.vertical)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.09, green: 0.10, blue: 0.16))
        .foregroundStyle(.white)
        .racePreview(isPresented: $testing, designs: [previewDesign])
    }

    /// This racer in the car that's queued to race — what both the PiP and
    /// the test drive show, so the two never disagree.
    private var previewDesign: CarDesign {
        appModel.stampedRaceDesign(driver: model.driver)
    }

    /// Fake a drive the whole time the editor is open. Parked at a standstill
    /// the reaction cam is a flat gradient with a blank face — it only reads as
    /// the thing from the race once the speed lines are flowing and the racer
    /// is pulling faces.
    ///
    /// Dead straight, though: the arena rolls the bust hard into turns, and in
    /// a 180 pt circle that swings the face clean out of frame — wrong on the
    /// one screen whose entire job is judging that face. The showreel of
    /// reactions does the showing off instead.
    private func demoDrive() async {
        let step = 0.05
        let showreel: [ReactionState] = [.boosted, .crashed, .braced, .idle]
        var elapsed = 0.0
        var fired = 0
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(50))
            elapsed += step
            director.update(dt: step, yawRate: 0, loopAhead: false, speed01: 0.7)
            // A new face every few seconds; update() walks each one back to
            // idle on its own once the override hold expires.
            if elapsed >= Double(fired + 1) * 3 {
                fired += 1
                director.fire(showreel[fired % showreel.count])
            }
        }
    }

    /// Save = this racer is now "me": persisted, selected, and remembered
    /// as the profile's last-used character.
    private func save() {
        model.save(into: modelContext, ownerProfileID: appModel.selectedProfile?.id)
        appModel.selectedDriver = model.driver
        if let profileID = appModel.selectedProfile?.id {
            let descriptor = FetchDescriptor<KidProfileRecord>(
                predicate: #Predicate { $0.id == profileID })
            (try? modelContext.fetch(descriptor).first)?.lastUsedDriverID = model.driver.id
            try? modelContext.save()
        }
        saved = true
        SoundBank.shared.play("confirm_sparkle")
    }

    // MARK: Tabs

    private var faceTab: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 28) {
                VStack(spacing: 10) {
                    label("Body")
                    ChipRow(chips: [
                        .init(value: BodyType.man, title: "Man"),
                        .init(value: .woman, title: "Woman"),
                        .init(value: .boy, title: "Boy"),
                        .init(value: .girl, title: "Girl"),
                    ], selection: optionalStyle(\.bodyType, default: BodyType.man),
                    scrolls: false)
                }
                #if canImport(PencilKit) && !os(tvOS)
                VStack(spacing: 6) {
                    label("Face paint")
                    FaceDrawPad(faceDrawingPNG: $model.driver.faceDrawingPNG,
                                strokes: $faceStrokes)
                }
                #endif
                swatchColumn("Skin", options: DriverPalette.skinTones,
                             selection: $model.driver.skinToneHex)
                swatchColumn("Eyes", options: DriverPalette.eyeColors,
                             selection: optionalColor(\.eyeColorHex,
                                                      default: DriverPalette.defaultEyeColor))
            }
            .padding(.horizontal, 20)
        }
    }

    private var hairTab: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 36) {
                VStack(spacing: 10) {
                    label("Style")
                    ChipRow(chips: [
                        .init(value: HairStyle.short, title: "Short"),
                        .init(value: .long, title: "Long"),
                        .init(value: .extraLong, title: "Extra Long"),
                        .init(value: .pigtails, title: "Pigtails"),
                        .init(value: .curly, title: "Curly"),
                        .init(value: .bald, title: "Bald"),
                    ], selection: $model.driver.hair, scrolls: false)
                }
                swatchColumn("Color", options: DriverPalette.hairColors,
                             selection: optionalColor(\.hairColorHex,
                                                      default: DriverPalette.defaultHairColor))
            }
            .padding(.horizontal, 20)
        }
    }

    private var clothesTab: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 28) {
                swatchColumn("Shirt", options: DriverPalette.outfitColors,
                             selection: $model.driver.suitColorHex)
                swatchColumn("Pants", options: DriverPalette.outfitColors,
                             selection: optionalColor(\.pantsColorHex,
                                                      default: DriverPalette.defaultPantsColor))
                swatchColumn("Helmet", options: DriverPalette.outfitColors,
                             selection: $model.driver.helmetColorHex)
            }
            .padding(.horizontal, 20)
        }
    }

    private var extrasTab: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 36) {
                VStack(spacing: 10) {
                    label("Hat")
                    ChipRow(chips: HatStyle.allCases.map {
                        .init(value: $0, title: hatName($0))
                    }, selection: optionalStyle(\.hat, default: HatStyle.none),
                    scrolls: false)
                    swatchColumn("Hat color", options: DriverPalette.outfitColors,
                                 selection: optionalColor(\.hatColorHex, default: "#FFD500"))
                }
                VStack(spacing: 10) {
                    label("Glasses")
                    ChipRow(chips: GlassesStyle.allCases.map {
                        .init(value: $0, title: glassesName($0))
                    }, selection: optionalStyle(\.glasses, default: GlassesStyle.none),
                    scrolls: false)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var cameraTab: some View {
        VStack(spacing: 14) {
            #if os(iOS)
            Button {
                showingLookalike = true
            } label: {
                Label("Make it look like ME!", systemImage: "camera.fill")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .frame(width: 440, height: 84)
            }
            .buttonStyle(.borderedProminent)
            .tint(.yellow)
            .foregroundStyle(.black)
            Text("One picture colors your racer like you — then it disappears.")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
            #else
            Text("The camera lives on the iPad")
            #endif
        }
        #if os(iOS)
        .sheet(isPresented: $showingLookalike) {
            LookalikeView { result in
                // One assignment = one undo entry.
                var driver = model.driver
                driver.skinToneHex = result.skinToneHex
                driver.eyeColorHex = result.eyeColorHex
                if result.suggestBald {
                    driver.hair = .bald
                } else {
                    driver.hairColorHex = result.hairColorHex
                    if driver.hair == .bald { driver.hair = .short }
                }
                model.driver = driver
            }
        }
        #endif
    }

    private func hatName(_ style: HatStyle) -> String {
        switch style {
        case .none: "None"
        case .helmet: "Helmet"
        case .cap: "Cap"
        case .crown: "Crown"
        case .headphones: "Music"
        }
    }

    private func glassesName(_ style: GlassesStyle) -> String {
        switch style {
        case .none: "None"
        case .round: "Round"
        case .square: "Square"
        case .sunglasses: "Sporty Shades"
        case .roundShades: "Round Shades"
        case .squareShades: "Square Shades"
        }
    }

    // MARK: Small helpers

    private func label(_ text: String) -> some View {
        Text(text).font(.system(size: 15, weight: .semibold, design: .rounded))
    }

    /// Binding into an optional color field, showing `default` until set.
    private func optionalColor(_ keyPath: WritableKeyPath<DriverProfile, String?>,
                               default fallback: String) -> Binding<String> {
        Binding(get: { model.driver[keyPath: keyPath] ?? fallback },
                set: { model.driver[keyPath: keyPath] = $0 })
    }

    private func optionalStyle<Style>(_ keyPath: WritableKeyPath<DriverProfile, Style?>,
                                      default fallback: Style) -> Binding<Style> {
        Binding(get: { model.driver[keyPath: keyPath] ?? fallback },
                set: { model.driver[keyPath: keyPath] = $0 })
    }

    private func swatchColumn(_ title: String, options: [String],
                              selection: Binding<String>) -> some View {
        VStack(spacing: 10) {
            label(title)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 8)], spacing: 8) {
                ForEach(options, id: \.self) { option in
                    Button {
                        selection.wrappedValue = option
                        SoundBank.shared.play("paint_spray")
                    } label: {
                        Circle().fill(Color(hex: option))
                            .frame(width: 44, height: 44)
                            .overlay(Circle().stroke(
                                selection.wrappedValue == option ? .yellow : .white.opacity(0.25),
                                lineWidth: selection.wrappedValue == option ? 4 : 1))
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: 240)
        }
    }
}

#Preview {
    NavigationStack { CharacterEditorView() }
        .environment(AppModel())
        .modelContainer(for: [KidProfileRecord.self, DriverProfileRecord.self],
                        inMemory: true)
}
