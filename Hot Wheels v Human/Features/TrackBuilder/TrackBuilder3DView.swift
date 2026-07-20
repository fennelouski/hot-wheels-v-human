//
//  TrackBuilder3DView.swift
//  Hot Wheels v Human
//
//  Live 3D view of the track being built: the real USDZ pieces via
//  TrackSpawner inside the day-theme arena world. One-finger drag orbits,
//  pinch zooms. The camera always aims at the track's center and the
//  distance auto-fits the footprint (zoom is a multiplier on top), so the
//  frame keeps up as pieces snap on and nobody gets lost.
//

import RealityKit
import SwiftUI
import simd

struct TrackBuilder3DView: View {
    let model: TrackBuilderModel

    @State private var azimuth: Float = 2.5
    @State private var elevation: Float = 0.55
    /// Pinch multiplier over the auto-fit distance — relative, so the
    /// track keeps fitting as it grows even after the kid has zoomed.
    @State private var zoom: Float = 1
    @State private var dragStart: SIMD2<Float>?   // (azimuth, elevation) at touch-down
    @State private var zoomStart: Float?

    var body: some View {
        // Gestures don't exist on tvOS; the builder only runs on iPad,
        // the TV merely compiles this file (same split as CarTurntableView).
        #if os(tvOS)
        realityView
        #else
        realityView
            .gesture(DragGesture(minimumDistance: 4)
                .onChanged { value in
                    let start = dragStart ?? SIMD2(azimuth, elevation)
                    dragStart = start
                    azimuth = start.x - Float(value.translation.width) * 0.008
                    elevation = min(1.4, max(0.1,
                        start.y + Float(value.translation.height) * 0.008))
                }
                .onEnded { _ in dragStart = nil })
            .simultaneousGesture(MagnifyGesture()
                .onChanged { value in
                    let start = zoomStart ?? zoom
                    zoomStart = start
                    zoom = min(3, max(0.25, start / Float(value.magnification)))
                }
                .onEnded { _ in zoomStart = nil })
        #endif
    }

    private var realityView: some View {
        RealityView { content in
            content.camera = .virtual

            let root = Entity()
            root.name = "builder-root"
            content.add(root)

            let light = DirectionalLight()
            light.light.intensity = 4000
            light.look(at: .zero, from: [1, 3, 2], relativeTo: nil)
            root.addChild(light)

            // Track holder; its name is the respawn dedupe key (see update).
            let holder = Entity()
            holder.name = "track-empty"
            root.addChild(holder)

            let camera = PerspectiveCamera()
            camera.name = "builder-camera"
            content.add(camera)

            // Fixed day theme (nil id), no props (nil footprint) — sky +
            // ground so the track sits in a place, not a void. On the
            // calling task: Task.detached inside RealityView closures
            // silently never resumes.
            Task { @MainActor in
                root.addChild(await ArenaEnvironment.make(for: nil, around: nil))
            }
        } update: { content in
            guard let root = content.entities.first(where: { $0.name == "builder-root" }),
                  let camera = content.entities.first(where: { $0.name == "builder-camera" })
                      as? PerspectiveCamera
            else { return }

            let layout = model.layout   // reads model.types → reruns on every edit

            // Respawn on change, ArenaView-style: holder's name is the
            // dedupe key, "building-" while the async spawn is in flight.
            let key = "track-\(model.types.hashValue)"
            if let holder = root.children.first(where: {
                    $0.name.hasPrefix("track-") || $0.name.hasPrefix("building-") }),
               holder.name != key, holder.name != "building-\(key)" {
                holder.name = "building-\(key)"
                Task { @MainActor in
                    let track = try? await TrackSpawner.spawn(layout: layout)
                    holder.children.removeAll()
                    if let track { holder.addChild(track) }
                    holder.name = key
                }
            }

            // Aim at the track's center, auto-fit the distance, apply the
            // kid's orbit + zoom on top.
            let rects = layout.pieces.map(\.worldFootprint)
            let minX = rects.map(\.minX).min() ?? 0
            let maxX = rects.map(\.maxX).max() ?? 0
            let minZ = rects.map(\.minZ).min() ?? 0
            let maxZ = rects.map(\.maxZ).max() ?? 0
            let maxY = layout.lanes.center.map(\.y).max() ?? 0
            let span = max(maxX - minX, maxZ - minZ, maxY * 2)
            // Aim near bed level (0.35·maxY, not the midpoint) — a target
            // hovering over the track pushes it into the bottom of the frame.
            let target = SIMD3<Float>((minX + maxX) / 2, maxY * 0.35,
                                      (minZ + maxZ) / 2)
            let distance = max(1.2, span) * zoom
            let offset = SIMD3<Float>(sin(azimuth) * cos(elevation),
                                      sin(elevation),
                                      cos(azimuth) * cos(elevation)) * distance
            camera.look(at: target, from: target + offset, relativeTo: nil)
        }
    }
}

#Preview {
    TrackBuilder3DView(model: TrackBuilderModel())
}
