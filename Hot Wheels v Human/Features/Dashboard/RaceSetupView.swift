//
//  RaceSetupView.swift
//  Hot Wheels v Human
//
//  Race-on-TV pre-flight: pick the car you're racing, then draft the
//  tracks you want in order (tap = add to your list, tap again = drop).
//  Each iPad drafts its own list; the TV alternates everyone's picks
//  into the race series. Kid-first: big cards, tap order IS the ranking.
//

import SwiftUI
import SwiftData

struct RaceSetupView: View {
    let onGo: () -> Void

    @Environment(AppModel.self) private var appModel
    @Query(sort: \CarDesignRecord.name) private var carRecords: [CarDesignRecord]
    @Query(sort: \TrackBlueprintRecord.name) private var trackRecords: [TrackBlueprintRecord]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Label("Race on TV", systemImage: "tv.fill")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                sectionHeader("Pick your car", systemImage: "car.side.fill")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(cars, id: \.id) { design in
                            carCard(design)
                        }
                    }
                    .padding(.vertical, 4)
                }
                sectionHeader("Pick your tracks — in your favorite order!",
                              systemImage: "map.fill")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 16)],
                          spacing: 16) {
                    ForEach(tracks, id: \.blueprint.trackId) { track in
                        trackCard(track.name, track.blueprint)
                    }
                }
                goButton
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
            .padding(24)
        }
        .background(Color(red: 0.09, green: 0.10, blue: 0.16))
        .foregroundStyle(.white)
        .onAppear {
            // "Race this next" from the Track Builder seeds the draft.
            if appModel.rankedTrackPicks.isEmpty, let built = appModel.selectedBlueprint {
                appModel.rankedTrackPicks = [built]
            }
        }
    }

    private var cars: [CarDesign] {
        carRecords.compactMap(\.design) + CarDesign.presets
    }

    private var tracks: [(name: String, blueprint: TrackBlueprint)] {
        trackRecords.compactMap { record in
            record.blueprint.map { (record.name, $0) }
        } + TrackBlueprint.presets
    }

    private func rank(of blueprint: TrackBlueprint) -> Int? {
        appModel.rankedTrackPicks.firstIndex { $0.trackId == blueprint.trackId }
    }

    private func toggleTrack(_ blueprint: TrackBlueprint) {
        if let index = rank(of: blueprint) {
            appModel.rankedTrackPicks.remove(at: index)
            SoundBank.shared.play("sticker_peel")
        } else if appModel.rankedTrackPicks.count < RaceTuning.raceSeriesLength {
            appModel.rankedTrackPicks.append(blueprint)
            SoundBank.shared.play("car_select_vroom")
        }
    }

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 30, weight: .heavy, design: .rounded))
            .foregroundStyle(.yellow)
    }

    private func carCard(_ design: CarDesign) -> some View {
        let isSelected = appModel.raceDesign.id == design.id
        return Button {
            appModel.selectedDesign = design
            SoundBank.shared.play("car_select_vroom")
        } label: {
            VStack(spacing: 8) {
                CarSwatchView(design: design, size: 54)
                Text(design.name)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .lineLimit(1)
            }
            .padding(16)
            .frame(width: 170)
            .background(isSelected ? .yellow.opacity(0.25) : .white.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 18).strokeBorder(.yellow, lineWidth: 3)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func trackCard(_ name: String, _ blueprint: TrackBlueprint) -> some View {
        let rank = rank(of: blueprint)
        return Button {
            toggleTrack(blueprint)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: rank == nil ? "road.lanes.curved.right"
                                              : "\(rank! + 1).circle.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(rank == nil ? .white : .yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .lineLimit(1)
                    Text("\(blueprint.segments.count) pieces")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(minHeight: 76)
            .background(rank == nil ? .white.opacity(0.08) : .yellow.opacity(0.25),
                        in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    private var goButton: some View {
        Button(action: onGo) {
            Label(appModel.rankedTrackPicks.count > 1
                      ? "RACE \(appModel.rankedTrackPicks.count) TRACKS!"
                      : "TO THE TV!",
                  systemImage: "flag.checkered")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .frame(width: 560, height: 88)
        }
        .buttonStyle(.borderedProminent)
        .tint(.yellow)
        .foregroundStyle(.black)
    }
}

#Preview {
    RaceSetupView {}
        .environment(AppModel())
        .modelContainer(for: [CarDesignRecord.self, TrackBlueprintRecord.self],
                        inMemory: true)
}
