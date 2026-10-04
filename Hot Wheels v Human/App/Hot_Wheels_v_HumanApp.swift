//
//  Hot_Wheels_v_HumanApp.swift
//  Hot Wheels v Human
//

import SwiftUI
import SwiftData

@main
struct Hot_Wheels_v_HumanApp: App {
    @State private var appModel = AppModel()
    private let container: ModelContainer

    init() {
        let schema = Schema([CarDesignRecord.self, DriverProfileRecord.self,
                             TrackBlueprintRecord.self, KidProfileRecord.self,
                             RaceResultRecord.self])
        let configuration: ModelConfiguration
        if HWTestSession.isActive {
            try? FileManager.default.createDirectory(at: HWTestSession.directory, withIntermediateDirectories: true)
            configuration = HWTestSession.isUnitHost
                ? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
                : ModelConfiguration(schema: schema, url: HWTestSession.directory.appendingPathComponent("workshop.store"), cloudKitDatabase: .none)
        } else {
            configuration = ModelConfiguration(schema: schema)
        }
        do { container = try ModelContainer(for: schema, configurations: [configuration]) }
        catch { fatalError("Unable to open the workshop: \(error)") }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if HWTestSession.isUnitHost { Color.clear }
                else { RootView().environment(appModel) }
            }
            .modifier(GamePresentationPolicy())
        }
        .modelContainer(container)
    }
}
