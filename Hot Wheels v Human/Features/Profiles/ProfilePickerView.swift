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

    private var lastProfileID: UUID? {
        UserDefaults.standard.string(forKey: "lastProfileID").flatMap(UUID.init)
    }

    // Only ever 3–6 people here, so no grid: the tiles orbit a shared center,
    // each on its own gentle bob, inside a wobbling blob outline. One
    // TimelineView drives every motion off wall-clock time — no timers, no
    // animation state to keep in sync.
    var body: some View {
        VStack(spacing: 8) {
            Text("Who's playing?")
                .font(.system(size: 64, weight: .heavy, design: .rounded))
                .padding(.top, 40)
            GeometryReader { geo in
                TimelineView(.animation) { timeline in
                    orbit(in: geo.size,
                          time: timeline.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.09, green: 0.10, blue: 0.16))
        .foregroundStyle(.white)
        .sheet(isPresented: $creating) { NewProfileSheet(onCreate: create) }
        .onAppear { SoundBank.shared.playMusic("workshop_ambience") }
    }

    private func orbit(in size: CGSize, time: TimeInterval) -> some View {
        let count = records.count + 1                     // + the New Racer tile
        let radius = count == 1 ? 0 : min(size.width, size.height) * 0.33
        let spin = time * 0.12                            // slow ring drift, rad/s
        func place(_ index: Int) -> CGSize {
            let a = spin + Double(index) / Double(count) * 2 * .pi - .pi / 2
            let bob = sin(time * 1.6 + Double(index)) * 8 // the wiggle/dance
            return CGSize(width: cos(a) * radius, height: sin(a) * radius + bob)
        }
        return ZStack {
            ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                profileTile(record, seed: Double(index), time: time)
                    .contextMenu {
                        Button(role: .destructive) { delete(record) } label: {
                            Label("Wave goodbye", systemImage: "trash")
                        }
                    }
                    .offset(place(index))
            }
            newProfileTile(seed: Double(records.count), time: time)
                .offset(place(records.count))
        }
        .frame(width: size.width, height: size.height)
    }

    private func profileTile(_ record: KidProfileRecord,
                             seed: Double, time: TimeInterval) -> some View {
        Button {
            pick(record)
        } label: {
            VStack(spacing: 12) {
                ZStack {
                    BlobShape(phase: time, seed: seed)
                        .fill(Color(hex: record.profile?.colorHex ?? "#FFD500"))
                    if let driver = lastUsedCharacter(of: record) {
                        // 3D look from a still image, not a live scene — a
                        // RealityView per tile crashes a device (OPEN-THREADS
                        // "3D grid avatars"). DriverGridAvatar handles it.
                        DriverGridAvatar(driver: driver)
                            .clipShape(Circle())
                            .padding(20)
                    } else {
                        // No character picked yet on this profile — a symbol,
                        // not a stand-in racer, so the tile never implies a
                        // character the kid didn't choose.
                        Image(systemName: "person.fill")
                            .font(.system(size: 72, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .frame(width: 190, height: 190)
                .overlay(BlobShape(phase: time, seed: seed).stroke(
                    record.id == lastProfileID ? .yellow : .clear, lineWidth: 6))
                Text(record.name)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    private func newProfileTile(seed: Double, time: TimeInterval) -> some View {
        Button {
            creating = true
        } label: {
            VStack(spacing: 12) {
                BlobShape(phase: time, seed: seed)
                    .fill(.white.opacity(0.08))
                    .frame(width: 190, height: 190)
                    .overlay(Image(systemName: "plus")
                        .font(.system(size: 72, weight: .heavy)))
                Text("New Racer")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
            }
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

/// A near-circle whose edge breathes: radius modulated by two slow sines of
/// the angle plus `phase` (wall-clock time), `seed` giving each tile its own
/// rhythm. Amplitude stays under ~9% so the avatar's inset circle never pokes
/// out. 80 line segments read as smooth for a shape this size.
private struct BlobShape: Shape {
    var phase: Double
    var seed: Double

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let base = min(rect.width, rect.height) / 2 * 0.92
        var path = Path()
        let steps = 80
        for i in 0...steps {
            let a = Double(i) / Double(steps) * 2 * .pi
            let wobble = 1
                + 0.055 * sin(3 * a + phase + seed)
                + 0.035 * sin(5 * a - phase * 0.7 + seed * 2)
            let r = base * wobble
            let point = CGPoint(x: center.x + CGFloat(cos(a) * r),
                                y: center.y + CGFloat(sin(a) * r))
            i == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()
        return path
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
