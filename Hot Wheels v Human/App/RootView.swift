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
    private let launchIntoBuilder = ProcessInfo.processInfo.arguments.contains("--trackbuilder")

    var body: some View {
        if launchIntoArena {
            SoloArenaView(designs: CarDesign.demoPair)
        } else if launchIntoCustomizer {
            CustomizerView()
        } else if launchIntoBuilder {
            TrackBuilderView()
        } else if Platform.isTV {
            ArenaLobbyView()
        } else {
            homeScreen
        }
    }


    private var homeScreen: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("iPad Workshop")
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                SpinningCarView()
                    .frame(maxHeight: 240)
                Grid(horizontalSpacing: 20, verticalSpacing: 20) {
                    GridRow {
                        homeLink("🏎️ Build a Car") { CustomizerView() }
                        homeLink("🛠️ Build a Track") { TrackBuilderView() }
                    }
                    GridRow {
                        homeLink("🏁 Race a Robot") { RobotRacePickerView() }
                        homeLink("📺 Race on TV") { RaceOnTVView() }
                    }
                    GridRow {
                        homeLink("🏚️ Garage") { GarageView() }
                        homeLink("🧪 Test My Cars") { TestModeView() }
                    }
                    GridRow {
                        homeLink("👥 2-Player Build") { CustomizerSplitView() }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.09, green: 0.10, blue: 0.16))
            .foregroundStyle(.white)
            .onAppear { SoundBank.shared.playMusic("workshop_ambience") }
        }
    }

    private func homeLink(_ title: String, destination: @escaping () -> some View) -> some View {
        NavigationLink {
            destination()
        } label: {
            Text(title)
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .frame(width: 320, height: 76)
        }
        .buttonStyle(.bordered)
        .tint(.yellow)
    }
}

/// Pick how clever the Hot Wheels robot is, then race it (1P mode, PRD §6.4).
struct RobotRacePickerView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(spacing: 24) {
            Text("Pick your rival!")
                .font(.system(size: 44, weight: .heavy, design: .rounded))
            ForEach([(AIDifficulty.easy, "🐢 Easy"),
                     (.medium, "🐰 Medium"),
                     (.hard, "🤖 Hard")], id: \.0) { difficulty, label in
                NavigationLink {
                    SoloArenaView(designs: [appModel.raceDesign],
                                  config: MatchConfig(mode: .onePlayer,
                                                      aiDifficulty: difficulty))
                } label: {
                    Text(label)
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
