import SwiftUI
import SwiftData

#if os(tvOS)
/// The TV workshop keeps the car in view while remote focus moves through
/// the tool shelf. Touch-only gestures have explicit equivalents here.
struct TVCustomizerView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Bindable var model: CustomizerModel
    var isPlayerTwo = false
    @State private var tab: CustomizerView.Tab = .body
    @State private var orbit = TurntableOrbit()
    @State private var paintSlot = CarPaintSlot.body
    @State private var saved = false
    @State private var saveFailed = false
    @State private var testing = false

    var body: some View {
        HStack(alignment: .top, spacing: 36) {
            VStack(spacing: 20) {
                TextField("Car name", text: $model.design.name)
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("tv-car-name")
                CarTurntableView(design: model.design, remoteOrbit: orbit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                TVPreviewOrbitControls(orbit: $orbit)
                HStack(spacing: 20) {
                    Button { model.undo() } label: {
                        Label("Undo", systemImage: "arrow.uturn.backward")
                    }
                    .disabled(model.undoStack.isEmpty)
                    Button { testing = true } label: {
                        Label("Test Drive", systemImage: "play.fill")
                    }
                    Button(action: save) {
                        Label(saved ? "Saved!" : "Save Car", systemImage: saved ? "checkmark" : "tray.and.arrow.down.fill")
                    }
                    .accessibilityIdentifier("tv-save-car")
                }
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .buttonStyle(TVWorkshopButtonStyle())
                .focusSection()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .focusSection()

            VStack(alignment: .leading, spacing: 20) {
                ChipRow(chips: CustomizerView.Tab.allCases.map {
                    .init(value: $0, title: $0.rawValue, symbol: $0.symbolName)
                }, selection: $tab, identifierPrefix: "tv-car-tab")
                .focusSection()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
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
        .onChange(of: model.design) { old, _ in
            saved = false
            model.designChanged(from: old)
        }
        .accessibilityIdentifier("tv-customizer")
        .racePreview(isPresented: $testing, designs: [appModel.stampedRaceDesign(car: model.design)])
        .alert("Couldn't Save Car", isPresented: $saveFailed) {
            Button("OK", role: .cancel) { }
        } message: { Text(model.lastSaveError ?? "Please try Save again.") }
    }

    @ViewBuilder private var tools: some View {
        switch tab {
        case .body: BodyPicker(selection: $model.design.modelOverride)
        case .chassis: ChassisPicker(selection: $model.design.chassis)
        case .tires: TirePicker(selection: $model.design.tires)
        case .paint: TVPaintShopView(design: $model.design, slot: $paintSlot)
        case .livery: TVLiveryShopView(livery: $model.design.livery)
        case .stickers: TVStickerEditor(stickers: $model.design.stickers)
        case .draw: TVDrawingPadView(drawingPNG: $model.design.drawingPNG, drawingStrokes: $model.design.drawingStrokes)
        case .driver:
            VStack(alignment: .leading, spacing: 24) {
                Text(appModel.raceDriver.name)
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                NavigationLink {
                    CharacterSelectView()
                } label: {
                    Label("Choose My Racer", systemImage: "person.2.fill")
                }
                NavigationLink {
                    CharacterEditorView(driver: appModel.raceDriver)
                } label: {
                    Label("Edit My Racer", systemImage: "pencil")
                }
            }
            .font(.system(size: 28, weight: .heavy, design: .rounded))
            .buttonStyle(TVWorkshopButtonStyle())
        }
    }

    private func save() {
        guard model.save(into: modelContext) else { saveFailed = true; return }
        if isPlayerTwo { appModel.playerTwoDesign = model.design }
        else { appModel.selectedDesign = model.design }
        saved = true
        SoundBank.shared.play("confirm_sparkle")
    }
}

struct TVPreviewOrbitControls: View {
    @Binding var orbit: TurntableOrbit

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                cameraButton("Look Left", symbol: "rotate.left") { orbit.drag(CGSize(width: -30, height: 0), ended: true) }
                cameraButton("Look Right", symbol: "rotate.right") { orbit.drag(CGSize(width: 30, height: 0), ended: true) }
                cameraButton("Look Above", symbol: "arrow.up") { orbit.drag(CGSize(width: 0, height: 25), ended: true) }
                cameraButton("Look Below", symbol: "arrow.down") { orbit.drag(CGSize(width: 0, height: -25), ended: true) }
            }
            HStack(spacing: 14) {
                cameraButton("Zoom Out", symbol: "minus.magnifyingglass") { orbit.pinch(0.8, ended: true) }
                cameraButton("Zoom In", symbol: "plus.magnifyingglass") { orbit.pinch(1.25, ended: true) }
                cameraButton("Reset View", symbol: "arrow.counterclockwise") { orbit = TurntableOrbit() }
            }
        }
        .buttonStyle(TVWorkshopButtonStyle())
        .focusSection()
    }

    private func cameraButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .bold))
                .frame(minWidth: 60, minHeight: 60)
        }
        .accessibilityLabel(title)
    }
}

/// Numeric tools use selectable buttons rather than unsupported TV sliders.
struct TVAdjustmentRow: View {
    let title: String
    let value: String
    var canDecrease = true
    var canIncrease = true
    let decrease: () -> Void
    let increase: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            Text(title).font(.system(size: 24, weight: .bold, design: .rounded))
            Spacer(minLength: 10)
            Button(action: decrease) { Image(systemName: "minus").frame(width: 60, height: 60) }
                .disabled(!canDecrease).accessibilityLabel("Decrease \(title)")
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded).monospacedDigit())
                .frame(minWidth: 88)
                .accessibilityLabel("\(title), \(value)")
            Button(action: increase) { Image(systemName: "plus").frame(width: 60, height: 60) }
                .disabled(!canIncrease).accessibilityLabel("Increase \(title)")
        }
        .buttonStyle(TVWorkshopButtonStyle())
    }
}

struct TVColorPalette: View {
    let title: String
    let options: [String]
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.system(size: 26, weight: .heavy, design: .rounded))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 16)], spacing: 16) {
                ForEach(options, id: \.self) { option in
                    Button {
                        selection = option
                        SoundBank.shared.play("paint_spray")
                    } label: {
                        Circle().fill(Color(hex: option))
                            .frame(width: 58, height: 58)
                            .overlay {
                                if selection == option {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 25, weight: .black))
                                        .foregroundStyle(.black)
                                        .background(.white.opacity(0.8), in: Circle())
                                }
                            }
                            .padding(8)
                    }
                    .buttonStyle(TVWorkshopButtonStyle(cornerRadius: 40))
                    .accessibilityLabel("\(title), \(TVWorkshopColorNames.name(for: option))")
                    .accessibilityAddTraits(selection == option ? .isSelected : [])
                }
            }
        }
    }
}

nonisolated enum TVWorkshopColorNames {
    static func name(for hex: String) -> String {
        switch hex.uppercased() {
        case "#FF3B30": "Red"
        case "#FF6600", "#FF9500": "Orange"
        case "#FFD500": "Yellow"
        case "#34C759": "Green"
        case "#00C7BE": "Teal"
        case "#2266FF": "Blue"
        case "#5856D6": "Indigo"
        case "#AF52DE", "#8E44AD": "Purple"
        case "#FF2D92": "Pink"
        case "#8E5B3A": "Brown"
        case "#F2F2F7": "White"
        case "#1C1C1E": "Black"
        case "#FFDBB4": "Light Peach"
        case "#F1C27D": "Peach"
        case "#E0AC69": "Tan"
        case "#C68642": "Warm Brown"
        case "#8D5524": "Deep Brown"
        case "#4A2C13", "#3B2716": "Dark Brown"
        case "#7C5823": "Brown"
        case "#B0793C": "Light Brown"
        case "#E7C87B": "Blond"
        case "#D62718": "Auburn"
        case "#8E8E93": "Gray"
        case "#5AC8FA": "Light Blue"
        default: "Color \(hex)"
        }
    }
}
#endif
