//
//  ProfilePickerView.swift
//  Hot Wheels v Human
//
//  "Who's playing?" — Netflix-kids-style local profiles, no accounts.
//  Cold launch lands here (one tap in), the home-screen chip comes back.
//  Picking a profile also loads its last-used character into AppModel.
//

import SwiftUI
import SwiftData

struct ProfilePickerView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \KidProfileRecord.name) private var records: [KidProfileRecord]
    @State private var creating = false

    private let columns = [GridItem(.adaptive(minimum: 200), spacing: 24)]
    private var lastProfileID: UUID? {
        UserDefaults.standard.string(forKey: "lastProfileID").flatMap(UUID.init)
    }

    var body: some View {
        VStack(spacing: 28) {
            Text("Who's playing?")
                .font(.system(size: 64, weight: .heavy, design: .rounded))
            ScrollView {
                LazyVGrid(columns: columns, spacing: 24) {
                    ForEach(records) { record in
                        profileTile(record)
                            .contextMenu {
                                Button(role: .destructive) {
                                    delete(record)
                                } label: {
                                    Label("Wave goodbye", systemImage: "trash")
                                }
                            }
                    }
                    newProfileTile
                }
                .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.09, green: 0.10, blue: 0.16))
        .foregroundStyle(.white)
        .sheet(isPresented: $creating) { NewProfileSheet(onCreate: create) }
        .onAppear { SoundBank.shared.playMusic("workshop_ambience") }
    }

    private func profileTile(_ record: KidProfileRecord) -> some View {
        Button {
            pick(record)
        } label: {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(hex: record.profile?.colorHex ?? "#FFD500"))
                    // No character picked yet on this profile — a symbol,
                    // not a stand-in racer, so the tile never implies a
                    // character the kid didn't choose.
                    // 2D badge, not a live DriverPreviewView: this grid draws
                    // one tile per profile, and a live RealityView per tile is
                    // N simultaneous scenes — fine on the simulator, but on a
                    // real device it drains the Metal drawable pools until
                    // nextDrawable fails and RealityKit aborts (tonemap-LUT
                    // fallback). See OPEN-THREADS "3D grid avatars".
                    if let driver = lastUsedCharacter(of: record) {
                        DriverFaceBadge(driver: driver)
                            .padding(14)
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 60, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .frame(width: 160, height: 160)
                .overlay(Circle().stroke(
                    record.id == lastProfileID ? .yellow : .clear, lineWidth: 5))
                Text(record.name)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .lineLimit(1)
            }
            .padding(16)
        }
        .buttonStyle(.plain)
    }

    private var newProfileTile: some View {
        Button {
            creating = true
        } label: {
            VStack(spacing: 12) {
                Circle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 160, height: 160)
                    .overlay(Image(systemName: "plus")
                        .font(.system(size: 64, weight: .heavy)))
                Text("New Racer")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
            }
            .padding(16)
        }
        .buttonStyle(.plain)
    }

    private func pick(_ record: KidProfileRecord) {
        guard let profile = record.profile else { return }
        appModel.selectedProfile = profile
        appModel.selectedDriver = lastUsedCharacter(of: record)
        UserDefaults.standard.set(record.id.uuidString, forKey: "lastProfileID")
        SoundBank.shared.play("player_join_horn")
    }

    private func lastUsedCharacter(of record: KidProfileRecord) -> DriverProfile? {
        guard let id = record.lastUsedDriverID else { return nil }
        let descriptor = FetchDescriptor<DriverProfileRecord>(
            predicate: #Predicate { $0.id == id })
        return try? modelContext.fetch(descriptor).first?.profile
    }

    /// New profile starts with a copy of a random starter character so the
    /// kid has someone to race as (and remix) immediately.
    private func create(name: String, colorHex: String) {
        let profile = KidProfile(id: UUID(), name: name, colorHex: colorHex)
        var starter = DriverProfile.presets.randomElement()!
        starter.id = UUID()
        guard let profileRecord = try? KidProfileRecord(profile: profile),
              let characterRecord = try? DriverProfileRecord(
                  profile: starter, ownerProfileID: profile.id) else { return }
        profileRecord.lastUsedDriverID = starter.id
        modelContext.insert(profileRecord)
        modelContext.insert(characterRecord)
        try? modelContext.save()
        SoundBank.shared.play("confirm_sparkle")
        appModel.selectedProfile = profile
        appModel.selectedDriver = starter
        UserDefaults.standard.set(profile.id.uuidString, forKey: "lastProfileID")
    }

    private func delete(_ record: KidProfileRecord) {
        let ownerID = record.id
        let characters = FetchDescriptor<DriverProfileRecord>(
            predicate: #Predicate { $0.ownerProfileID == ownerID })
        for character in (try? modelContext.fetch(characters)) ?? [] {
            modelContext.delete(character)
        }
        modelContext.delete(record)
        try? modelContext.save()
        SoundBank.shared.play("piece_delete_pop")
    }
}

/// Name + color, nothing else — a kid can finish this in five seconds.
private struct NewProfileSheet: View {
    let onCreate: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = DriverProfile.randomName()
    @State private var colorHex = DriverPalette.outfitColors.randomElement()!

    var body: some View {
        VStack(spacing: 28) {
            Text("New Racer!")
                .font(.system(size: 44, weight: .heavy, design: .rounded))
            HStack(spacing: 12) {
                TextField("Your name", text: $name)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    #if !os(tvOS)
                    .textFieldStyle(.roundedBorder)
                    #endif
                    .frame(maxWidth: 300)
                Button {
                    name = DriverProfile.randomName()
                    SoundBank.shared.play("shuffle_dice")
                } label: {
                    Image(systemName: "dice.fill").font(.system(size: 38, weight: .bold))
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 14) {
                ForEach(DriverPalette.outfitColors, id: \.self) { option in
                    Button {
                        colorHex = option
                        SoundBank.shared.play("ui_tap")
                    } label: {
                        Circle().fill(Color(hex: option))
                            .frame(width: 60, height: 60)
                            .overlay(Circle().stroke(
                                colorHex == option ? .yellow : .clear, lineWidth: 4))
                    }
                    .buttonStyle(.plain)
                }
            }
            Button {
                onCreate(name.isEmpty ? DriverProfile.randomName() : name, colorHex)
                dismiss()
            } label: {
                Label("Let's go!", systemImage: "flag.checkered")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .frame(width: 320, height: 80)
            }
            .buttonStyle(.borderedProminent)
            .tint(.yellow)
            .foregroundStyle(.black)
        }
        .padding(40)
        .presentationDetents([.medium])
    }
}

#Preview {
    ProfilePickerView()
        .environment(AppModel())
        .modelContainer(for: [KidProfileRecord.self, DriverProfileRecord.self],
                        inMemory: true)
}
