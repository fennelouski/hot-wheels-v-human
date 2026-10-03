import SwiftUI

#if os(tvOS)
/// A complete remote-native racer editor, with a persistent preview and
/// scrollable wardrobe. It saves through the existing profile owner.
struct TVCharacterEditorView: View {
    @Environment(AppModel.self) private var appModel
    @Bindable var model: CharacterEditorModel
    let onSave: () -> Bool
    @State private var tab: CharacterEditorView.Tab = .face
    @State private var orbit = TurntableOrbit()
    @State private var saved = false
    @State private var saveFailed = false
    @State private var testing = false

    var body: some View {
        HStack(alignment: .top, spacing: 36) {
            VStack(spacing: 20) {
                HStack(spacing: 18) {
                    TextField("Racer name", text: $model.driver.name)
                        .font(.system(size: 38, weight: .heavy, design: .rounded))
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("tv-racer-name")
                    Button { model.driver.name = DriverProfile.randomName() } label: {
                        Image(systemName: "dice.fill").font(.system(size: 30, weight: .bold))
                    }
                    .buttonStyle(TVWorkshopButtonStyle())
                    .accessibilityLabel("Random Racer Name")
                }
                DriverPreviewView(driver: model.driver, remoteOrbit: orbit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                TVPreviewOrbitControls(orbit: $orbit)
                HStack(spacing: 20) {
                    Button { model.undo() } label: { Label("Undo", systemImage: "arrow.uturn.backward") }
                        .disabled(model.undoStack.isEmpty)
                    Button { testing = true } label: { Label("Test Drive", systemImage: "play.fill") }
                    Button { if onSave() { saved = true } else { saveFailed = true } } label: {
                        Label(saved ? "Saved!" : "Save Racer", systemImage: saved ? "checkmark" : "tray.and.arrow.down.fill")
                    }
                    .accessibilityIdentifier("tv-save-racer")
                }
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .buttonStyle(TVWorkshopButtonStyle())
                .focusSection()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .focusSection()

            VStack(alignment: .leading, spacing: 20) {
                ChipRow(chips: CharacterEditorView.Tab.allCases.map {
                    .init(value: $0, title: $0.rawValue, symbol: $0.symbolName)
                }, selection: $tab, identifierPrefix: "tv-racer-tab")
                .focusSection()
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        Text(tab.rawValue)
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                            .foregroundStyle(.yellow)
                        tools
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                }
                .focusSection()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(36)
        .background(Color(red: 0.09, green: 0.10, blue: 0.16))
        .foregroundStyle(.white)
        .onChange(of: model.driver) { old, _ in
            saved = false
            model.driverChanged(from: old)
        }
        .accessibilityIdentifier("tv-character-editor")
        .racePreview(isPresented: $testing, designs: [appModel.stampedRaceDesign(driver: model.driver)])
        .alert("Couldn't Save Racer", isPresented: $saveFailed) {
            Button("OK", role: .cancel) { }
        } message: { Text(model.lastSaveError ?? "Please try Save again.") }
    }

    @ViewBuilder private var tools: some View {
        switch tab {
        case .face:
            choices("Body", values: BodyType.allCases, selection: bodyBinding) { $0.rawValue.capitalized }
            choices("Person", values: bodyType.variants, selection: variantBinding) { value in
                "Person \((bodyType.variants.firstIndex(of: value) ?? 0) + 1)"
            }
            TVColorPalette(title: "Skin", options: DriverPalette.skinTones, selection: $model.driver.skinToneHex)
            if RosterColormap.canRecolorEyes(for: model.driver) {
                TVColorPalette(title: "Eyes", options: DriverPalette.eyeColors,
                               selection: optionalColor(\.eyeColorHex, default: DriverPalette.defaultEyeColor))
            }
        case .hair:
            choices("Style", values: HairStyle.allCases, selection: $model.driver.hair, name: hairName)
            if model.driver.canRecolorHair {
                TVColorPalette(title: "Hair Color", options: DriverPalette.hairColors,
                               selection: optionalColor(\.hairColorHex, default: model.driver.hair == .character ? "" : DriverPalette.defaultHairColor))
            }
        case .clothes:
            TVColorPalette(title: "Shirt", options: DriverPalette.outfitColors, selection: $model.driver.suitColorHex)
            TVColorPalette(title: "Pants", options: DriverPalette.outfitColors,
                           selection: optionalColor(\.pantsColorHex, default: DriverPalette.defaultPantsColor))
        case .extras:
            choices("Hat", values: HatStyle.allCases, selection: optionalStyle(\.hat, default: HatStyle.none), name: hatName)
            if model.driver.hat ?? .none != HatStyle.none {
                TVColorPalette(title: "Hat Color", options: DriverPalette.outfitColors,
                               selection: optionalColor(\.hatColorHex, default: "#FFD500"))
            }
            let mustWear = RosterColormap.eyesTakeGarmentColor(for: model.driver)
            choices("Glasses", values: GlassesStyle.allCases.filter { !mustWear || $0 != .none },
                    selection: optionalStyle(\.glasses, default: mustWear ? .round : .none), name: glassesName)
        }
    }

    private func choices<Value: Hashable>(_ title: String, values: [Value], selection: Binding<Value>, name: @escaping (Value) -> String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.system(size: 26, weight: .heavy, design: .rounded))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 18)], spacing: 18) {
                ForEach(values, id: \.self) { value in
                    Button {
                        selection.wrappedValue = value
                        SoundBank.shared.play("ui_tap")
                    } label: {
                        HStack(spacing: 10) {
                            Text(name(value))
                            if selection.wrappedValue == value { Image(systemName: "checkmark") }
                        }
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, minHeight: 64)
                    }
                    .buttonStyle(TVWorkshopButtonStyle(selected: selection.wrappedValue == value))
                    .accessibilityAddTraits(selection.wrappedValue == value ? .isSelected : [])
                }
            }
        }
    }

    private var bodyType: BodyType { model.driver.bodyType ?? .man }
    private var bodyBinding: Binding<BodyType> {
        Binding(get: { bodyType }, set: { value in
            var next = model.driver
            next.bodyType = value
            if next.hair.isFeminine == !value.isFemale { next.hair = .character }
            model.driver = next
        })
    }
    private var variantBinding: Binding<String> {
        Binding(get: {
            let wanted = model.driver.characterVariant ?? bodyType.defaultVariant
            return bodyType.variants.contains(wanted) ? wanted : bodyType.defaultVariant
        }, set: { model.driver.characterVariant = $0 })
    }
    private func optionalColor(_ keyPath: WritableKeyPath<DriverProfile, String?>, default fallback: String) -> Binding<String> {
        Binding(get: { model.driver[keyPath: keyPath] ?? fallback }, set: { model.driver[keyPath: keyPath] = $0 })
    }
    private func optionalStyle<Value>(_ keyPath: WritableKeyPath<DriverProfile, Value?>, default fallback: Value) -> Binding<Value> {
        Binding(get: { model.driver[keyPath: keyPath] ?? fallback }, set: { model.driver[keyPath: keyPath] = $0 })
    }
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
}
#endif
