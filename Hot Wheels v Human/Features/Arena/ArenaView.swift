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
    @State private var arenaAudio = ArenaAudio()

    /// The car the driver camera rides in — same pick as the arena camera's.
    private var heroSpeed: Float {
        let racers = coordinator.session.racers
        return (racers.first { !$0.isAI } ?? racers.first)?.speed ?? 0
    }

    var body: some View {
        ZStack {
            RealityView { content in
                content.camera = .virtual

                let root = Entity()
                content.add(root)

                // Sky + ground live under a named holder; the update
                // closure swaps the theme when a new track spawns.
                let environmentHolder = Entity()
                environmentHolder.name = "environment"
                root.addChild(environmentHolder)

                let light = DirectionalLight()
                light.light.intensity = 4000
                light.look(at: .zero, from: [1, 3, 2], relativeTo: nil)
                root.addChild(light)

                DriveSystem.registerSystem()
                RaceRulesSystem.registerSystem()

                let cameraEntity = PerspectiveCamera()
                cameraEntity.camera.near = RaceTuning.driverCamNear
                content.add(cameraEntity)

                let session = coordinator.session
                let feed = reactionFeed
                let audio = arenaAudio
                var smoothed = SIMD3<Float>(0, 2.2, -3)
                var loopBias: Float = 0   // 0 = chase from behind, 1 = 3/4 side (loops)
                cameraEntity.look(at: [0, 0, 1], from: smoothed, relativeTo: nil)
                camera = content.subscribe(to: SceneEvents.Update.self) { event in
                    feed.tick(session: session, dt: event.deltaTime)
                    audio.tick(session: session, station: coordinator.radioStation,
                               radioOn: coordinator.radioOn)

                    // Driver's-eye view: sit where the little human sits.
                    // Rolled with the car (upVector: its own up), so a loop
                    // really does go upside down. Falls through to the chase
                    // camera if that car is wrecked or out.
                    let hero = session.racers.first { !$0.isAI && $0.entity?.isEnabled == true }
                        ?? session.racers.first { $0.entity?.isEnabled == true }
                    // The flag ends the ride: from here the camera watches the
                    // cars, because the finish is where the loser falls apart
                    // and the cockpit points the other way.
                    let atTheFlag = session.phase == .results
                    if coordinator.driverView, !atTheFlag, let car = hero?.entity,
                       let ride = car.components[CarComponent.self]?.rideHeight {
                        // BOLTED to the car, not re-aimed at it every frame:
                        // a world-space look() reads the car's transform one
                        // frame stale, so the hood juddered against the near
                        // plane. As a child, the camera composes with the
                        // car's CURRENT pose — the hood is nailed in place,
                        // and a loop rolls the view upside down for free.
                        // CarFactory pinned rideHeight to half the visual
                        // height plus the bed offset — read it back out.
                        if cameraEntity.parent !== car {
                            car.addChild(cameraEntity)
                            // Height off rideHeight, not the bounds: the bounds
                            // include the driver, whose head clears the roof.
                            let height = (ride - RaceTuning.bedSurfaceHeight) * 2
                            let length = car.visualBounds(relativeTo: car).extents.z
                            cameraEntity.transform = Transform(
                                // A camera looks down its own −Z and the car's
                                // forward is +Z, hence the half turn; then nose
                                // down onto the hood.
                                rotation: simd_quatf(angle: .pi, axis: [0, 1, 0])
                                    * simd_quatf(angle: -RaceTuning.driverCamPitch,
                                                 axis: [1, 0, 0]),
                                translation: [0, height * RaceTuning.driverCamEyeRatio,
                                              length * RaceTuning.driverCamNoseRatio])
                        }
                        smoothed = cameraEntity.position(relativeTo: nil)
                        return   // chase eases out from here if the hero drops
                    }
                    // Back to the world: a camera left parented to a car
                    // vanishes with it on the next respawn.
                    if cameraEntity.parent !== root { root.addChild(cameraEntity) }

                    let positions = session.racers.compactMap {
                        $0.entity.flatMap { $0.isEnabled ? $0.position(relativeTo: nil) : nil }
                    }
                    guard !positions.isEmpty else { return }
                    let mid = positions.reduce(SIMD3<Float>.zero, +) / Float(positions.count)
                    let spread = positions.map { simd_length($0 - mid) }.max() ?? 0
                    var distance = max(1.6, spread * 2.2)
                    if atTheFlag { distance *= RaceTuning.finishCamZoom }
                    // 0.4 keeps the horizon + sky dome in the top of the
                    // frame (0.65 looked straight down at the play mat).
                    // A loop's circle lies in the plane of travel, so from
                    // straight behind it's edge-on — it reads as a wall, not
                    // a loop ("facing the wrong way"). Swing to a 3/4 side
                    // angle while a car is on or nearing a loop so the ring
                    // reads as the circle it is. loopBias eases the swing;
                    // detection is via the loopRanges the follower carries.
                    let nearLoop = session.racers.contains { racer in
                        guard let e = racer.entity, e.isEnabled,
                              let f = e.components[LaneFollowComponent.self] else { return false }
                        return f.loopRanges.contains { r in
                            f.nextIndex >= r.lowerBound - RaceTuning.loopCamLead
                                && f.nextIndex <= r.upperBound
                        }
                    }
                    loopBias = simd_mix(loopBias, nearLoop ? 1 : 0, 0.08)
                    let behind = SIMD3<Float>(0, distance * 0.4, -distance)
                    let side = SIMD3<Float>(distance * 0.9, distance * 0.4, -distance * 0.35)
                    let goal = mid + simd_mix(behind, side, SIMD3<Float>(repeating: loopBias))
                    smoothed = simd_mix(smoothed, goal, SIMD3<Float>(repeating: 0.04))
                    // Aiming BESIDE the pack slides it across the frame, which
                    // is what leaves the results panel a lane of its own.
                    var aim = mid
                    if atTheFlag {
                        let dir = simd_normalize(mid - smoothed)
                        let right = simd_cross(SIMD3<Float>(0, 1, 0), dir)
                        let length = simd_length(right)
                        if length > 1e-5 {
                            aim -= right / length * distance * RaceTuning.finishCamSideBias
                        }
                    }
                    cameraEntity.look(at: aim, from: smoothed, relativeTo: nil)
                }

                coordinator.attach(root: root)
            } update: { content in
                // Re-theme when the (next) race's track changes. Reading
                // trackID here re-runs this closure on each new race.
                let trackID = coordinator.session.trackID
                let worldTheme = coordinator.session.worldTheme
                let scenery = coordinator.session.scenery
                let worldEmpty = coordinator.session.worldEmpty
                let footprint = coordinator.session.trackFootprint
                guard let holder = content.entities.first?
                    .findEntity(named: "environment") else { return }
                let wanted = ArenaEnvironment.name(for: trackID, theme: worldTheme,
                                                   scenery: scenery, empty: worldEmpty)
                guard holder.children.first?.name != wanted,
                      holder.name != "building-\(wanted)" else { return }
                holder.name = "building-\(wanted)"
                Task { @MainActor in
                    let environment = await ArenaEnvironment.make(
                        for: trackID, theme: worldTheme, scenery: scenery,
                        empty: worldEmpty, around: footprint)
                    holder.children.removeAll()
                    holder.addChild(environment)
                    holder.name = "environment"
                }
            }
            // The scene runs edge to edge (under the status bar, out to the
            // TV's overscan); everything below stays inside the safe area.
            .ignoresSafeArea()
            ArenaHUDView(session: coordinator.session,
                         seriesLabel: coordinator.raceCount > 1
                             ? "Race \(coordinator.raceNumber) of \(coordinator.raceCount)"
                             : nil,
                         // Lift the race clock over the dash when it's up.
                         bottomInset: coordinator.driverView
                             && coordinator.session.phase != .results ? 110 : 0)

            // Driver's-seat dashboard: the radio, sitting on the hood line.
            if coordinator.driverView, coordinator.session.phase != .results {
                VStack {
                    Spacer()
                    DriverDashboardView(
                        station: coordinator.radioStation,
                        speed: heroSpeed,
                        powered: coordinator.radioOn,
                        onPick: { preset in
                            coordinator.radioStation = preset
                            coordinator.radioOn = true
                            SoundBank.shared.play("ui_tap")
                            SoundBank.shared.playMusic(preset.track)
                        },
                        onPower: {
                            coordinator.radioOn.toggle()
                            SoundBank.shared.play("ui_tap")
                            if coordinator.radioOn {
                                SoundBank.shared.playMusic(coordinator.radioStation.track)
                            } else {
                                SoundBank.shared.stopMusic()
                            }
                        })
                }
            }

            // Camera toggle — top-trailing, clear of the banners (top
            // centre), the PiPs (bottom) and Solo Arena's close button
            // (top-leading). One button for both platforms: the camera
            // belongs to the host, so tapping on iPad and clicking with
            // the Siri Remote hit the same switch.
            VStack {
                HStack {
                    Spacer()
                    Button {
                        coordinator.driverView.toggle()
                    } label: {
                        Label(coordinator.driverView ? "Driver View" : "Chase Cam",
                              systemImage: coordinator.driverView ? "steeringwheel" : "video.fill")
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .lineLimit(1)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 60)
                    }
                    .buttonStyle(.bordered)
                    .tint(.yellow)
                }
                Spacer()
            }
            .padding(24)

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
        .background(Color(red: 0.09, green: 0.10, blue: 0.16).ignoresSafeArea())
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
