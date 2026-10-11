#if os(visionOS)
import SwiftUI
import SwiftData
import RealityKit

/// Uses the saved workshop selections and the existing loopback race protocol.
struct SpatialWorkshopView: View {
    private enum Shelf: String, CaseIterable, Identifiable {
        case race = "Race", cars = "Cars", drivers = "Drivers", tracks = "Tracks"
        var id: Self { self }
        var symbol: String {
            switch self { case .race: "flag.checkered"; case .cars: "car.side.fill"; case .drivers: "person.crop.circle.fill"; case .tracks: "point.topleft.down.to.point.bottomright.curvepath" }
        }
    }
    @Environment(AppModel.self) private var appModel
    @Environment(\.openWindow) private var openWindow
    @Query private var savedCars: [CarDesignRecord]
    @Query private var savedDrivers: [DriverProfileRecord]
    @Query private var savedTracks: [TrackBlueprintRecord]
    @State private var shelf = Shelf.race
    @AppStorage("race.visionRobot") private var racesRobot = true

    var body: some View {
        NavigationSplitView {
            List(Shelf.allCases) { item in
                Button { shelf = item } label: {
                    Label(item.rawValue, systemImage: item.symbol).font(.headline).padding(.vertical, 12)
                }.buttonStyle(.plain).hoverEffect(.highlight)
            }.navigationTitle("Workshop").navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text(shelf == .race ? "Race on your table." : shelf.rawValue)
                        .font(.system(.largeTitle, design: .rounded).weight(.black))
                    switch shelf {
                    case .race:
                        Image(systemName: "flag.checkered.2.crossed").font(.system(size: 100)).foregroundStyle(.orange)
                            .padding(32).frame(maxWidth: .infinity).accessibilityHidden(true)
                        selectionRow(appModel.raceDesign.name, symbol: "car.side.fill", shelf: .cars)
                        selectionRow(appModel.raceDriver.name, symbol: "person.crop.circle.fill", shelf: .drivers)
                        selectionRow(trackName, symbol: "point.topleft.down.to.point.bottomright.curvepath", shelf: .tracks)
                        Toggle("Race a robot", isOn: $racesRobot).font(.headline)
                    case .cars:
                        ForEach(CarDesign.demoPair + savedCars.compactMap(\.design)) { car in
                            choice(car.name, symbol: "car.side.fill", selected: appModel.raceDesign.id == car.id) { appModel.selectedDesign = car }
                        }
                    case .drivers:
                        ForEach(DriverProfile.presets + savedDrivers.compactMap(\.profile)) { driver in
                            choice(driver.name, symbol: "person.crop.circle.fill", selected: appModel.raceDriver.id == driver.id) { appModel.selectedDriver = driver }
                        }
                    case .tracks:
                        ForEach(TrackBlueprint.presets, id: \.blueprint.trackId) { preset in
                            choice(preset.name, symbol: "flag.checkered", selected: appModel.raceBlueprint.trackId == preset.blueprint.trackId) { appModel.selectedBlueprint = preset.blueprint }
                        }
                        ForEach(savedTracks) { record in
                            if let blueprint = record.blueprint {
                                choice(record.name, symbol: "square.and.pencil", selected: appModel.raceBlueprint.trackId == blueprint.trackId) { appModel.selectedBlueprint = blueprint }
                            }
                        }
                    }
                }.padding(36).frame(maxWidth: 720).frame(maxWidth: .infinity)
            }.navigationTitle("Hot Wheels vs Humans")
        }
        .frame(minWidth: 820, minHeight: 620)
        .ornament(attachmentAnchor: .scene(.bottom), contentAlignment: .top) {
            Button { openWindow(id: "hw-spatial-race") } label: {
                Label("Race!", systemImage: "play.fill").font(.title2.bold()).padding(.horizontal, 32)
            }.buttonStyle(.borderedProminent).tint(.orange).keyboardShortcut(.defaultAction)
                .controlSize(.large).padding(16).glassBackgroundEffect().accessibilityIdentifier("spatial.race.start")
        }
    }
    private var trackName: String {
        savedTracks.first(where: { $0.id == appModel.raceBlueprint.trackId })?.name
            ?? TrackBlueprint.presets.first(where: { $0.blueprint.trackId == appModel.raceBlueprint.trackId })?.name ?? "My track"
    }
    private func selectionRow(_ title: String, symbol: String, shelf: Shelf) -> some View {
        Button { self.shelf = shelf } label: {
            HStack { Label(title, systemImage: symbol).font(.title3.bold()); Spacer(); Image(systemName: "chevron.right") }
                .padding(20).background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
        }.buttonStyle(.plain).hoverEffect(.highlight)
    }
    private func choice(_ title: String, symbol: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack { Label(title, systemImage: symbol).font(.headline).fixedSize(horizontal: false, vertical: true); Spacer(); if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(.orange) } }
                .padding(20).frame(minHeight: 64).background(.orange.opacity(selected ? 0.16 : 0.05), in: RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain).hoverEffect(.highlight).accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct SpatialRaceTable: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var rig: SoloRig?
    @State private var projection = RaceTableProjection()
    @State private var subscription: EventSubscription?
    @State private var boostTask: Task<Void, Never>?
    @State private var sharedResult: URL?
    @State private var filedResultID: UUID?
    @State private var zoom: Float = 1
    @State private var angle = 0.0

    var body: some View {
        RealityView { content in
            DriveSystem.registerSystem()
            RaceRulesSystem.registerSystem()
            content.add(projection.simulation)
            content.add(projection.presentation)
            subscription = content.subscribe(to: SceneEvents.Update.self) { _ in
                if let rig { projection.synchronize(session: rig.coordinator.session, zoom: zoom, angle: Float(angle)) }
            }
        } update: { _ in
            if let rig { projection.synchronize(session: rig.coordinator.session, zoom: zoom, angle: Float(angle)) }
        }
        .ornament(attachmentAnchor: .scene(.top), contentAlignment: .bottom) {
            VStack(spacing: 12) {
                if let session = rig?.coordinator.session {
                    Text(session.phase == .countdown ? "\(session.countdownValue)" : session.phase == .results ? "Race complete" : session.trackName)
                        .font(.title.bold()).accessibilityIdentifier("spatial.race.status")
                    HStack(spacing: 28) {
                        ForEach(session.racers) { racer in
                            VStack(spacing: 4) {
                                Text(racer.design.name).font(.headline).fixedSize(horizontal: false, vertical: true)
                                Text(racer.finishTime.map { String(format: "%.1f s", $0) } ?? String(format: "%.1f m/s", racer.speed)).monospacedDigit()
                                ProgressView(value: Double(racer.progress)).frame(width: 160)
                            }
                        }
                    }
                } else { ProgressView("Building race") }
            }.padding(16).glassBackgroundEffect()
        }
        .ornament(attachmentAnchor: .scene(.bottom), contentAlignment: .top) {
            VStack(spacing: 12) {
                if let rig {
                    HStack(spacing: 24) {
                        if rig.coordinator.session.phase == .results {
                            Button("Race again", systemImage: "arrow.clockwise") { rig.dashboards.forEach { $0.requestRematch() } }
                                .buttonStyle(.borderedProminent).tint(.orange).accessibilityIdentifier("race-rematch")
                            if let sharedResult { ShareLink(item: sharedResult) { Label("Share", systemImage: "square.and.arrow.up") } }
                        } else if let model = rig.dashboards.first, let car = model.myCar {
                            Button("Boost", systemImage: "bolt.fill") {
                                boostTask?.cancel()
                                model.beginBoost()
                                boostTask = Task { try? await Task.sleep(for: .milliseconds(350)); model.endBoost() }
                            }.buttonStyle(.borderedProminent).tint(.orange)
                                .disabled(rig.coordinator.session.phase != .racing || car.boostMeter < 1)
                                .accessibilityIdentifier("race-boost")
                            ProgressView(value: Double(min(max(car.boostMeter, 0), 2)), total: 2).frame(width: 140)
                        }
                        Button("Workshop", systemImage: "house") { dismissWindow(id: "hw-spatial-race") }
                    }.controlSize(.large)
                    HStack(spacing: 20) {
                        Label("Size", systemImage: "arrow.up.left.and.arrow.down.right")
                        Slider(value: $zoom, in: 0.75...1.15).frame(width: 160)
                        Label("Turn", systemImage: "rotate.3d")
                        Slider(value: $angle, in: -Double.pi...Double.pi).frame(width: 180)
                    }
                }
            }.padding(16).glassBackgroundEffect()
        }
        .task {
            guard rig == nil else { return }
            let hub = LoopbackTransport.hub(playerCount: 1)
            let coordinator = RaceCoordinator(transport: hub.host)
            let dashboard = DashboardModel(transport: hub.players[0], playerName: "Solo Racer")
            coordinator.start(); dashboard.start()
            let robot = GamePreferences.shared.bool("race.visionRobot", fallback: true)
            dashboard.submit(designs: [appModel.stampedRaceDesign()], tracks: [appModel.raceBlueprint],
                             config: MatchConfig(mode: robot ? .onePlayer : .solo, aiDifficulty: robot ? .medium : nil))
            dashboard.sendReady()
            rig = SoloRig(coordinator: coordinator, dashboards: [dashboard])
            coordinator.attach(root: projection.simulation)
        }
        .onChange(of: rig?.coordinator.session.completedResult?.id) { _, _ in saveCompletedResult() }
        .onDisappear {
            boostTask?.cancel(); rig?.dashboards.forEach { $0.endBoost(); $0.stop() }
            rig?.coordinator.stop(); subscription?.cancel(); subscription = nil
        }
    }

    private func saveCompletedResult() {
        guard let result = rig?.coordinator.session.completedResult, filedResultID != result.id else { return }
        filedResultID = result.id
        for entry in result.entries {
            if let seconds = entry.finishTime { modelContext.recordFinish(trackID: result.trackID, carName: entry.carName, seconds: seconds) }
        }
        // Export genuine frozen result data. Headset cameras are never captured.
        let renderer = ImageRenderer(content: VStack(alignment: .leading, spacing: 24) {
            Text("Hot Wheels vs Humans").font(.title2.bold())
            Text(result.winner.map { "\($0.carName) wins!" } ?? "Race complete").font(.largeTitle.bold())
            Text(result.trackName).font(.headline)
            ForEach(result.rankedEntries) { entry in
                HStack { Text(entry.carName).bold(); Spacer(); Text(entry.finishTime.map { String(format: "%.1f s", $0) } ?? "Out").monospacedDigit() }
            }
            Text(RaceShareResult.appURL.absoluteString).font(.caption)
        }.padding(40).frame(width: 760).foregroundStyle(.white).background(Color(red: 0.07, green: 0.08, blue: 0.13)))
        guard let bytes = renderer.uiImage?.pngData() else { return }
        let folder = HWTestSession.isActive ? HWTestSession.directory : FileManager.default.temporaryDirectory
        let url = folder.appendingPathComponent("Spatial-Race-\(result.id).png")
        do { try bytes.write(to: url, options: .atomic); sharedResult = url } catch { sharedResult = nil }
    }
}

/// Visible miniature models schedule the same Drive/Rules systems that advance
/// the full-size simulation; the display copies never carry game components.
struct SpatialRaceDisplayComponent: Component {}

/// Keeps simulation in its original metre coordinate system. Only its render
/// projection is miniature; the car forces, waypoints and finish logic are unchanged.
@MainActor private final class RaceTableProjection {
    let simulation = Entity()
    let presentation = Entity()
    private let scaledContent = Entity()
    private var pairs: [(source: Entity, display: Entity)] = []
    private var sourceChildren: [UInt64] = []
    private var fittedHeight: Float = 1
    init() {
        SpatialRaceDisplayComponent.registerComponent()
        simulation.components.set(OpacityComponent(opacity: 0))
        presentation.addChild(scaledContent)
    }
    func synchronize(session: RaceSession, zoom: Float, angle: Float) {
        guard [.countdown, .racing, .results].contains(session.phase), let bounds = session.trackFootprint else { return }
        let children = simulation.children.map(\.id)
        if sourceChildren != children {
            sourceChildren = children; pairs.removeAll(); scaledContent.children.removeAll()
            fittedHeight = max(simulation.visualBounds(relativeTo: simulation).extents.y, 1)
            for source in simulation.children {
                let display = source.clone(recursive: true)
                stripSimulation(from: display)
                scaledContent.addChild(display)
                collect(source, display)
            }
        }
        for pair in pairs { pair.display.transform = pair.source.transform; pair.display.isEnabled = pair.source.isEnabled }
        let scale = min(1.05 / max(bounds.maxX - bounds.minX, 1), 1.05 / max(bounds.maxZ - bounds.minZ, 1), 0.65 / fittedHeight) * zoom
        scaledContent.scale = SIMD3(repeating: scale)
        scaledContent.position = [-(bounds.minX + bounds.maxX) * 0.5 * scale, 0, -(bounds.minZ + bounds.maxZ) * 0.5 * scale]
        presentation.position = [0, -0.3, 0]
        presentation.orientation = simd_quatf(angle: angle, axis: [0, 1, 0])
    }
    private func collect(_ source: Entity, _ display: Entity) {
        pairs.append((source, display))
        for (original, copy) in zip(source.children, display.children) { collect(original, copy) }
    }
    private func stripSimulation(from entity: Entity) {
        entity.components.remove(PhysicsBodyComponent.self)
        entity.components.remove(PhysicsMotionComponent.self)
        entity.components.remove(CollisionComponent.self)
        entity.components.remove(CarComponent.self)
        entity.components.remove(LaneFollowComponent.self)
        entity.components.remove(RaceTrackComponent.self)
        entity.components.remove(DebrisComponent.self)
        if entity.components.has(ModelComponent.self) {
            entity.components.set(SpatialRaceDisplayComponent())
        }
        for child in entity.children { stripSimulation(from: child) }
    }
}
#endif
