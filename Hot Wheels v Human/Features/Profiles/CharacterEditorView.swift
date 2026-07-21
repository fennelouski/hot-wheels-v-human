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
            // Uncapped on purpose — see CustomizerView. The Face bench is
            // twice the height of the Hair one, and a maxHeight cap doesn't
            // clip, it just overlaps the buttons below.

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
                    ], selection: bodyBinding, scrolls: false)

                    // Which of the six roster people of that body's sex.
                    // Without this row eight of the twelve characters were
                    // bundled, tested, and unreachable — each body type
                    // showed one fixed variant forever. Numbered rather than
                    // named because the roster has no names; the live
                    // preview above answers "who is 4?" on tap.
                    label("Person")
                    ChipRow(chips: bodyType.variants.indices.map {
                        .init(value: bodyType.variants[$0], title: "\($0 + 1)")
                    }, selection: variantBinding, scrolls: false)
                }
                swatchColumn("Skin", options: DriverPalette.skinTones,
                             selection: $model.driver.skinToneHex)
                swatchColumn("Eyes", options: DriverPalette.eyeColors,
                             selection: optionalColor(\.eyeColorHex,
                                                      default: DriverPalette.defaultEyeColor))
            }
            .padding(.horizontal, 20)
        }
        // Centered, not left-jammed: most benches are narrower than an iPad,
        // and a short row pinned to the left edge reads as broken. Same
        // modifier ChipRow already uses for its scrolling variant.
        .defaultScrollAnchor(.center)
    }

    private var hairTab: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 36) {
                // Color reads first, so picking a color never means hunting
                // for the Style row first. Still hidden for the two styles
                // that have no hair mesh to paint: `.character` wears its
                // baked colormap (roster models are painted, not striped —
                // see DriverPainter.apply's bakedAppearance) and `.bald`
                // takes the scalp from the skin swatch. Swatches there would
                // be dead taps.
                if model.driver.hair != .character && model.driver.hair != .bald {
                    swatchColumn("Color", options: DriverPalette.hairColors,
                                 selection: optionalColor(\.hairColorHex,
                                                          default: DriverPalette.defaultHairColor))
                }
                VStack(spacing: 10) {
                    label("Style")
                    ChipRow(chips: HairStyle.allCases.map {
                        .init(value: $0, title: hairName($0))
                    }, selection: $model.driver.hair, scrolls: false)
                }
            }
            .padding(.horizontal, 20)
        }
        .defaultScrollAnchor(.center)
    }

    private var clothesTab: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 28) {
                swatchColumn("Shirt", options: DriverPalette.outfitColors,
                             selection: $model.driver.suitColorHex)
                swatchColumn("Pants", options: DriverPalette.outfitColors,
                             selection: optionalColor(\.pantsColorHex,
                                                      default: DriverPalette.defaultPantsColor))
                // ponytail: no Helmet swatch here. The helmet is a hat, and
                // DriverDressUp paints it from hatColorHex — helmetColorHex
                // renders nowhere. Colouring it lives with the Hat picker in
                // Extras so you never jump tabs to change one hat.
            }
            .padding(.horizontal, 20)
        }
        .defaultScrollAnchor(.center)
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
                    // Bare head has nothing to paint — same reasoning as the
                    // hair swatches under "Their Own".
                    if model.driver.hat ?? .none != HatStyle.none {
                        swatchColumn("Color", options: DriverPalette.outfitColors,
                                     selection: optionalColor(\.hatColorHex, default: "#FFD500"))
                    }
                }
                VStack(spacing: 10) {
                    label("Glasses")
                    // A few characters must wear glasses to hide eyes that
                    // can't be recoloured apart from a garment — drop "None"
                    // and default them to round frames, so the picker can't
                    // set a state the racer won't honour.
                    let mustWear = RosterColormap.eyesTakeGarmentColor(for: model.driver)
                    ChipRow(chips: GlassesStyle.allCases
                        .filter { !mustWear || $0 != .none }
                        .map { .init(value: $0, title: glassesName($0)) },
                    selection: optionalStyle(\.glasses,
                                             default: mustWear ? .round : .none),
                    scrolls: false)
                }
            }
            .padding(.horizontal, 20)
        }
        .defaultScrollAnchor(.center)
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
                    if driver.hair == .bald { driver.hair = .character }
                }
                model.driver = driver
            }
        }
        #endif
    }

    /// Kid-readable names for the extracted roster hair. "Their Own" is the
    /// default: the hair the character you picked was modelled with.
    private func hairName(_ style: HairStyle) -> String {
        switch style {
        case .character: "Their Own"
        case .bald: "Bald"
        case .bob: "Bob"
        case .bun: "Top Bun"
        case .buns: "Space Buns"
        case .ponytail: "Ponytail"
        case .swoop: "Swoop"
        case .longHair: "Long"
        case .crop: "Crop"
        case .spike: "Spikes"
        case .bowl: "Bowl"
        case .mop: "Mop"
        }
    }

    private func hatName(_ style: HatStyle) -> String {
        switch style {
        case .none: "None"
        case .helmet: "Helmet"
        case .cap: "Cap"
        case .crown: "Crown"
        case .headphones: "Music"
        case .policeCap: "Police"
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

    private var bodyType: BodyType { model.driver.bodyType ?? .man }

    /// Roster variant, defaulting to whatever the current body type wears —
    /// so the chips show who you're actually looking at before you've picked.
    /// Falls back the same way `modelName` clamps, so a variant this body
    /// can't wear highlights the chip it actually renders.
    private var variantBinding: Binding<String> {
        Binding(get: {
                    let wanted = model.driver.characterVariant ?? bodyType.defaultVariant
                    return bodyType.variants.contains(wanted) ? wanted : bodyType.defaultVariant
                },
                set: { model.driver.characterVariant = $0 })
    }

    /// Switching body type re-picks the hair when the old one came off the
    /// other sex's head — a girl kept the man's crop, which is the "that's
    /// not a girl" moment. `.character` is the safe landing: the roster
    /// model's OWN hair, so it always suits whoever you just became.
    private var bodyBinding: Binding<BodyType> {
        Binding(get: { bodyType },
                set: { body in
                    var driver = model.driver
                    driver.bodyType = body
                    if driver.hair.isFeminine == !body.isFemale { driver.hair = .character }
                    model.driver = driver   // one assignment = one undo entry
                })
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
