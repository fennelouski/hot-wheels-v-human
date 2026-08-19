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
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct TrackBuilderView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext

    @State private var model = TrackBuilderModel()
    @State private var savedName: String?
    @State private var previewing = false
    @State private var mapExpanded = false
    @State private var showingWorlds = false
    @Query(sort: \TrackBlueprintRecord.name) private var savedRecords: [TrackBlueprintRecord]

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Label("Track Builder", systemImage: "wrench.and.screwdriver.fill")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                worldChip
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
                    // World strip beats the preset row — it only shows
                    // while the kid is actively picking a world.
                    if showingWorlds {
                        worldRow
                    } else if model.types == [.startGate], !model.decorating {
                        // Fresh canvas → offer the starter tracks.
                        presetRow
                    }
                }
                .overlay(alignment: .topLeading) {
                    if model.decorating {
                        Text(model.movingIndex != nil ? "Tap where it should go — tap it again to spin it!"
                             : model.placingModel != nil ? "Tap the ground to place it!"
                             : "Pick a decoration below — or tap one you placed to move it!")
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.black.opacity(0.55), in: Capsule())
                            .padding(10)
                    }
                }
                .padding(.horizontal, 16)

            if model.decorating {
                DecorPaletteView(model: model)
            } else {
                PiecePaletteView(model: model)
            }

            HStack(spacing: 14) {
                // Build ↔ Decorate. In decorate mode the palette turns into
                // the decoration box (every world's props) and Undo removes
                // the last placed decoration.
                Button {
                    model.decorating.toggle()
                    if !model.decorating {
                        model.placingModel = nil
                        model.movingIndex = nil
                    }
                    SoundBank.shared.play("confirm_sparkle")
                } label: {
                    Label(model.decorating ? "Build" : "Decorate",
                          systemImage: model.decorating
                              ? "wrench.and.screwdriver.fill" : "paintbrush.fill")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .padding(.horizontal, 14)
                        .frame(height: 60)
                }
                .buttonStyle(.bordered)
                .tint(model.decorating ? .orange : nil)
                .accessibilityIdentifier("decorateToggle")
                toolButton("Undo", systemImage: "arrow.uturn.backward") {
                    model.decorating ? model.removeLastScenery() : model.removeLast()
                }
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

    /// Shows the current world; tapping opens/closes the world strip over
    /// the 3D scene, where each pick rebuilds the world live.
    private var worldChip: some View {
        let theme = model.worldTheme.flatMap { name in
            ArenaEnvironment.themes.first { $0.name == name }
        }
        return Button {
            withAnimation(.snappy) { showingWorlds.toggle() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: theme?.symbol ?? "sparkles")
                    .font(.system(size: 24, weight: .bold))
                // "Pick a World!" until one is picked — "Surprise" said
                // nothing about what the button does and nobody tapped it.
                Text(theme?.displayName ?? "Pick a World!")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
            }
            .padding(.horizontal, 18)
            .frame(height: 60)
            .background(.white.opacity(showingWorlds ? 0.28 : 0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("World: \(theme?.displayName ?? "Surprise me")")
        .accessibilityIdentifier("worldChip")
    }

    /// One button per world; the picked one glows. Stays open so a kid can
    /// tap through every world and watch the scene change behind it.
    private var worldRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                emptyWorldCard
                worldCard(name: nil, label: "Surprise", symbol: "sparkles")
                ForEach(ArenaEnvironment.themes, id: \.name) { theme in
                    worldCard(name: theme.name, label: theme.displayName,
                              symbol: theme.symbol)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 16)
    }

    /// Empty World: keep the picked world's sky and ground, none of the
    /// auto-placed stuff — he builds everything himself.
    private var emptyWorldCard: some View {
        Button {
            model.toggleWorldEmpty()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "square.dashed")
                    .font(.system(size: 30, weight: .bold))
                    .frame(height: 36)
                Text("Empty")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
            }
            .frame(width: 108, height: 84)
            .background(model.worldEmpty ? .orange.opacity(0.45) : .black.opacity(0.45),
                        in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("emptyWorldCard")
    }

    private func worldCard(name: String?, label: String, symbol: String) -> some View {
        let picked = model.worldTheme == name
        return Button {
            model.selectWorld(name)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 30, weight: .bold))
                    .frame(height: 36)
                Text(label)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: 108, height: 84)
            .background(picked ? .yellow.opacity(0.35) : .black.opacity(0.45),
                        in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
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

/// The decoration box: every world's props, hand-placeable. A world
/// filter row on top, the props of that world below — tap a prop, then
/// tap the ground in the 3D scene to drop it there.
struct DecorPaletteView: View {
    let model: TrackBuilderModel

    @State private var worldIndex = 0

    /// Thumbnail from the bundle's loose PNGs (Resources/Thumbs, rendered
    /// by tools — see Graphics/README). Explicit URL load: named-image
    /// lookup missed loose files in practice.
    static func thumb(_ prop: String) -> Image {
        guard let url = Bundle.main.url(forResource: "thumb-\(prop)",
                                        withExtension: "png") else {
            return Image(systemName: "cube.fill")
        }
        #if canImport(UIKit)
        if let image = UIImage(contentsOfFile: url.path) {
            return Image(uiImage: image)
        }
        #elseif canImport(AppKit)
        if let image = NSImage(contentsOfFile: url.path) {
            return Image(nsImage: image)
        }
        #endif
        return Image(systemName: "cube.fill")
    }

    /// (label, symbol, unique props) per world, from the theme lists —
    /// one source of truth for what exists.
    static let groups: [(String, String, [String])] = [
        ("Streets", "road.lanes",
         ["street-straight", "street-cross", "street-bend", "street-tee",
          "street-end", "street-square", "city-path-long", "city-path-short"]),
        ("People", "figure.walk",
         ["person-a", "person-b", "person-c", "person-d"]),
        ("Planets", "globe.americas.fill", SpaceStuff.models),
    ] + ArenaEnvironment.themes.map { theme in
        var seen = Set<String>()
        let unique = theme.props.filter { seen.insert($0).inserted }
        return (theme.displayName, theme.symbol, unique)
    }

    var body: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(Self.groups.enumerated()), id: \.offset) { index, group in
                        Button {
                            worldIndex = index
                        } label: {
                            Label(group.0, systemImage: group.1)
                                .font(.system(size: 16, weight: .heavy, design: .rounded))
                                .padding(.horizontal, 12)
                                .frame(height: 44)
                                .background(worldIndex == index
                                                ? .yellow.opacity(0.35) : .white.opacity(0.10),
                                            in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Self.groups[worldIndex].2, id: \.self) { prop in
                        let picked = model.placingModel == prop
                        Button {
                            model.placingModel = picked ? nil : prop
                            SoundBank.shared.play("confirm_sparkle")
                        } label: {
                            Self.thumb(prop)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 64, height: 64)
                                .padding(8)
                                .background(picked ? .yellow.opacity(0.35) : .white.opacity(0.10),
                                            in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(prop)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
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
