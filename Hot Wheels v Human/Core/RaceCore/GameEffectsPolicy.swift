import Foundation

/// RealityKit decorative systems run outside the main actor. Gameplay physics,
/// boost holds, collision and timing never consult this presentation-only flag.
nonisolated final class GameEffectsPolicy: @unchecked Sendable {
    static let shared = GameEffectsPolicy()
    private let lock = NSLock()
    private var enabled = true
    var motionEnabled: Bool {
        get { lock.lock(); defer { lock.unlock() }; return enabled }
        set { lock.lock(); defer { lock.unlock() }; enabled = newValue }
    }
}
