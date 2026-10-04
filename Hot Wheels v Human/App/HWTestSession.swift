import Foundation

/// Debug native QA uses a private store and preference suite. Shipping launches
/// never accept these arguments or change their storage/service behavior.
nonisolated enum HWTestSession {
    static let identifier: String? = {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "-HWTestSession"), args.indices.contains(index + 1),
           let id = UUID(uuidString: args[index + 1]) { return id.uuidString }
        if ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.environment["XCInjectBundleInto"] != nil {
            return "unit-host-\(UUID().uuidString)"
        }
        #endif
        return nil
    }()
    static var isActive: Bool { identifier != nil }
    static var isUnitHost: Bool { identifier?.hasPrefix("unit-host-") == true }
    static var directory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("HWvH-QA")
            .appendingPathComponent(identifier ?? "unused", isDirectory: true)
    }
    @MainActor static var defaults: UserDefaults {
        guard let identifier else { return .standard }
        return UserDefaults(suiteName: "HWvH.QA.\(identifier)")!
    }
}
