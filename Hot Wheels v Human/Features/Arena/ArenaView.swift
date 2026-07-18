//
//  ArenaView.swift
//  Hot Wheels v Human
//
//  The 3D race scene. Environment + chase camera live here; race logic
//  lives in the RaceCoordinator this view is attached to. Same view runs
//  on the TV (Multipeer host) and inside Solo Arena (loopback host).
//

import SwiftUI
import RealityKit

struct ArenaView: View {
    let coordinator: RaceCoordinator

    @State private var camera: EventSubscription?
    @State private var reactionFeed = ReactionFeed()

    var body: some View {
        ZStack {
            RealityView { content in
                content.camera = .virtual

                let root = Entity()
                content.add(root)

                let ground = ModelEntity(
                    mesh: .generatePlane(width: 14, depth: 14),
                    materials: [SimpleMaterial(color: .init(red: 0.16, green: 0.32, blue: 0.18, alpha: 1), isMetallic: false)])
                ground.position.y = -0.03
                ground.collision = CollisionComponent(shapes: [.generateBox(width: 14, height: 0.01, depth: 14)])
                ground.physicsBody = PhysicsBodyComponent(mode: .static)
                root.addChild(ground)

                let light = DirectionalLight()
                light.light.intensity = 4000
                light.look(at: .zero, from: [1, 3, 2], relativeTo: nil)
                root.addChild(light)

                DriveSystem.registerSystem()
                RaceRulesSystem.registerSystem()

                let cameraEntity = PerspectiveCamera()
                content.add(cameraEntity)

                let session = coordinator.session
                let feed = reactionFeed
                var smoothed = SIMD3<Float>(0, 2.2, -3)
                cameraEntity.look(at: [0, 0, 1], from: smoothed, relativeTo: nil)
                camera = content.subscribe(to: SceneEvents.Update.self) { event in
                    feed.tick(session: session, dt: event.deltaTime)
                    let positions = session.racers.compactMap {
                        $0.entity.flatMap { $0.isEnabled ? $0.position(relativeTo: nil) : nil }
                    }
                    guard !positions.isEmpty else { return }
                    let mid = positions.reduce(SIMD3<Float>.zero, +) / Float(positions.count)
                    let spread = positions.map { simd_length($0 - mid) }.max() ?? 0
                    let distance = max(1.6, spread * 2.2)
                    let goal = mid + SIMD3<Float>(0, distance * 0.65, -distance)
                    smoothed = simd_mix(smoothed, goal, SIMD3<Float>(repeating: 0.04))
                    cameraEntity.look(at: mid, from: smoothed, relativeTo: nil)
                }

                coordinator.attach(root: root)
            }
            ArenaHUDView(session: coordinator.session)

            // Reaction Cam PiPs — bottom-left for player 1, bottom-right
            // for player 2, while they hold the cam button on their iPad.
            VStack {
                Spacer()
                HStack {
                    ForEach(Array(coordinator.session.racers.enumerated()), id: \.element.id) { index, racer in
                        // `--show-cams`: sim/dev arg — PiPs on without a held button.
                        if coordinator.reactionCamsOn.contains(racer.id)
                            || ProcessInfo.processInfo.arguments.contains("--show-cams"),
                           let director = reactionFeed.directors[racer.id] {
                            ReactionCamView(director: director, design: racer.design)
                                .frame(maxWidth: .infinity,
                                       alignment: index % 2 == 0 ? .leading : .trailing)
                        }
                    }
                }
                .padding(24)
            }
            if let rejection = coordinator.lastRejection {
                Text(rejection).font(.title2).padding()
                    .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
            }
        }
        .background(Color(red: 0.09, green: 0.10, blue: 0.16))
    }
}

extension CarDesign {
    /// RaceCore README tuning pair: heavy+grippy must clear the loop,
    /// light+slick should get flung ~half the time.
    static let demoPair = [
        CarDesign(id: UUID(uuidString: "CA200000-0000-0000-0000-000000000001")!,
                  name: "Tank", chassis: .heavyMuscle, tires: .grippyOffroad,
                  paint: PaintSpec(colorHex: "#2266FF", finish: .glossy)),
        CarDesign(id: UUID(uuidString: "CA200000-0000-0000-0000-000000000002")!,
                  name: "Zoomie", chassis: .superlightDrift, tires: .slickRacing,
                  paint: PaintSpec(colorHex: "#FF6600", finish: .metallic)),
    ]
}
