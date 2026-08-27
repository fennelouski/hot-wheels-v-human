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
    /// Build mode: (azimuth, elevation) at touch-down. Decorate mode:
    /// running drag translation (pan applies deltas).
    @State private var dragStart: SIMD2<Float>?
    @State private var zoomStart: Float?
    /// Decorate-mode camera-target offset — pan to reach the whole world.
    @State private var pan: SIMD3<Float> = .zero

    var body: some View {
        // Gestures don't exist on tvOS; the builder only runs on iPad,
        // the TV merely compiles this file (same split as CarTurntableView).
        #if os(tvOS)
        realityView
        #else
        GeometryReader { proxy in
        realityView
            // Decorate mode: tap a placed prop to pick it up, tap the
            // ground to set it down (or to drop a new prop from the
            // palette). Tap-tap moving instead of dragging, so the orbit
            // drag keeps working everywhere. The targeted gesture supplies
            // WHICH entity was hit; the ground point comes from our own
            // camera math (iOS tap values are 2D).
            .gesture(SpatialTapGesture().targetedToAnyEntity()
                .onEnded { value in
                    if let index = SceneryPlacer.itemIndex(of: value.entity) {
                        if model.movingIndex == index {
                            // Second tap on the held item spins it.
                            model.rotatePickedScenery()
                        } else {
                            model.movingIndex = index
                            SoundBank.shared.play("confirm_sparkle")
                        }
                        return
                    }
                    // Build mode: tap a piece to flip it ghost ↔ solid.
                    // Hit-tested against the track's collision, so it picks
                    // the right piece at any elevation and a see-through
                    // ghost is just as tappable as a solid piece.
                    if !model.decorating, model.placingPortalIndex == nil,
                       let piece = TrackSpawner.pieceIndex(of: value.entity) {
                        model.toggleGhost(at: piece)
                        return
                    }
                    guard let spot = groundPoint(tap: value.location,
                                                 size: proxy.size) else { return }
                    if model.placingPortalIndex != nil {
                        // A portal exit is waiting: this tap places it.
                        model.placePortalExit(atX: spot.x, z: spot.z)
                    } else if model.movingIndex != nil {
                        model.moveScenery(atX: spot.x, z: spot.z)
                    } else if model.placingModel != nil {
                        model.placeScenery(atX: spot.x, z: spot.z)
                    }
                })
            .gesture(DragGesture(minimumDistance: 4)
                .onChanged { value in
                    if model.decorating {
                        // Decorate mode: drag PANS across the ground —
                        // you have to reach past the track to build a
                        // town. (Orbit is a build-mode gesture.)
                        let previous = dragStart ?? .zero
                        let deltaX = Float(value.translation.width) - previous.x
                        let deltaY = Float(value.translation.height) - previous.y
                        dragStart = SIMD2(Float(value.translation.width),
                                          Float(value.translation.height))
                        let distance = simd_length(Self.cameraPose(
                            layout: model.layout, azimuth: azimuth,
                            elevation: elevation, zoom: zoom, pan: pan).offset)
                        let scale = distance * 0.0012
                        let right = SIMD3<Float>(cos(azimuth), 0, -sin(azimuth))
                        let forward = SIMD3<Float>(-sin(azimuth), 0, -cos(azimuth))
                        pan -= right * (deltaX * scale)
                        pan += forward * (deltaY * scale)
                        let limit = Float(30)
                        pan.x = min(limit, max(-limit, pan.x))
                        pan.z = min(limit, max(-limit, pan.z))
                    } else {
                        let start = dragStart ?? SIMD2(azimuth, elevation)
                        dragStart = start
                        azimuth = start.x - Float(value.translation.width) * 0.008
                        elevation = min(1.4, max(0.1,
                            start.y + Float(value.translation.height) * 0.008))
                    }
                }
                .onEnded { _ in dragStart = nil })
            .simultaneousGesture(MagnifyGesture()
                .onChanged { value in
                    let start = zoomStart ?? zoom
                    zoomStart = start
                    zoom = min(6, max(0.25, start / Float(value.magnification)))
                }
                .onEnded { _ in zoomStart = nil })
        }
        #endif
    }

    /// Where a tap lands on the ground plane (y = 0): the camera pose is
    /// recomputed exactly as `update` places it, then the tap is cast
    /// through the perspective frustum.
    /// ponytail: assumes the camera's default 60° vertical FOV — a slight
    /// mismatch just lands the prop a touch off the fingertip, and the kid
    /// can move it.
    private func groundPoint(tap: CGPoint, size: CGSize) -> SIMD3<Float>? {
        guard size.width > 0, size.height > 0 else { return nil }
        let (target, offset) = Self.cameraPose(
            layout: model.layout, azimuth: azimuth, elevation: elevation,
            zoom: zoom, pan: pan)
        let camPos = target + offset
        let forward = simd_normalize(target - camPos)
        let right = simd_normalize(simd_cross(forward, SIMD3<Float>(0, 1, 0)))
        let up = simd_cross(right, forward)
        let tanY = tan(Float.pi / 6)     // half of 60°
        let tanX = tanY * Float(size.width / size.height)
        let ndcX = Float(tap.x / size.width) * 2 - 1
        let ndcY = 1 - Float(tap.y / size.height) * 2
        let sideways: SIMD3<Float> = right * (ndcX * tanX)
        let upward: SIMD3<Float> = up * (ndcY * tanY)
        let dir = simd_normalize(forward + sideways + upward)
        guard dir.y < -0.001 else { return nil }   // tapped the sky
        let t = -camPos.y / dir.y
        return camPos + dir * t
    }

    /// The one place the camera's target and offset are derived — `update`
    /// aims the camera with it, `groundPoint` casts taps through it.
    static func cameraPose(layout: TrackLayout, azimuth: Float,
                           elevation: Float, zoom: Float,
                           pan: SIMD3<Float> = .zero)
        -> (target: SIMD3<Float>, offset: SIMD3<Float>) {
        let rects = layout.pieces.map(\.worldFootprint)
        let minX = rects.map(\.minX).min() ?? 0
        let maxX = rects.map(\.maxX).max() ?? 0
        let minZ = rects.map(\.minZ).min() ?? 0
        let maxZ = rects.map(\.maxZ).max() ?? 0
        let maxY = layout.lanes.center.map(\.y).max() ?? 0
        let span = max(maxX - minX, maxZ - minZ, maxY * 2)
        let target = SIMD3<Float>((minX + maxX) / 2, maxY * 0.35,
                                  (minZ + maxZ) / 2) + pan
        let distance = max(1.2, span) * zoom
        let offset = SIMD3<Float>(sin(azimuth) * cos(elevation),
                                  sin(elevation),
                                  cos(azimuth) * cos(elevation)) * distance
        return (target, offset)
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

            // World holder — filled/rebuilt in `update` when the kid picks
            // a world. (Task, not Task.detached: detached inside RealityView
            // closures silently never resumes.)
            let world = Entity()
            world.name = "world-empty"
            root.addChild(world)

            // Hand-placed decorations, rebuilt when the list changes.
            let decor = Entity()
            decor.name = "decor-empty"
            root.addChild(decor)
        } update: { content in
            guard let root = content.entities.first(where: { $0.name == "builder-root" }),
                  let camera = content.entities.first(where: { $0.name == "builder-camera" })
                      as? PerspectiveCamera
            else { return }

            let layout = model.layout   // reads model.types → reruns on every edit

            // Respawn on change, ArenaView-style: holder's name is the
            // dedupe key, "building-" while the async spawn is in flight.
            // Groundless worlds strip the support legs (the track floats),
            // so the picked world is part of the key.
            let floating = RaceTuning.groundlessThemes.contains(
                RaceTuning.resolvedThemeName(model.worldTheme, for: nil))
            let key = "track-\(model.types.hashValue)-\(model.portalExits.hashValue)"
                + "-\(model.ghostIndices.hashValue)-\(floating)"
            if let holder = root.children.first(where: {
                    $0.name.hasPrefix("track-") || $0.name.hasPrefix("building-track-") }),
               holder.name != key, holder.name != "building-\(key)" {
                holder.name = "building-\(key)"
                Task { @MainActor in
                    let track = try? await TrackSpawner.spawn(layout: layout)
                    if let track, floating {
                        for child in Array(track.children)
                        where child.name.hasPrefix("support-")
                            || child.name.hasPrefix("tunnel-") {
                            child.removeFromParent()
                        }
                    }
                    // Ghosts are see-through in the builder, not gone: the
                    // kid has to see what they placed to keep building on it.
                    if let track {
                        TrackSpawner.setOpacity(on: track, ghosts: 0.3)
                        TrackSpawner.makeTappable(track)
                    }
                    holder.children.removeAll()
                    if let track { holder.addChild(track) }
                    holder.name = key
                }
            }

            // Aim at the track's center, auto-fit the distance, apply the
            // kid's orbit + zoom on top.
            let rects = layout.pieces.map(\.worldFootprint)
            // Rebuild the world when the picked theme changes, scattering
            // its buildings/trees around the track as it is right now.
            // ponytail: keyed on theme only — pieces added afterwards can
            // overlap props (no collision, purely visual) until the kid
            // re-taps the world chip; re-key on the track hash if it bugs
            // anyone.
            // Placed decorations respawn on change (same dedupe pattern);
            // the picked-up item is part of the key so it lifts on pickup.
            let decorKey = SceneryPlacer.name(for: model.scenery)
                + "-m\(model.movingIndex ?? -1)"
            if let decor = root.children.first(where: {
                    $0.name.hasPrefix("decor-") || $0.name.hasPrefix("scenery-")
                        || $0.name.hasPrefix("building-scenery-") }),
               decor.name != decorKey, decor.name != "building-\(decorKey)" {
                decor.name = "building-\(decorKey)"
                let items = model.scenery
                let moving = model.movingIndex
                // Placed cars need the world's road grid to drive on —
                // recomputed here because the decor holder rebuilds
                // independently of the world holder.
                var autoStreets = Set<SIMD2<Int32>>()
                if let themeName = model.worldTheme, !model.worldEmpty {
                    let theme = ArenaEnvironment.theme(named: themeName, for: nil)
                    if theme.cityBlocks {
                        autoStreets = ArenaEnvironment.autoStreetCells(
                            around: FootprintRect(
                                minX: rects.map(\.minX).min() ?? -1,
                                minZ: rects.map(\.minZ).min() ?? -1,
                                maxX: rects.map(\.maxX).max() ?? 1,
                                maxZ: rects.map(\.maxZ).max() ?? 1),
                            clearance: theme.clearance)
                    }
                }
                let streets = autoStreets
                Task { @MainActor in
                    let spawned = await SceneryPlacer.spawn(
                        items, tappable: true, highlight: moving,
                        autoStreets: streets)
                    decor.children.removeAll()
                    decor.addChild(spawned)
                    decor.name = decorKey
                }
            }

            let worldKey = "world-\(model.worldTheme ?? "auto")\(model.worldEmpty ? "-empty" : "")"
            if let world = root.children.first(where: {
                    $0.name.hasPrefix("world-") || $0.name.hasPrefix("building-world-") }),
               world.name != worldKey, world.name != "building-\(worldKey)" {
                world.name = "building-\(worldKey)"
                let footprint = FootprintRect(
                    minX: rects.map(\.minX).min() ?? -1,
                    minZ: rects.map(\.minZ).min() ?? -1,
                    maxX: rects.map(\.maxX).max() ?? 1,
                    maxZ: rects.map(\.maxZ).max() ?? 1)
                let theme = model.worldTheme
                let empty = model.worldEmpty
                Task { @MainActor in
                    let env = await ArenaEnvironment.make(
                        for: nil, theme: theme, empty: empty,
                        around: theme == nil ? nil : footprint)
                    world.children.removeAll()
                    world.addChild(env)
                    world.name = worldKey
                }
            }
            // Digging? See through the dirt: force the terrain to the
            // faded opacity while the track has underground pieces, so
            // the kid never has to fight the ground while building.
            // (No cars here — GroundFadeSystem's own trigger never fires.)
            if let terrain = root.children
                .first(where: { $0.name.hasPrefix("world-") })?
                .findEntity(named: "terrain"),
               var fade = terrain.components[GroundFadeComponent.self] {
                fade.forced = model.isDigging ? GroundFadeSystem.fadedOpacity : nil
                terrain.components.set(fade)
            }

            // Aim near bed level (0.35·maxY inside cameraPose) — a target
            // hovering over the track pushes it into the bottom of the frame.
            let (target, offset) = Self.cameraPose(
                layout: layout, azimuth: azimuth, elevation: elevation,
                zoom: zoom, pan: pan)
            camera.look(at: target, from: target + offset, relativeTo: nil)
        }
    }
}

#Preview {
    TrackBuilder3DView(model: TrackBuilderModel())
}
