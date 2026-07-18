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
    @State private var showingLookalike = false
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
                    // Face bubble: the reaction-cam face + the kid's face
                    // paint (2D — it rides the reaction cam, not the mesh).
                    ZStack {
                        DriverFaceView(state: .idle, skinToneHex: model.driver.skinToneHex)
                        if let paint = model.driver.faceDrawingPNG,
                           let image = UIImage(data: paint) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        }
                    }
                    .frame(width: 96, height: 96)
                    .clipShape(Circle())
                    .padding(.trailing, 16)
                }
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

            Picker("Part", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { Label($0.rawValue, systemImage: $0.symbolName) }
            }
            .pickerStyle(.segmented)
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

            Button {
                save()
            } label: {
                Label(saved ? "Saved!" : "Save My Racer",
                      systemImage: saved ? "checkmark.circle.fill" : "square.and.arrow.down.fill")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .onChange(of: model.driver) { old, _ in
                saved = false
                model.driverChanged(from: old)
            }
        }
        .padding(.vertical)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.09, green: 0.10, blue: 0.16))
        .foregroundStyle(.white)
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
        HStack(alignment: .top, spacing: 36) {
            VStack(spacing: 10) {
                label("Style")
                Picker("Hair", selection: $model.driver.hair) {
                    Image(systemName: "scissors").tag(HairStyle.short)
                    Image(systemName: "water.waves").tag(HairStyle.long)
                    Image(systemName: "hurricane").tag(HairStyle.curly)
                    Image(systemName: "circle.fill").tag(HairStyle.bald)
                }
                .pickerStyle(.segmented)
                .frame(width: 280)
            }
            swatchColumn("Color", options: DriverPalette.hairColors,
                         selection: optionalColor(\.hairColorHex,
                                                  default: DriverPalette.defaultHairColor))
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
        HStack(alignment: .top, spacing: 36) {
            VStack(spacing: 10) {
                label("Hat")
                Picker("Hat", selection: optionalStyle(\.hat, default: HatStyle.none)) {
                    ForEach(HatStyle.allCases, id: \.self) { style in
                        Text(hatName(style)).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 380)
                swatchColumn("Hat color", options: DriverPalette.outfitColors,
                             selection: optionalColor(\.hatColorHex, default: "#FFD500"))
            }
            VStack(spacing: 10) {
                label("Glasses")
                Picker("Glasses", selection: optionalStyle(\.glasses, default: GlassesStyle.none)) {
                    ForEach(GlassesStyle.allCases, id: \.self) { style in
                        Text(glassesName(style)).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 320)
            }
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
        case .sunglasses: "Cool"
        case .round: "Round"
        case .star: "Star"
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
