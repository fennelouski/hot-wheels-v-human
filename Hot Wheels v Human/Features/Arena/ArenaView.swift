//
//  ArenaView.swift
//  Hot Wheels v Human
//
//  Phase 1: renders a solved track in 3D with a slow orbit camera so the
//  whole layout is visible. Phase 2 adds cars, physics systems, and the
//  chase CameraSystem; Phase 3 hosts this on the TV.
//

import SwiftUI
import RealityKit

struct ArenaView: View {
    let blueprint: TrackBlueprint

    @State private var orbit: EventSubscription?
    @State private var spawnError: String?

    var body: some View {
        ZStack {
            RealityView { content in
                content.camera = .virtual

                let layout = TrackLayoutSolver.solve(blueprint)
                let track: Entity
                do {
                    track = try await TrackSpawner.spawn(layout: layout)
                } catch {
                    spawnError = "\(error)"
                    return
                }
                content.add(track)

                // Soft ground just under the bed so pieces don't float in void.
                let ground = ModelEntity(
                    mesh: .generatePlane(width: 12, depth: 12),
                    materials: [SimpleMaterial(color: .init(red: 0.16, green: 0.32, blue: 0.18, alpha: 1), isMetallic: false)])
                ground.position.y = -0.03
                content.add(ground)

                let light = DirectionalLight()
                light.light.intensity = 5000
                light.look(at: .zero, from: [1, 3, 2], relativeTo: nil)
                content.add(light)

                // Frame the track: orbit its center at a radius that fits it.
                let bounds = track.visualBounds(relativeTo: nil)
                let radius = max(bounds.boundingRadius * 1.9, 1.5)
                let pivot = Entity()
                pivot.position = bounds.center
                content.add(pivot)
                let camera = PerspectiveCamera()
                pivot.addChild(camera)
                camera.look(at: .zero, from: [0, radius * 0.7, -radius], relativeTo: pivot)

                orbit = content.subscribe(to: SceneEvents.Update.self) { event in
                    pivot.transform.rotation *= simd_quatf(
                        angle: Float(event.deltaTime) * 0.3, axis: [0, 1, 0])
                }
            }
            if let spawnError {
                Text("Track build hiccup: \(spawnError)")
                    .font(.title2).padding()
            }
        }
        .background(Color(red: 0.09, green: 0.10, blue: 0.16))
    }
}

#Preview {
    ArenaView(blueprint: .demo)
}
