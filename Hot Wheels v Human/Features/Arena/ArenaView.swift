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
    /// Apple TV remote camera peek, written by swipes and eased back to the
    /// auto-cam each frame in the scene update (tvOS only; iPad has no remote).
    @State private var camNudge = CameraNudge()

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
                content.add(cameraEntity)

                let session = coordinator.session
                let feed = reactionFeed
                let audio = arenaAudio
                let nudge = camNudge
                let coord = coordinator
                var smoothed = SIMD3<Float>(0, 2.2, -3)
                var loopBias: Float = 0   // 0 = chase from behind, 1 = 3/4 side (loops)
                var idleAngle: Float = 0  // lobby attract-orbit around the empty arena
                // Smoothed framing so a new showcase track glides in, not snaps.
                var idleCenter = SIMD3<Float>(0, 0, 0)
                var idleR = RaceTuning.lobbyCamRadius
                var idleH = RaceTuning.lobbyCamHeight
                cameraEntity.look(at: [0, 0, 1], from: smoothed, relativeTo: nil)
                camera = content.subscribe(to: SceneEvents.Update.self) { event in
                    feed.tick(session: session, dt: event.deltaTime)
                    audio.tick(session: session)
                    let positions = session.racers.compactMap {
                        $0.entity.flatMap { $0.isEnabled ? $0.position(relativeTo: nil) : nil }
                    }
                    guard !positions.isEmpty else {
                        // No car yet: slowly circle the current showcase track
                        // (or the default box) so the lobby has a living backdrop.
                        idleAngle += Float(event.deltaTime) * RaceTuning.lobbyCamSpin
                        let fp = coord.lobbyFootprint ?? RaceTuning.lobbyFootprint
                        let center = SIMD3<Float>((fp.minX + fp.maxX) / 2, 0,
                                                  (fp.minZ + fp.maxZ) / 2)
                        let size = max(fp.maxX - fp.minX, fp.maxZ - fp.minZ)
                        // Ease framing toward the current track's size/position.
                        idleCenter += (center - idleCenter) * 0.02
                        idleR += (max(RaceTuning.lobbyCamRadius, size * 0.9) - idleR) * 0.02
                        idleH += (max(RaceTuning.lobbyCamHeight, size * 0.35) - idleH) * 0.02
                        let eye = idleCenter + SIMD3<Float>(sin(idleAngle) * idleR,
                                                            idleH, cos(idleAngle) * idleR)
                        cameraEntity.look(at: idleCenter + [0, 0.4, 0], from: eye,
                                          relativeTo: nil)
                        return
                    }
                    let mid = positions.reduce(SIMD3<Float>.zero, +) / Float(positions.count)
                    let spread = positions.map { simd_length($0 - mid) }.max() ?? 0
                    let distance = max(1.6, spread * 2.2)
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
                    var offset = simd_mix(behind, side, SIMD3<Float>(repeating: loopBias))
                    // Remote peek: a swipe orbits (yaw) and lifts/drops (height)
                    // this offset, then it decays back so the auto-cam wins again.
                    let yaw = nudge.yaw
                    offset = SIMD3<Float>(
                        offset.x * cos(yaw) - offset.z * sin(yaw),
                        offset.y + nudge.height,
                        offset.x * sin(yaw) + offset.z * cos(yaw))
                    nudge.yaw *= RaceTuning.camNudgeDecay
                    nudge.height *= RaceTuning.camNudgeDecay
                    let goal = mid + offset
                    smoothed = simd_mix(smoothed, goal, SIMD3<Float>(repeating: 0.04))
                    cameraEntity.look(at: mid, from: smoothed, relativeTo: nil)
                }

                coordinator.attach(root: root)
            } update: { content in
                // Re-theme when the (next) race's track changes. Reading
                // trackID here re-runs this closure on each new race.
                // In the lobby, fall back to the showcase track so its sky theme
                // and props swap in as the parade cycles; else the default box.
                let trackID = coordinator.session.trackID ?? coordinator.lobbyTrackID
                let footprint = coordinator.session.trackFootprint
                    ?? coordinator.lobbyFootprint ?? RaceTuning.lobbyFootprint
                guard let holder = content.entities.first?
                    .findEntity(named: "environment") else { return }
                let wanted = ArenaEnvironment.name(for: trackID)
                guard holder.children.first?.name != wanted,
                      holder.name != "building-\(wanted)" else { return }
                holder.name = "building-\(wanted)"
                Task { @MainActor in
                    let environment = await ArenaEnvironment.make(
                        for: trackID, around: footprint)
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
                             : nil)

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
        // Siri Remote camera peek — TV only; iPad's arena keeps focus for its
        // boost buttons. .focusable() so the arena receives swipes when no
        // control is focused.
        #if os(tvOS)
        .focusable()
        .onMoveCommand { direction in
            switch direction {
            case .left:  camNudge.yaw += RaceTuning.camNudgeYawStep
            case .right: camNudge.yaw -= RaceTuning.camNudgeYawStep
            case .up:    camNudge.height += RaceTuning.camNudgeHeightStep
            case .down:  camNudge.height -= RaceTuning.camNudgeHeightStep
            default: break
            }
        }
        #endif
    }
}

/// Shared between the SwiftUI remote handler (writes on swipe) and the
/// RealityKit scene update (reads + decays each frame). Both run on the
/// main actor. Not @Observable — nothing renders from it, the render loop
/// polls it.
@MainActor final class CameraNudge {
    var yaw: Float = 0
    var height: Float = 0
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
