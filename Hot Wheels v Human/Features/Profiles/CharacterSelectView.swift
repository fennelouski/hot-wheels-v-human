//
//  CharacterSelectView.swift
//  Hot Wheels v Human
//
//  This profile's characters + starter characters. Tap = race as them,
//  pencil = edit (a starter edits as a personal copy), hold = scrap.
//  Mirrors GarageView so the two "pick your stuff" screens feel the same.
//

import SwiftUI
import SwiftData

struct CharacterSelectView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DriverProfileRecord.name) private var records: [DriverProfileRecord]
    @State private var persistenceError: String?

    private let columns = [GridItem(.adaptive(minimum: 220), spacing: 20)]

    /// Only this profile's characters (nil owner = pre-profile junk, hidden).
    private var myRecords: [DriverProfileRecord] {
        records.filter { $0.ownerProfileID == appModel.selectedProfile?.id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                NavigationLink {
                    CharacterEditorView()
                } label: {
                    Label("Make a New Racer", systemImage: "plus.circle.fill")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .frame(height: 80)
                }
                .buttonStyle(.borderedProminent)
                .tint(.yellow)
                .foregroundStyle(.black)

                sectionHeader("My Racers", systemImage: "person.2.fill")
                if myRecords.isEmpty {
                    Text("Nothing here yet — make a racer, or remix a starter below!")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                } else {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(myRecords) { record in
                            if let driver = record.profile {
                                characterCard(driver)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            delete(record)
                                        } label: {
                                            Label("Scrap it", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                }
                sectionHeader("Starter Racers", systemImage: "sparkles")
                    .padding(.top, 12)
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(DriverProfile.presets) { driver in
                        characterCard(driver, isStarter: true)
                    }
                }
            }
            .padding(24)
        }
        .background(Color(red: 0.09, green: 0.10, blue: 0.16))
        .foregroundStyle(.white)
        .navigationTitle("My Racers")
        #if os(iOS)
        .toolbarColorScheme(.dark, for: .navigationBar)
        #endif
        .onAppear { SoundBank.shared.play("player_join_horn") }
        .alert("Couldn't Save Changes", isPresented: Binding(get: { persistenceError != nil }, set: { if !$0 { persistenceError = nil } })) {
            Button("OK", role: .cancel) { persistenceError = nil }
        } message: { Text(persistenceError ?? "Please try again.") }
    }

    @discardableResult
    private func select(_ driver: DriverProfile, reportFailure: Bool = true) -> Bool {
        var owner: KidProfileRecord?
        var previous: UUID?
        do {
            if let profileID = appModel.selectedProfile?.id {
                let descriptor = FetchDescriptor<KidProfileRecord>(predicate: #Predicate { $0.id == profileID })
                owner = try modelContext.fetch(descriptor).first
                guard let owner else {
                    if reportFailure { persistenceError = "Your profile couldn't be found. Choose your profile again, then select a racer." }
                    return false
                }
                previous = owner.lastUsedDriverID
                owner.lastUsedDriverID = driver.id
                try modelContext.save()
            }
        } catch {
            owner?.lastUsedDriverID = previous
            if reportFailure { persistenceError = "Your racer choice couldn't be saved. Please try again." }
            return false
        }
        appModel.selectedDriver = driver
        SoundBank.shared.play("driver_woohoo")
        return true
    }

    @discardableResult
    private func delete(_ record: DriverProfileRecord, reportFailure: Bool = true) -> Bool {
        var owner: KidProfileRecord?
        var oldLastUsed: UUID?
        var deletionStarted = false
        do {
            if let profileID = appModel.selectedProfile?.id {
                let descriptor = FetchDescriptor<KidProfileRecord>(predicate: #Predicate { $0.id == profileID })
                owner = try modelContext.fetch(descriptor).first
                oldLastUsed = owner?.lastUsedDriverID
                if oldLastUsed == record.id { owner?.lastUsedDriverID = nil }
            }
            modelContext.delete(record)
            deletionStarted = true
            try modelContext.save()
        } catch {
            if deletionStarted { modelContext.insert(record) }
            owner?.lastUsedDriverID = oldLastUsed
            if reportFailure { persistenceError = "Your racer couldn't be removed. Please try again." }
            return false
        }
        if appModel.selectedDriver?.id == record.id { appModel.selectedDriver = nil }
        SoundBank.shared.play("piece_delete_pop")
        return true
    }

    private func deleteDriver(_ id: UUID) -> Bool {
        guard let record = records.first(where: { $0.id == id }) else { return false }
        return delete(record, reportFailure: false)
    }

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 30, weight: .heavy, design: .rounded))
            .foregroundStyle(.yellow)
    }

    private func characterCard(_ driver: DriverProfile, isStarter: Bool = false) -> some View {
        let isSelected = appModel.selectedDriver?.id == driver.id
        #if os(tvOS)
        return NavigationLink {
            TVCharacterDetailView(driver: driver, isStarter: isStarter,
                                  onSelect: { select($0, reportFailure: false) }, onDelete: { deleteDriver(driver.id) })
        } label: {
            VStack(spacing: 16) {
                DriverGridAvatar(driver: driver).frame(width: 120, height: 120)
                Text(driver.name).font(.system(size: 28, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                if isSelected {
                    Label("Racing Next", systemImage: "checkmark")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(TVWorkshopButtonStyle(selected: isSelected))
        .accessibilityIdentifier("tv-racer-card-\(driver.id.uuidString)")
        #else
        return Button {
            select(driver)
        } label: {
            VStack(spacing: 10) {
                // 3D look from a still image, not a live scene — a RealityView
                // per tile crashes a device (OPEN-THREADS "3D grid avatars").
                DriverGridAvatar(driver: driver)
                    .frame(width: 84, height: 84)
                    .clipShape(Circle())
                Text(driver.name)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                if isSelected {
                    Text("RACING NEXT")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(.yellow)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(isSelected ? .yellow.opacity(0.2) : .white.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            NavigationLink {
                // Editing a starter makes a personal copy — presets stay pristine.
                CharacterEditorView(driver: isStarter ? personalCopy(of: driver) : driver)
            } label: {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 34))
                    .frame(width: 60, height: 60)
            }
            .buttonStyle(.plain)
        }
        #endif
    }

    private func personalCopy(of starter: DriverProfile) -> DriverProfile {
        var copy = starter
        copy.id = UUID()
        return copy
    }
}

#Preview {
    NavigationStack { CharacterSelectView() }
        .environment(AppModel())
        .modelContainer(for: [KidProfileRecord.self, DriverProfileRecord.self],
                        inMemory: true)
}
