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

    /// Dev deep links: `simctl launch <app> --solo-arena | --customizer`.
    private let launchIntoArena = ProcessInfo.processInfo.arguments.contains("--solo-arena")
    private let launchIntoCustomizer = ProcessInfo.processInfo.arguments.contains("--customizer")
    private let launchIntoCharacterEditor = ProcessInfo.processInfo.arguments.contains("--character-editor")
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
                          blueprint: RandomTrackGenerator.generate(
                              pieceCount: RaceTuning.maxTrackPieces))
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
                SpinningCarView()
                    .frame(maxHeight: 240)
                Grid(horizontalSpacing: 20, verticalSpacing: 20) {
                    GridRow {
                        homeLink("Build a Car", systemImage: "car.fill") { CustomizerView() }
                        homeLink("Build a Track", systemImage: "road.lanes.curved.right") { TrackBuilderView() }
                    }
                    GridRow {
                        homeLink("Race a Robot", systemImage: "flag.checkered") { RobotRacePickerView() }
                        homeLink("Race on TV", systemImage: "tv.fill") { RaceOnTVView() }
                    }
                    GridRow {
                        homeLink("Garage", systemImage: "door.garage.closed") { GarageView() }
                        homeLink("Test My Cars", systemImage: "stopwatch.fill") { TestModeView() }
                    }
                    GridRow {
                        homeLink("2-Player Build", systemImage: "person.2.fill") { CustomizerSplitView() }
                        homeLink("My Racers", systemImage: "person.crop.circle.fill") { CharacterSelectView() }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.09, green: 0.10, blue: 0.16))
            .foregroundStyle(.white)
            .onAppear { SoundBank.shared.playMusic("workshop_ambience") }
            #if os(iOS)
            .toolbar { ToolbarItem(placement: .topBarLeading) { profileChip } }
            #endif
        }
    }

    /// Tap to go back to "Who's playing?" — switching kids mid-session.
    private var profileChip: some View {
        Button {
            appModel.selectedProfile = nil
            appModel.selectedDriver = nil
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color(hex: appModel.selectedProfile?.colorHex ?? "#FFD500"))
                    .frame(width: 34, height: 34)
                Text(appModel.selectedProfile?.name ?? "")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
            }
            .padding(.horizontal, 14)
            .frame(height: 60)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
    }

    private func homeLink(_ title: String, systemImage: String,
                          destination: @escaping () -> some View) -> some View {
        NavigationLink {
            destination()
        } label: {
            Label(title, systemImage: systemImage)
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .frame(width: 320, height: 76)
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
        var design = car
        design.driver = appModel.raceDriver
        return SoloArenaView(designs: [design], blueprint: track,
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

/// Loads the pilot car USDZ and spins it on a turntable.
struct SpinningCarView: View {
    @State private var spin: EventSubscription?

    var body: some View {
        RealityView { content in
            content.camera = .virtual

            guard let car = try? await Entity(named: "vehicle-speedster") else {
                assertionFailure("vehicle-speedster.usdz missing from bundle")
                return
            }

            // Auto-frame whatever scale the conversion produced.
            let bounds = car.visualBounds(relativeTo: nil)
            car.position = -bounds.center
            let radius = max(bounds.boundingRadius, 0.01)

            let camera = PerspectiveCamera()
            camera.look(at: .zero, from: [0, radius * 0.9, radius * 2.2], relativeTo: nil)
            content.add(camera)

            let light = DirectionalLight()
            light.light.intensity = 5000
            light.look(at: .zero, from: [1, 2, 2], relativeTo: nil)
            content.add(light)

            let turntable = Entity()
            turntable.addChild(car)
            content.add(turntable)

            spin = content.subscribe(to: SceneEvents.Update.self) { event in
                turntable.transform.rotation *= simd_quatf(
                    angle: Float(event.deltaTime) * 1.2,
                    axis: [0, 1, 0]
                )
            }
        }
    }
}

#Preview {
    RootView()
        .environment(AppModel())
}
