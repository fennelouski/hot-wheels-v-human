//
//  RootView.swift
//  Hot Wheels v Human
//
//  Platform router. Phase 0: placeholder role screens proving the
//  RealityKit stack on both platforms. iPadOS → Workshop, tvOS → Arena.
//

import SwiftUI
import RealityKit

struct RootView: View {
    /// `simctl launch <app> --solo-arena` jumps straight to the demo track.
    private let launchIntoArena = ProcessInfo.processInfo.arguments.contains("--solo-arena")

    var body: some View {
        if launchIntoArena {
            SoloArenaView(designs: CarDesign.demoPair)
        } else if Platform.isTV {
            ArenaLobbyView()
        } else {
            homeScreen
        }
    }

    private var homeScreen: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(Platform.isTV ? "TV Arena" : "iPad Workshop")
                    .font(.system(size: 72, weight: .heavy, design: .rounded))
                SpinningCarView()
                NavigationLink {
                    SoloArenaView(designs: CarDesign.demoPair)
                } label: {
                    Text("🏁 Solo Arena")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .padding(.horizontal, 40)
                        .padding(.vertical, 20)
                }
                .buttonStyle(.borderedProminent)
                #if !os(tvOS)
                NavigationLink {
                    RaceOnTVView()
                } label: {
                    Text("📺 Race on TV")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .padding(.horizontal, 40)
                        .padding(.vertical, 20)
                }
                .buttonStyle(.bordered)
                NavigationLink {
                    TestModeView()
                } label: {
                    Text("🧪 Test Mode")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .padding(.horizontal, 40)
                        .padding(.vertical, 20)
                }
                .buttonStyle(.bordered)
                #endif
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.09, green: 0.10, blue: 0.16))
            .foregroundStyle(.white)
        }
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
}
