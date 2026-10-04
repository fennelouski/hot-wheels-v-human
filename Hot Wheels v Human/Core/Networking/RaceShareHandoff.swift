import Foundation
import Observation

/// Standalone TV play uses loopback. Only an explicit Share presentation opens
/// the existing encrypted local service; closing it releases the advertiser.
@MainActor @Observable final class RaceShareHandoff {
    private let transport: any GameTransport
    private var task: Task<Void, Never>?
    private(set) var connected = false

    init(transport: (any GameTransport)? = nil) { self.transport = transport ?? MultipeerTransport() }
    func start(payload: RaceSharePayload) {
        guard task == nil, payload.isValid else { return }
        transport.start(role: .host)
        task = Task { [weak self] in
            guard let events = self?.transport.events else { return }
            for await event in events {
                guard !Task.isCancelled, let self else { return }
                switch event {
                case .peerConnected, .message(.hello), .message(.requestRaceShare):
                    connected = true
                    transport.send(.raceShare(payload), reliably: true)
                case .peerDropped: connected = false
                default: break
                }
            }
        }
    }
    func stop() { task?.cancel(); task = nil; connected = false; transport.stop() }
}
