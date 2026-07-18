//
//  Hot_Wheels_v_HumanApp.swift
//  Hot Wheels v Human
//

import SwiftUI
import SwiftData

@main
struct Hot_Wheels_v_HumanApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appModel)
        }
        .modelContainer(for: [CarDesignRecord.self, DriverProfileRecord.self,
                              TrackBlueprintRecord.self])
    }
}
