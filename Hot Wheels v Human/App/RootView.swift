//
//  RootView.swift
//  Hot Wheels v Human
//
//  Platform router + iPad home. iPadOS → Workshop home, tvOS → Arena
//  lobby. `--solo-arena` launch arg jumps straight into a demo race.
//

import SwiftUI
import RealityKit

struct RootView: View {
    @Environment(AppModel.self) private var appModel

    /// Browses for an Apple TV the whole time the home screen is up, so the
    /// "Race on TV" tile only appears when there's a TV to race on. A tile
    /// that leads to a permanent "Looking for your TV…" is a dead end for a
    /// kid; no tile asks no questions.
    @State private var tvFinder = TVFinder()

    /// Dev deep links: `simctl launch <app> --solo-arena | --customizer`.
    private let launchIntoArena = ProcessInfo.processInfo.arguments.contains("--solo-arena")
    private let launchIntoCustomizer = ProcessInfo.processInfo.arguments.contains("--customizer")
    private let launchIntoCharacterEditor = ProcessInfo.processInfo.arguments.contains("--character-editor")
    /// Dev arg: the wardrobe bench — every hat/glasses style at fixed
    /// profiles, so dress-up geometry can be screenshotted repeatably (the
    /// character editor randomises its driver every launch).
    private let launchIntoWardrobe = ProcessInfo.processInfo.arguments.contains("--wardrobe")
    /// Dev arg: the reaction-cam bench — every ReactionState at once. A race
    /// can't show them all (rail-mode races finish with 0 crashes, so the
    /// crash clip never plays), and the PiP is where "the driver isn't the
    /// driver" bugs hide.
    private let launchIntoReactionCam = ProcessInfo.processInfo.arguments.contains("--reaction-cam")
    /// Dev arg: the PiP tuner — a live reaction cam with a slider per
    /// cockpit number, for dialling the driver's framing in by eye.
    private let launchIntoPiPTuner = ProcessInfo.processInfo.arguments.contains("--pip-tuner")
    /// Dev arg: the physics A/B bench (PRD §2.1 "Test Mode") — two builds run
    /// side by side, no lives, no boosts. It's how physics FEEL is tuned, and
    /// it was never a kid feature: the pickers are hard-wired to
    /// `CarDesign.demoPair`, not to saved cars, and its "Glued to the Track"
    /// toggle writes `RaceTuning.railPinned` — a global that outlives the
    /// screen and would change the physics of every later race in the session.
    /// Behind a launch arg, that global can no longer be flipped by a player.
    private let launchIntoTestMode = ProcessInfo.processInfo.arguments.contains("--test-mode")
    private let launchIntoBuilder = ProcessInfo.processInfo.arguments.contains("--trackbuilder")
    private let launchIntoGarage = ProcessInfo.processInfo.arguments.contains("--garage")
    /// P7 memory drill: max-size random track, crash-prone demo pair.
    private let launchIntoStress = ProcessInfo.processInfo.arguments.contains("--stress-track")
    /// Dev arg: straight into a 1P race vs the medium robot (AI test loop).
    private let launchIntoRobotRace = ProcessInfo.processInfo.arguments.contains("--robot-race")
    /// Dev arg: Loopy Louie (opens hillUp + bump + hillDown) — hill-seam check.
    private let launchIntoHillTrack = ProcessInfo.processInfo.arguments.contains("--hill-track")
    /// Dev arg mirroring the home-screen Quick Play button.
    private let launchIntoQuickPlay = ProcessInfo.processInfo.arguments.contains("--quick-play")
    /// Dev arg: `--preset-track <n>` races the demo pair on starter track n
    /// (0-based) — lets CLI drills hit any of the 7 launch tracks directly.
    private let launchIntoPresetTrack: Int? = {
        let args = ProcessInfo.processInfo.arguments
        guard let flag = args.firstIndex(of: "--preset-track"),
              args.indices.contains(flag + 1), let n = Int(args[flag + 1])
        else { return nil }
        return min(max(n, 0), TrackBlueprint.presets.count - 1)
    }()
    /// Dev arg: straight to the Race-on-TV setup screen (track draft UI).
    private let launchIntoRaceOnTV = ProcessInfo.processInfo.arguments.contains("--race-on-tv")
    /// Dev arg: `--car <n>` narrows `--solo-arena` to demoPair[n] alone —
    /// single-car tuning drills without start-line traffic.
    private let soloCarIndex: Int? = {
        let args = ProcessInfo.processInfo.arguments
        guard let flag = args.firstIndex(of: "--car"),
              args.indices.contains(flag + 1), let n = Int(args[flag + 1])
        else { return nil }
        return min(max(n, 0), CarDesign.demoPair.count - 1)
    }()
    /// Dev arg: `--tires standard|slick|grippy` overrides every drill car's
    /// tires — isolates tire physics from chassis geometry in CLI drills.
    private let tireOverride: TireType? = {
        let args = ProcessInfo.processInfo.arguments
        guard let flag = args.firstIndex(of: "--tires"),
              args.indices.contains(flag + 1) else { return nil }
        switch args[flag + 1] {
        case "slick": return .slickRacing
        case "grippy": return .grippyOffroad
        case "standard": return .standard
        default: return nil
        }
    }()

    var body: some View {
        if launchIntoQuickPlay {
            QuickPlayView()
        } else if launchIntoRobotRace {
            SoloArenaView(designs: [CarDesign.demoPair[0]],
                          config: MatchConfig(mode: .onePlayer, aiDifficulty: .medium))
        } else if launchIntoStress {
            SoloArenaView(designs: CarDesign.demoPair,
                          blueprint: RandomTrackGenerator.generate(pieceCount: 75))
        } else if launchIntoHillTrack {
            SoloArenaView(designs: CarDesign.demoPair,
                          blueprint: TrackBlueprint.presets[2].blueprint)
        } else if let n = launchIntoPresetTrack {
            SoloArenaView(designs: CarDesign.demoPair,
                          blueprint: TrackBlueprint.presets[n].blueprint)
        } else if launchIntoArena {
            let picked = soloCarIndex.map { [CarDesign.demoPair[$0]] } ?? CarDesign.demoPair
            SoloArenaView(designs: picked.map { design in
                var d = design
                if let tireOverride { d.tires = tireOverride }
                return d
            })
        } else if launchIntoCustomizer {
            CustomizerView()
        } else if launchIntoCharacterEditor {
            NavigationStack { CharacterEditorView() }
        } else if launchIntoWardrobe {
            WardrobePreviewGrid()
        } else if launchIntoReactionCam {
            ReactionBenchGrid()
        } else if launchIntoPiPTuner {
            #if os(iOS)
            PiPTunerView()
            #endif
        } else if launchIntoTestMode {
            TestModeView()
        } else if launchIntoBuilder {
            TrackBuilderView()
        } else if launchIntoGarage {
            NavigationStack { GarageView() }
        } else if launchIntoRaceOnTV {
            NavigationStack { RaceOnTVView() }
        } else if Platform.isTV {
            ArenaLobbyView()
        } else if appModel.selectedProfile == nil {
            // "Who's playing?" gate — one tap, then home. Dev deep links
            // above skip it on purpose.
            ProfilePickerView()
        } else {
            homeScreen
        }
    }

    private var homeScreen: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("iPad Workshop")
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                NavigationLink {
                    QuickPlayView()
                } label: {
                    Label("QUICK PLAY!", systemImage: "play.fill")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .frame(width: 660, height: 96)
                }
                .buttonStyle(.borderedProminent)
                .tint(.yellow)
                .foregroundStyle(.black)
                homeBoard
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.09, green: 0.10, blue: 0.16))
            .foregroundStyle(.white)
            // Browsing is cheap and stops the moment you leave home. The
            // tile fades in when a TV starts advertising, which is exactly
            // when a kid opens the app on the Apple TV.
            .onAppear {
                SoundBank.shared.playMusic("workshop_ambience")
                tvFinder.start()
            }
            .onDisappear { tvFinder.stop() }
            .animation(.easeInOut(duration: 0.3), value: tvFinder.foundTV)
            .animation(.easeInOut(duration: 0.3), value: tvFinder.blocked)
            #if os(iOS)
            .toolbar { ToolbarItem(placement: .topBarLeading) { profileChip } }
            #endif
        }
    }

    /// Tap to go back to "Who's playing?" — switching kids mid-session.
    /// The profile colour alone read as decoration, not a way out, so the
    /// circle carries a back caret and the whole chip sits in a capsule —
    /// the same back affordance RaceOnTVView uses.
    private var profileChip: some View {
        let colorHex = appModel.selectedProfile?.colorHex ?? "#FFD500"
        return Button {
            appModel.selectedProfile = nil
            appModel.selectedDriver = nil
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color(hex: colorHex))
                    .frame(width: 34, height: 34)
                    .overlay {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 19, weight: .black))
                            // The profile swatches run all the way from near
                            // black to near white, so the caret's ink has to
                            // follow the circle it sits on.
                            .foregroundStyle(DriverPalette.needsLightInk(on: colorHex)
                                             ? .white : .black)
                    }
                Text(appModel.selectedProfile?.name ?? "")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
            }
            .padding(.horizontal, 14)
            .frame(height: 60)
            .background(.white.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
    }

    /// The home board's tiles, in the order they read: build, race, manage,
    /// share. Declared as a list rather than hand-laid GridRows so a tile that
    /// isn't available closes the gap behind it — a fixed grid left a hole in
    /// the middle of the board whenever "Race on TV" was away.
    ///
    /// Two screens deliberately have no tile, both reachable by launch arg:
    /// the PiP tuner (`--pip-tuner`, framing is settled) and the physics A/B
    /// bench (`--test-mode`). The bench went behind a flag because "Test My
    /// Cars" couldn't test your cars — its pickers are hard-wired to
    /// `CarDesign.demoPair` — and its rails toggle wrote a session-wide
    /// physics global that no other screen mentions.
    private enum HomeTile: CaseIterable {
        case buildCar, buildTrack, raceRobot, raceOnTV
        case garage, twoPlayer, myRacers

        var title: String {
            switch self {
            case .buildCar: "Build a Car"
            case .buildTrack: "Build a Track"
            case .raceRobot: "Race a Robot"
            case .raceOnTV: "Race on TV"
            case .garage: "Garage"
            case .twoPlayer: "2-Player Build"
            case .myRacers: "My Racers"
            }
        }

        /// What the tile shows above its label. Kids who can't read yet pick
        /// buttons by picture, and in a game about toys the picture should be
        /// the toy — so most tiles carry a render of the actual model
        /// (`tools/render_tile_art.py`). Two can't: no pack ships a
        /// television, and Kenney's pit garage has "TANKCO." branding baked
        /// into its texture, which is fine trackside and wrong on a kid's home
        /// screen. Those two keep a symbol rather than borrow a wrong toy.
        enum Art {
            case toy(String)        // loose PNG in Resources/Thumbs
            case symbol(String)     // SF Symbol
        }

        var art: Art {
            switch self {
            case .buildCar: .toy("tile-build-car")
            case .buildTrack: .toy("tile-build-track")
            case .raceRobot: .toy("tile-race-robot")
            case .raceOnTV: .symbol("tv.fill")
            case .garage: .symbol("door.garage.closed")
            case .twoPlayer: .toy("tile-two-player")
            case .myRacers: .toy("tile-my-racers")
            }
        }
    }

    /// Two to a row, in order, with an odd tile centred under the board rather
    /// than hanging off the left edge. Two columns of 320 + 20 of gutter is
    /// 660 — the same width as QUICK PLAY above it, which is what makes the
    /// whole screen line up.
    private var homeBoard: some View {
        let tiles = HomeTile.allCases.filter { tile in
            // "Race on TV" is only real when there's a TV to race on — or when
            // we were blocked from looking, so denying the Local Network
            // prompt doesn't hide the feature for good.
            tile != .raceOnTV || tvFinder.foundTV || tvFinder.blocked
        }
        let rows = stride(from: 0, to: tiles.count, by: 2).map {
            Array(tiles[$0..<min($0 + 2, tiles.count)])
        }
        return Grid(horizontalSpacing: 20, verticalSpacing: 20) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                GridRow {
                    ForEach(row, id: \.self) { tile in
                        homeLink(tile)
                        // A lone tile spans both columns so the Grid centres
                        // it. Spanning cells don't set column widths, so the
                        // full rows above still size the board.
                        .gridCellColumns(row.count == 1 ? 2 : 1)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func destination(for tile: HomeTile) -> some View {
        switch tile {
        case .buildCar: CustomizerView()
        case .buildTrack: TrackBuilderView()
        case .raceRobot: RobotRacePickerView()
        case .raceOnTV: RaceOnTVView()
        case .garage: GarageView()
        case .twoPlayer: CustomizerSplitView()
        case .myRacers: CharacterSelectView()
        }
    }

    /// A picture card: the toy on top, the name under it. Sized 320 × 140 so
    /// two columns still come to the 660 pt of QUICK PLAY above, and three
    /// rows still clear an 11-inch iPad in landscape.
    private func homeLink(_ tile: HomeTile) -> some View {
        NavigationLink {
            destination(for: tile)
        } label: {
            VStack(spacing: 6) {
                Group {
                    switch tile.art {
                    case .toy(let name):
                        // Rendered 2:1 and fitted, so it fills the strip
                        // without the card having to crop it.
                        bundleImage(name).resizable().scaledToFit()
                    case .symbol(let name):
                        Image(systemName: name)
                            .font(.system(size: 64, weight: .semibold))
                    }
                }
                .frame(height: 84)
                Text(tile.title)
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
            }
            .frame(width: 320, height: 140)
        }
        .buttonStyle(.bordered)
        .tint(.yellow)
    }
}

/// Quick Play: zero decisions — random starter car, random starter track,
/// medium robot, straight into Solo Arena. `--quick-play` launches here.
struct QuickPlayView: View {
    @Environment(AppModel.self) private var appModel
    // @State so the dice roll once per visit, not on every body re-eval.
    @State private var car = CarDesign.presets.randomElement()!
    @State private var track = TrackBlueprint.presets.randomElement()!.blueprint

    var body: some View {
        SoloArenaView(designs: [appModel.stampedRaceDesign(car: car)], blueprint: track,
                      config: MatchConfig(mode: .onePlayer, aiDifficulty: .medium))
            .onAppear { SoundBank.shared.play("grid_rev_anticipation") }
    }
}

/// Pick how clever the Hot Wheels robot is, then race it (1P mode, PRD §6.4).
struct RobotRacePickerView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(spacing: 24) {
            Text("Pick your rival!")
                .font(.system(size: 44, weight: .heavy, design: .rounded))
            ForEach([(AIDifficulty.easy, "Easy", "tortoise.fill"),
                     (.medium, "Medium", "hare.fill"),
                     (.hard, "Hard", "bolt.fill")], id: \.0) { difficulty, name, symbol in
                NavigationLink {
                    SoloArenaView(designs: [appModel.stampedRaceDesign()],
                                  config: MatchConfig(mode: .onePlayer,
                                                      aiDifficulty: difficulty))
                } label: {
                    Label(name, systemImage: symbol)
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .frame(width: 320, height: 80)
                }
                .buttonStyle(.bordered)
                .tint(.yellow)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.09, green: 0.10, blue: 0.16))
        .foregroundStyle(.white)
    }
}

#Preview {
    RootView()
        .environment(AppModel())
}
