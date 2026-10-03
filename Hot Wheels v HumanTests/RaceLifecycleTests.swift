import Foundation
import RealityKit
import Testing
@testable import Hot_Wheels_v_Human

@MainActor
@Suite(.serialized)
struct RaceLifecycleTests {
    private func settle(until condition: @autoclosure () -> Bool) async {
        for _ in 0..<2000 where !condition() { await Task.yield() }
    }

    @Test func stopRejectsQueuedAndFutureControllerInputs() async {
        let transport = LifecycleTransport()
        let coordinator = RaceCoordinator(transport: transport)
        coordinator.start()
        coordinator.start()
        #expect(transport.startCount == 1)
        let player = PlayerInfo(id: UUID(), name: "Couch racer", deviceRole: .iPad)
        transport.emit(.message(.hello(player, protocolVersion: gameProtocolVersion)))
        transport.emit(.message(.reactionCam(playerID: player.id, on: true)))
        await settle(until: coordinator.reactionCamsOn.contains(player.id))
        #expect(coordinator.players.count == 1)

        // This input is queued before stop; a suspended stream consumer must
        // not apply it after the arena has disappeared.
        transport.emit(.message(.trackVisibility(.hideAll)))
        coordinator.stop()
        transport.emit(.message(.hello(
            PlayerInfo(id: UUID(), name: "Late racer", deviceRole: .iPad),
            protocolVersion: gameProtocolVersion)))
        for _ in 0..<100 { await Task.yield() }
        #expect(transport.stopCount == 1)
        #expect(coordinator.transportState == .idle)
        #expect(coordinator.players.isEmpty)
        #expect(coordinator.reactionCamsOn.isEmpty)
        #expect(coordinator.trackVisibility == .hideGhosts)
        #expect(coordinator.session.phase == .lobby)
    }

    @Test func cancelledBuildDoesNotChangeTheSceneOrPhase() async {
        let session = RaceSession()
        let root = Entity()
        let build = Task { @MainActor in
            try await session.start(
                blueprint: TrackBlueprint.presets[0].blueprint,
                entries: [(UUID(), CarDesign.demoPair[0])],
                config: MatchConfig(mode: .test), root: root)
        }
        // The test still owns the main actor, so cancellation precedes the
        // queued build's first instruction. No model loading is required.
        build.cancel()
        switch await build.result {
        case .failure(let error): #expect(error is CancellationError)
        case .success: Issue.record("A cancelled build unexpectedly completed")
        }
        #expect(session.phase == .lobby)
        #expect(session.racers.isEmpty)
        #expect(root.children.isEmpty)
    }

    @Test func closingCountdownRemovesCarsAndCannotStartARaceLater() async throws {
        let session = RaceSession()
        let root = Entity()
        var ticks: [Int] = []
        session.onEvent = { event in
            if case .countdownTick(let value) = event { ticks.append(value) }
        }
        try await session.start(
            blueprint: TrackBlueprint.presets[0].blueprint,
            entries: [(UUID(), CarDesign.demoPair[0])],
            config: MatchConfig(mode: .test), root: root)
        #expect(session.phase == .countdown)
        let cars = session.racers.compactMap(\.entity)
        #expect(!cars.isEmpty)
        #expect(!root.children.isEmpty)
        session.stop()
        let ticksAtStop = ticks
        #expect(cars.allSatisfy { $0.parent == nil })
        #expect(root.children.isEmpty)
        #expect(session.racers.isEmpty)
        // The original countdown was three seconds. Waiting past that point
        // catches a detached countdown re-entering go() after navigation.
        try await Task.sleep(for: .milliseconds(3250))
        #expect(ticks == ticksAtStop)
        #expect(session.phase == .lobby)
        #expect(session.raceClock == 0)
        #expect(!RaceEventBus.shared.raceActive)
    }
}

@MainActor
private final class LifecycleTransport: GameTransport {
    private(set) var state: TransportState = .idle
    let events: AsyncStream<TransportEvent>
    private let continuation: AsyncStream<TransportEvent>.Continuation
    private(set) var startCount = 0
    private(set) var stopCount = 0

    init() { (events, continuation) = AsyncStream.makeStream() }

    func start(role: TransportRole) {
        startCount += 1
        state = .connected
        emit(.stateChanged(.connected))
    }

    func stop() {
        stopCount += 1
        state = .idle
        emit(.stateChanged(.idle))
    }

    func send(_ message: GameMessage, reliably: Bool) {}
    func emit(_ event: TransportEvent) { continuation.yield(event) }
}
