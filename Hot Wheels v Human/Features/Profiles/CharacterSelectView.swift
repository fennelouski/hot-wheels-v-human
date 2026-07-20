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
    }

    private func select(_ driver: DriverProfile) {
        appModel.selectedDriver = driver
        if let profileID = appModel.selectedProfile?.id {
            let descriptor = FetchDescriptor<KidProfileRecord>(
                predicate: #Predicate { $0.id == profileID })
            (try? modelContext.fetch(descriptor).first)?.lastUsedDriverID = driver.id
            try? modelContext.save()
        }
        SoundBank.shared.play("driver_woohoo")
    }

    private func delete(_ record: DriverProfileRecord) {
        if appModel.selectedDriver?.id == record.id {
            appModel.selectedDriver = nil
        }
        modelContext.delete(record)
        try? modelContext.save()
        SoundBank.shared.play("piece_delete_pop")
    }

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 30, weight: .heavy, design: .rounded))
            .foregroundStyle(.yellow)
    }

    private func characterCard(_ driver: DriverProfile, isStarter: Bool = false) -> some View {
        let isSelected = appModel.selectedDriver?.id == driver.id
        return Button {
            select(driver)
        } label: {
            VStack(spacing: 10) {
                // 2D badge, not a live DriverPreviewView: this is a GRID, and
                // every tile as its own RealityView means N simultaneous
                // scenes. That survives the simulator but exhausts a real
                // device's Metal drawable pools — nextDrawable returns nil and
                // RealityKit aborts binding a fallback texture into the
                // tonemap LUT slot. Live 3D is fine for the single-instance
                // previews (editor turntable, customizer); a grid needs a
                // cheap thumbnail. See OPEN-THREADS "3D grid avatars".
                DriverFaceBadge(driver: driver)
                    .frame(width: 84, height: 84)
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
