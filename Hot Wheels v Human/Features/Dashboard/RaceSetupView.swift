//
//  RaceSetupView.swift
//  Hot Wheels v Human
//
//  Race-on-TV pre-flight, one thing at a time: pick your car, then your
//  racer, then draft the tracks you want in order (tap = add to your list,
//  tap again = drop). Each step shows a single big 3D preview — one live
//  RealityKit scene at a time, so a screen full of turntables can't crash the
//  device (DriverThumbnail's "3D grid avatars" note). The TV alternates every
//  iPad's picks into the race series. Kid-first: big cards, tap order = rank.
//

import SwiftUI
import SwiftData

struct RaceSetupView: View {
    let onGo: () -> Void

    @Environment(AppModel.self) private var appModel
    @Query(sort: \CarDesignRecord.name) private var carRecords: [CarDesignRecord]
    @Query(sort: \DriverProfileRecord.name) private var driverRecords: [DriverProfileRecord]
    @Query(sort: \TrackBlueprintRecord.name) private var trackRecords: [TrackBlueprintRecord]

    /// 0 = car, 1 = racer, 2 = tracks. Only the current step's view is built,
    /// so exactly one 3D turntable is ever alive.
    @State private var step = 0
    /// Drives the track step's 3D preview — loaded with whichever track is
    /// currently in focus.
    @State private var trackModel = TrackBuilderModel()
    @State private var previewTrackId: UUID?

    private let stepTitles = ["Pick your car", "Pick your racer", "Pick your tracks"]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(.white.opacity(0.12))
            Group {
                switch step {
                case 0:  carStep
                case 1:  racerStep
                default: trackStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            footer
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

    // MARK: Header — Home button, current step, progress dots

    private var header: some View {
        HStack(spacing: 16) {
            HomeButton()
            VStack(alignment: .leading, spacing: 2) {
                Label("Race on TV", systemImage: "tv.fill")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                Text(stepTitles[step])
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.yellow)
            }
            Spacer()
            HStack(spacing: 10) {
                ForEach(0..<stepTitles.count, id: \.self) { index in
                    Circle()
                        .fill(index == step ? .yellow : .white.opacity(0.25))
                        .frame(width: 14, height: 14)
                }
            }
        }
        .padding(20)
    }

    // MARK: Step 1 — car (3D turntable + chooser)

    private var carStep: some View {
        VStack(spacing: 16) {
            CarTurntableView(design: appModel.raceDesign)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            chooserRow {
                ForEach(cars, id: \.id) { design in
                    let selected = appModel.raceDesign.id == design.id
                    chooserCard(selected: selected) {
                        appModel.selectedDesign = design
                        SoundBank.shared.play("car_select_vroom")
                    } content: {
                        CarSwatchView(design: design, size: 54)
                        Text(design.name)
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: Step 2 — racer (3D turntable + chooser)

    private var racerStep: some View {
        VStack(spacing: 16) {
            DriverPreviewView(driver: appModel.raceDriver)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            chooserRow {
                ForEach(drivers) { driver in
                    let selected = appModel.raceDriver.id == driver.id
                    chooserCard(selected: selected) {
                        appModel.selectedDriver = driver
                        SoundBank.shared.play("car_select_vroom")
                    } content: {
                        DriverFaceBadge(driver: driver)
                            .frame(width: 54, height: 54)
                            .clipShape(Circle())
                        Text(driver.name)
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: Step 3 — tracks (3D preview + draft-in-order list)

    private var trackStep: some View {
        HStack(spacing: 16) {
            VStack(spacing: 8) {
                TrackBuilder3DView(model: trackModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Text("Tap tracks in your favorite order — up to \(RaceTuning.raceSeriesLength)!")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.yellow)
            }
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(tracks, id: \.blueprint.trackId) { track in
                        trackCard(track.name, track.blueprint)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(width: 320)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .onAppear(perform: syncTrackPreview)
    }

    // MARK: Footer — Back / Next / To the TV

    private var footer: some View {
        HStack(spacing: 16) {
            if step > 0 {
                Button {
                    step -= 1
                    SoundBank.shared.play("ui_back")
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .frame(height: 76).frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.white)
            }
            if step < stepTitles.count - 1 {
                Button {
                    step += 1
                    SoundBank.shared.play("ui_tap")
                } label: {
                    Label("Next", systemImage: "chevron.right")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .frame(height: 76).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).tint(.yellow).foregroundStyle(.black)
            } else {
                Button(action: onGo) {
                    Label(appModel.rankedTrackPicks.count > 1
                              ? "RACE \(appModel.rankedTrackPicks.count) TRACKS!"
                              : "TO THE TV!",
                          systemImage: "flag.checkered")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .frame(height: 76).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).tint(.yellow).foregroundStyle(.black)
            }
        }
        .padding(20)
    }

    // MARK: Data

    private var cars: [CarDesign] {
        carRecords.compactMap(\.design) + CarDesign.presets
    }

    private var drivers: [DriverProfile] {
        driverRecords.compactMap(\.profile) + DriverProfile.presets
    }

    private var tracks: [(name: String, blueprint: TrackBlueprint)] {
        trackRecords.compactMap { record in
            record.blueprint.map { (record.name, $0) }
        } + TrackBlueprint.presets
    }

    // MARK: Track drafting + 3D preview

    private func rank(of blueprint: TrackBlueprint) -> Int? {
        appModel.rankedTrackPicks.firstIndex { $0.trackId == blueprint.trackId }
    }

    private func toggleTrack(_ blueprint: TrackBlueprint) {
        // Tapping a track always shows it in the 3D preview, and adds/removes
        // it from the ranked draft.
        setPreview(blueprint)
        if let index = rank(of: blueprint) {
            appModel.rankedTrackPicks.remove(at: index)
            SoundBank.shared.play("sticker_peel")
        } else if appModel.rankedTrackPicks.count < RaceTuning.raceSeriesLength {
            appModel.rankedTrackPicks.append(blueprint)
            SoundBank.shared.play("car_select_vroom")
        }
    }

    /// Default the preview to the top ranked pick (or the first track), so the
    /// 3D pane is never empty when the step opens.
    private func syncTrackPreview() {
        if let bp = appModel.rankedTrackPicks.first ?? tracks.first?.blueprint {
            setPreview(bp)
        }
    }

    private func setPreview(_ blueprint: TrackBlueprint) {
        guard previewTrackId != blueprint.trackId else { return }
        previewTrackId = blueprint.trackId
        trackModel.load(preset: blueprint)
    }

    // MARK: Cards

    /// One tappable chooser tile with a selected highlight, shared by the car
    /// and racer rows.
    private func chooserCard<Content: View>(
        selected: Bool, action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) { content() }
                .padding(16)
                .frame(width: 150)
                .background(selected ? .yellow.opacity(0.25) : .white.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 18))
                .overlay {
                    if selected {
                        RoundedRectangle(cornerRadius: 18).strokeBorder(.yellow, lineWidth: 3)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func chooserRow<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) { content() }
                .padding(.vertical, 4)
        }
        .frame(height: 150)
    }

    private func trackCard(_ name: String, _ blueprint: TrackBlueprint) -> some View {
        let rank = rank(of: blueprint)
        let isPreviewing = previewTrackId == blueprint.trackId
        return Button {
            toggleTrack(blueprint)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: rank == nil ? "road.lanes.curved.right"
                                              : "\(rank! + 1).circle.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(rank == nil ? .white : .yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .lineLimit(1)
                    Text("\(blueprint.segments.count) pieces")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(minHeight: 72)
            .background(rank == nil ? .white.opacity(0.08) : .yellow.opacity(0.25),
                        in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                if isPreviewing {
                    RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.6), lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    RaceSetupView {}
        .environment(AppModel())
        .modelContainer(for: [CarDesignRecord.self, TrackBlueprintRecord.self,
                              DriverProfileRecord.self],
                        inMemory: true)
}
