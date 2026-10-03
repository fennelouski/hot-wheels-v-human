import SwiftUI
import SwiftData

#if os(tvOS)
/// Selecting, remixing and scrapping are visible remote actions rather
/// than overlapping pencil buttons or hidden long-press menus.
struct TVCharacterDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppModel.self) private var appModel
    let isStarter: Bool
    let onSelect: (DriverProfile) -> Bool
    let onDelete: () -> Bool
    @State private var driver: DriverProfile
    @State private var orbit = TurntableOrbit()
    @State private var testing = false
    @State private var persistenceError: String?

    init(driver: DriverProfile, isStarter: Bool, onSelect: @escaping (DriverProfile) -> Bool, onDelete: @escaping () -> Bool) {
        _driver = State(initialValue: driver)
        self.isStarter = isStarter
        self.onSelect = onSelect
        self.onDelete = onDelete
    }

    var body: some View {
        HStack(spacing: 44) {
            VStack(spacing: 24) {
                DriverPreviewView(driver: driver, remoteOrbit: orbit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                TVPreviewOrbitControls(orbit: $orbit)
            }
            .frame(maxWidth: .infinity)
            .focusSection()
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text(driver.name).font(.system(size: 44, weight: .heavy, design: .rounded))
                    Button { if onSelect(driver) { dismiss() } else { persistenceError = "Your racer choice couldn't be saved. Please try again." } } label: {
                        Label("Race as This Racer", systemImage: "flag.checkered")
                    }
                    .buttonStyle(TVWorkshopButtonStyle(selected: true))
                    .accessibilityIdentifier("tv-select-racer")
                    NavigationLink {
                        CharacterEditorView(driver: isStarter ? personalCopy() : driver)
                    } label: { Label(isStarter ? "Remix Racer" : "Edit Racer", systemImage: "pencil") }
                    .buttonStyle(TVWorkshopButtonStyle())
                    .accessibilityIdentifier("tv-racer-edit")
                    Button { testing = true } label: { Label("Test Drive", systemImage: "play.fill") }
                        .buttonStyle(TVWorkshopButtonStyle())
                    Button {
                        let copy = personalCopy()
                        guard CharacterEditorModel(driver: copy).save(into: modelContext, ownerProfileID: appModel.selectedProfile?.id) else { persistenceError = "Your original racer is still here. Please try Save Copy again."; return }
                        SoundBank.shared.play("confirm_sparkle")
                        dismiss()
                    } label: { Label("Make a Copy", systemImage: "doc.on.doc.fill") }
                    .buttonStyle(TVWorkshopButtonStyle())
                    if !isStarter {
                        Button(role: .destructive) { if onDelete() { dismiss() } else { persistenceError = "Your racer couldn't be removed. Please try again." } } label: { Label("Scrap Racer", systemImage: "trash.fill") }
                            .buttonStyle(TVWorkshopButtonStyle())
                            .accessibilityIdentifier("tv-delete-racer")
                    }
                }
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
            .focusSection()
        }
        .padding(44)
        .background(Color(red: 0.09, green: 0.10, blue: 0.16))
        .foregroundStyle(.white)
        .onAppear {
            let id = driver.id
            let descriptor = FetchDescriptor<DriverProfileRecord>(predicate: #Predicate { $0.id == id })
            if let fresh = try? modelContext.fetch(descriptor).first?.profile { driver = fresh }
        }
        .racePreview(isPresented: $testing, designs: [appModel.stampedRaceDesign(driver: driver)])
        .alert("Couldn't Save Changes", isPresented: Binding(get: { persistenceError != nil }, set: { if !$0 { persistenceError = nil } })) {
            Button("OK", role: .cancel) { persistenceError = nil }
        } message: { Text(persistenceError ?? "Please try again.") }
    }

    private func personalCopy() -> DriverProfile {
        var copy = driver
        copy.id = UUID()
        return copy
    }
}
#endif
