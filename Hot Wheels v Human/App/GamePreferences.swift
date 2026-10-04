import Foundation
import Observation
import SwiftUI

@MainActor @Observable
final class GamePreferences {
    static let shared = GamePreferences(defaults: HWTestSession.defaults)
    private let defaults: UserDefaults
    var animationsEnabled: Bool { didSet { defaults.set(animationsEnabled, forKey: "game.animations") } }
    var hapticsEnabled: Bool { didSet { defaults.set(hapticsEnabled, forKey: "game.haptics") } }

    init(defaults: UserDefaults) {
        self.defaults = defaults
        animationsEnabled = Self.savedBool("game.animations", in: defaults, fallback: true)
        hapticsEnabled = Self.savedBool("game.haptics", in: defaults, fallback: true)
    }
    static func savedBool(_ key: String, in defaults: UserDefaults, fallback: Bool) -> Bool {
        defaults.object(forKey: key) == nil ? fallback : defaults.bool(forKey: key)
    }
    func set<T>(_ value: T, for key: String) { defaults.set(value, forKey: key) }
    func bool(_ key: String, fallback: Bool) -> Bool { Self.savedBool(key, in: defaults, fallback: fallback) }
    func string(_ key: String) -> String? { defaults.string(forKey: key) }
    func double(_ key: String, fallback: Double) -> Double {
        defaults.object(forKey: key) == nil ? fallback : defaults.double(forKey: key)
    }
    var permitsHaptics: Bool { hapticsEnabled && !HWTestSession.isActive }
    func reduceMotion(systemPreference: Bool) -> Bool { systemPreference || !animationsEnabled }
}

/// Read-only OS preference and saved app preference are combined, never written
/// back to the system's accessibility environment.
@MainActor @propertyWrapper struct HWReduceMotion: DynamicProperty {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var preferences = GamePreferences.shared
    var wrappedValue: Bool { preferences.reduceMotion(systemPreference: systemReduceMotion) }
}

struct GamePresentationPolicy: ViewModifier {
    @HWReduceMotion private var reduceMotion
    func body(content: Content) -> some View {
        content
            .transaction { if reduceMotion { $0.animation = nil; $0.disablesAnimations = true } }
            .symbolEffectsRemoved(reduceMotion)
            .onChange(of: reduceMotion, initial: true) { _, value in
                GameEffectsPolicy.shared.motionEnabled = !value
            }
    }
}
