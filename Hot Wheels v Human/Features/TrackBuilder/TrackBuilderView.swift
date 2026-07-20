//
//  TrackBuilderView.swift
//  Hot Wheels v Human
//
//  3D builder: live orbit/zoom scene up top with an overhead mini-map
//  (tap to grow it), piece palette below, toolbar of big friendly
//  buttons. No free placement — pieces attach to the open exit with
//  derived orientation, so a kid can't build a broken track.
//

import SwiftUI
import SwiftData

struct TrackBuilderView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext

    @State private var model = TrackBuilderModel()
    @State private var savedName: String?
    @State private var previewing = false
    @State private var mapExpanded = false
    @Query(sort: \TrackBlueprintRecord.name) private var savedRecords: [TrackBlueprintRecord]

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Label("Track Builder", systemImage: "wrench.and.screwdriver.fill")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                Spacer()
                Text("\(model.types.count) \(model.types.count == 1 ? "piece" : "pieces")")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                HStack(spacing: 2) {
                    ForEach(0..<min(model.difficulty, 5), id: \.self) { _ in
                        Image(systemName: "flame.fill").foregroundStyle(.orange)
                    }
                }
                .font(.system(size: 20))
            }
            .padding(.horizontal, 20)

            TrackBuilder3DView(model: model)
                .frame(maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(alignment: .topTrailing) { miniMap }
                .overlay(alignment: .bottom) {
                    // Fresh canvas → offer the starter tracks.
                    if model.types == [.startGate] {
                        presetRow
                    }
                }
                .padding(.horizontal, 16)

            PiecePaletteView(model: model)

            HStack(spacing: 14) {
                toolButton("Undo", systemImage: "arrow.uturn.backward") { model.removeLast() }
                toolButton("Clear", systemImage: "trash") { model.clear() }
                toolButton("Shuffle", systemImage: "dice.fill") {
                    model.shuffle()
                    savedName = nil
                }
                Spacer()
                // Drive the track you're looking at — no save, no backing
                // out. Peeking mid-build is the whole point, so this races
                // `model.blueprint`, not whatever was last saved.
                TryItButton(title: "Race it!") {
                    previewing = true
                }
                .disabled(!model.isRaceable)
                SaveItButton(saved: savedName != nil) {
                    let name = "Track \(Int.random(in: 100...999))"
                    model.save(named: name, into: modelContext, appModel: appModel)
                    savedName = name
                }
                .disabled(!model.isRaceable)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
        .background(Color(red: 0.09, green: 0.10, blue: 0.16))
        .foregroundStyle(.white)
        .onChange(of: model.types) { savedName = nil }
        .racePreview(isPresented: $previewing,
                     designs: [appModel.stampedRaceDesign()],
                     blueprint: model.blueprint)
    }

    /// Overhead schematic in the corner of the 3D scene. A Button, not a
    /// tap gesture, so it also works when the TV compiles this file: tap
    /// zooms the map between corner-size and reading-size.
    private var miniMap: some View {
        Button {
            withAnimation(.snappy) { mapExpanded.toggle() }
        } label: {
            TrackCanvasView(layout: model.layout, isThumbnail: !mapExpanded)
                .frame(width: mapExpanded ? 420 : 180, height: mapExpanded ? 260 : 96)
                .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .padding(10)
        .accessibilityLabel("Track map")
        .accessibilityIdentifier("miniMap")
    }

    /// Starter tracks (and the kid's own saved ones) to jump off from
    /// instead of a blank canvas. Saved tracks first — theirs beats ours.
    private var presetRow: some View {
        VStack(spacing: 8) {
            Text("...or start from one of these!")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.yellow)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(savedRecords) { record in
                        if let blueprint = record.blueprint {
                            trackChip(name: record.name, blueprint: blueprint, saved: true)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        modelContext.delete(record)
                                        try? modelContext.save()
                                        SoundBank.shared.play("piece_delete_pop")
                                    } label: {
                                        Label("Scrap it", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    ForEach(TrackBlueprint.presets, id: \.blueprint.trackId) { preset in
                        trackChip(name: preset.name, blueprint: preset.blueprint, saved: false)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 16)
    }

    private func trackChip(name: String, blueprint: TrackBlueprint, saved: Bool) -> some View {
        Button {
            model.load(preset: blueprint)
            savedName = nil
        } label: {
            VStack(spacing: 4) {
                TrackCanvasView(layout: TrackLayoutSolver.solve(blueprint), isThumbnail: true)
                    .frame(width: 150, height: 64)
                HStack(spacing: 5) {
                    if saved {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.yellow)
                    }
                    Text(name)
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 8)
            .frame(width: 176, height: 108)
            .background(.yellow.opacity(saved ? 0.22 : 0.15),
                        in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private func toolButton(_ label: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            // Icon-only: spelled out, these three plus the two race buttons
            // overflow an iPad in portrait and every label wraps into an
            // unreadable stack. Undo/trash/dice are the icons kids already
            // know, and Label still hands the words to VoiceOver.
            Label(label, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .font(.system(size: 28, weight: .bold))
                .frame(width: 64, height: 60)
        }
        .buttonStyle(.bordered)
    }
}

/// Palette of appendable pieces; impossible appends gray out live.
struct PiecePaletteView: View {
    let model: TrackBuilderModel

    private static let cards: [(PieceType, String)] = [
        (.straight, "Straight"),
        (.curve90L, "Left"),
        (.curve90R, "Right"),
        (.curveLarge, "Sweeper"),
        (.loop, "Loop"),
        (.bump, "Bump"),
        (.hillUp, "Hill Up"),
        (.hillDown, "Hill Down"),
        (.rampJump, "Jump"),
        (.finishGate, "Finish"),
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Self.cards, id: \.0) { type, name in
                    let allowed = model.canAppend(type)
                    Button {
                        model.append(type)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: type.symbolName ?? "questionmark")
                                .font(.system(size: 34, weight: .bold))
                                .frame(height: 40)
                            Text(name)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                        }
                        .frame(width: 96, height: 86)
                        .background(.white.opacity(allowed ? 0.12 : 0.04),
                                    in: RoundedRectangle(cornerRadius: 14))
                        .opacity(allowed ? 1 : 0.35)
                    }
                    .buttonStyle(.plain)
                    .disabled(!allowed)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

#Preview {
    TrackBuilderView()
        .environment(AppModel())
        .modelContainer(for: [TrackBlueprintRecord.self], inMemory: true)
}
