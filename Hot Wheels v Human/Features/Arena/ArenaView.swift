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
    @HWReduceMotion private var reduceMotion

    /// Does this collision hit belong to a car (its own body, a wheel, the
    /// driver) rather than to the track? Cars are the thing we're trying to
    /// see, so they never count as blocking the view of themselves.
    private static func isCar(_ entity: Entity) -> Bool {
        var node: Entity? = entity
        while let current = node {
            if current.components[CarComponent.self] != nil { return true }
            node = current.parent
        }
        return false
    }

    /// The car the driver camera rides in — same pick as the arena camera's.
    private var hero: RaceSession.Racer? {
        let racers = coordinator.session.racers
        return racers.first { !$0.isAI } ?? racers.first
    }
    /// Apple TV remote camera peek, written by swipes and eased back to the
    /// auto-cam each frame in the scene update (tvOS only; iPad has no remote).
    @State private var camNudge = CameraNudge()

    var body: some View {
        ZStack {
            RealityView { content in
                #if !os(visionOS)
                content.camera = .virtual
                content.renderingEffects.dynamicRange = .standard
                content.renderingEffects.customPostProcessing = .effect(ArenaSnapshotEffect(capture: coordinator.frameCapture))
                #endif

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

                #if os(visionOS)
                // This legacy chase-view is never the headset scene root. Its
                // camera math uses an entity while SpatialRaceTable supplies
                // the native view of the real simulation.
                let cameraEntity = Entity()
                #else
                let cameraEntity = PerspectiveCamera()
                cameraEntity.camera.near = RaceTuning.driverCamNear
                #endif
                content.add(cameraEntity)

                let session = coordinator.session
                let feed = reactionFeed
                let audio = arenaAudio
                let nudge = camNudge
                let coord = coordinator
                var smoothed = SIMD3<Float>(0, 2.2, -3)
                var loopBias: Float = 0   // 0 = chase from behind, 1 = 3/4 side (loops)
                var blockedFor: Double = 0   // seconds of track between us and the cars
                var idleAngle: Float = 0  // lobby attract-orbit around the empty arena
                // Smoothed framing so a new showcase track glides in, not snaps.
                var idleCenter = SIMD3<Float>(0, 0, 0)
                var idleR = RaceTuning.lobbyCamRadius
                var idleH = RaceTuning.lobbyCamHeight
                cameraEntity.look(at: [0, 0, 1], from: smoothed, relativeTo: nil)
                camera = content.subscribe(to: SceneEvents.Update.self) { event in
                    if GameEffectsPolicy.shared.motionEnabled { feed.tick(session: session, dt: event.deltaTime) }

                    // Driver's-eye view: sit where the little human sits.
                    // Rolled with the car (upVector: its own up), so a loop
                    // really does go upside down. Falls through to the chase
                    // camera if that car is wrecked or out.
                    let hero = session.racers.first { !$0.isAI && $0.entity?.isEnabled == true }
                        ?? session.racers.first { $0.entity?.isEnabled == true }
                    // The listener rides with the camera, so the cockpit's own
                    // engine has to duck — ArenaAudio needs to know whose.
                    let inCar = GameEffectsPolicy.shared.motionEnabled && coordinator.driverView && session.phase != .results
                        ? hero?.id : nil
                    audio.tick(session: session, station: coordinator.radioStation,
                               radioOn: coordinator.radioOn, driverCarID: inCar)
                    // The flag ends the ride: from here the camera watches the
                    // cars, because the finish is where the loser falls apart
                    // and the cockpit points the other way.
                    let atTheFlag = session.phase == .results
                    if !GameEffectsPolicy.shared.motionEnabled {
                        if cameraEntity.parent !== root { root.addChild(cameraEntity) }
                        let rect = session.trackFootprint
                        let center = SIMD3<Float>((rect?.minX ?? 0) + (rect?.maxX ?? 0), 0,
                                                  (rect?.minZ ?? 0) + (rect?.maxZ ?? 0)) / 2
                        let span = max((rect?.maxX ?? 2) - (rect?.minX ?? -2),
                                       (rect?.maxZ ?? 2) - (rect?.minZ ?? -2), 3)
                        cameraEntity.look(at: center, from: center + SIMD3<Float>(span * 0.65, span * 0.85, -span * 0.9), relativeTo: nil)
                        return
                    }
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
                    var offset = simd_mix(behind, side, SIMD3<Float>(repeating: loopBias))
                    let yaw = nudge.yaw
                    offset = SIMD3<Float>(
                        offset.x * cos(yaw) - offset.z * sin(yaw),
                        offset.y + nudge.height,
                        offset.x * sin(yaw) + offset.z * cos(yaw))
                    nudge.yaw *= RaceTuning.camNudgeDecay
                    nudge.height *= RaceTuning.camNudgeDecay
                    var goal = mid + offset

                    // Elevated track parks itself between the camera and the
                    // cars, and from behind a deck the race is an orange wall.
                    // Ask the physics whether anything that isn't a car is in
                    // the way; if the normal framing is still blocked a few
                    // seconds later, go stand somewhere it isn't.
                    //
                    // The test is on the DEFAULT spot, not on where the camera
                    // currently is — testing the current spot makes the escape
                    // undo itself the moment it works, and the camera flaps
                    // back and forth between the two.
                    let subject = hero?.entity?.position(relativeTo: nil) ?? mid
                    func clear(_ from: SIMD3<Float>) -> Bool {
                        !event.scene.raycast(from: from, to: subject, query: .nearest,
                                             mask: .all, relativeTo: nil)
                            .contains { !Self.isCar($0.entity) }
                    }
                    blockedFor = clear(goal) ? 0 : blockedFor + event.deltaTime
                    var ease: Float = 0.04
                    if blockedFor > RaceTuning.camBlockedGrace {
                        let offset = goal - mid
                        let flat = SIMD3<Float>(offset.x, 0, offset.z)
                        for escape in RaceTuning.camEscapes {
                            let turned = simd_quatf(angle: escape.x, axis: [0, 1, 0]).act(flat)
                            let spot = mid + turned * escape.z
                                + SIMD3<Float>(0, distance * escape.y, 0)
                            if clear(spot) {
                                goal = spot
                                // The lazy drift is for framing, not rescue —
                                // at 0.04 the trip to the escape spot ate two
                                // more seconds of not seeing the race.
                                ease = RaceTuning.camEscapeEase
                                break
                            }
                        }
                    }

                    smoothed = simd_mix(smoothed, goal, SIMD3<Float>(repeating: ease))
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
                if reduceMotion {
                    for entity in content.entities { entity.stopAllAnimations(recursive: true) }
                }
                // Re-theme when the (next) race's track changes. Reading
                // trackID here re-runs this closure on each new race.
                let trackID = coordinator.session.trackID ?? coordinator.lobbyTrackID
                let worldTheme = coordinator.session.worldTheme
                let scenery = coordinator.session.scenery
                let worldEmpty = coordinator.session.worldEmpty
                let footprint = coordinator.session.trackFootprint
                    ?? coordinator.lobbyFootprint ?? RaceTuning.lobbyFootprint
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
                         bottomInset: (coordinator.driverView || reduceMotion)
                             && coordinator.session.phase != .results ? 110 : 0)

            // Driver's-seat dashboard: the radio, sitting on the hood line.
            if coordinator.driverView || reduceMotion, coordinator.session.phase != .results {
                VStack {
                    Spacer()
                    DriverDashboardView(
                        station: coordinator.radioStation,
                        speed: hero?.speed ?? 0,
                        powered: coordinator.radioOn,
                        style: DashStyle(design: hero?.design ?? CarDesign.demoPair[0]),
                        volume: Binding(
                            get: { coordinator.musicLevel },
                            set: {
                                coordinator.musicLevel = $0
                                SoundBank.shared.musicLevel = Float($0)
                            }),
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
            VStack(alignment: .trailing, spacing: 12) {
                HStack {
                    Spacer()
                    Button {
                        coordinator.driverView.toggle()
                    } label: {
                        Label(reduceMotion ? "Calm Cam" : coordinator.driverView ? "Driver View" : "Chase Cam",
                              systemImage: reduceMotion ? "camera.fill" : coordinator.driverView ? "steeringwheel" : "video.fill")
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .lineLimit(1)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 60)
                    }
                    #if os(tvOS)
                    .buttonStyle(TVWorkshopButtonStyle(selected: coordinator.driverView))
                    .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 16))
                    #else
                    .buttonStyle(.bordered)
                    .tint(.yellow)
                    #endif
                    .accessibilityIdentifier("race-camera")
                    .accessibilityValue(reduceMotion ? "Calm Cam" : coordinator.driverView ? "Driver View" : "Chase Cam")
                    .disabled(reduceMotion)
                }
                TrackVisibilityPicker(selection: coordinator.trackVisibility) {
                    coordinator.trackVisibility = $0
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
                        if !reduceMotion && (coordinator.reactionCamsOn.contains(racer.id)
                            || ProcessInfo.processInfo.arguments.contains("--show-cams")),
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
        .task(id: coordinator.session.completedResult?.id) {
            guard coordinator.session.completedResult != nil else { coordinator.clearShare(); return }
            // Let the real finish camera settle; this doesn't delay race input
            // or any computer move. The copied frame remains immutable.
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            coordinator.captureResult(using: coordinator.frameCapture)
        }
        .onDisappear {
            if !coordinator.isPresentingResultShare { coordinator.frameCapture.cancel() }
        }
    }
}

/// The three-way track switch. Icon only, per the ask — and it has to read
/// at 3 m from a sofa anyway; `Label` still hands the words to VoiceOver.
/// The eye opens, half-closes, shuts, which is the same progression the
/// track makes. The SAME control sits over the arena and on the iPad
/// controller, because whichever one the kid grabs should look identical.
struct TrackVisibilityPicker: View {
    let selection: TrackVisibility
    var size: CGFloat = 60
    let onPick: (TrackVisibility) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(TrackVisibility.allCases, id: \.self) { mode in
                Button {
                    onPick(mode)
                    SoundBank.shared.play("ui_tap")
                } label: {
                    Label(mode.title, systemImage: mode.symbolName)
                        .labelStyle(.iconOnly)
                        .font(.system(size: size * 0.43, weight: .bold))
                        .frame(width: size, height: size)
                }
                #if os(tvOS)
                .buttonStyle(TVWorkshopButtonStyle(selected: selection == mode))
                .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 16))
                #else
                .buttonStyle(.bordered)
                .tint(selection == mode ? .yellow : .gray)
                #endif
                .accessibilityIdentifier("race-track-\(mode.rawValue)")
                .accessibilityAddTraits(selection == mode ? .isSelected : [])
            }
        }
    }
}

/// SF Symbols + the words VoiceOver reads (CLAUDE.md: no emoji).
extension TrackVisibility {
    var symbolName: String {
        switch self {
        case .all: "eye.fill"
        case .hideGhosts: "eye.half.closed.fill"
        case .hideAll: "eye.slash.fill"
        }
    }

    var title: String {
        switch self {
        case .all: "Show all track"
        case .hideGhosts: "Hide ghost track"
        case .hideAll: "Hide all track"
        }
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
