//
//  AssetStore.swift
//  Hot Wheels v Human
//
//  Caching loader for bundled USDZ models. Loads each model once,
//  vends clones. @MainActor (not a plain actor) because RealityKit
//  Entity is MainActor-bound — same isolation guarantee.
//

import RealityKit

@MainActor
final class AssetStore {
    static let shared = AssetStore()

    private var prototypes: [String: Entity] = [:]

    func entity(named name: String) async throws -> Entity {
        if let cached = prototypes[name] {
            return cached.clone(recursive: true)
        }
        let loaded = try await Entity(named: name)
        prototypes[name] = loaded
        return loaded.clone(recursive: true)
    }
}
