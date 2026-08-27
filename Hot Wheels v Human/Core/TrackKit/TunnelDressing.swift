//
//  TunnelDressing.swift
//  Hot Wheels v Human
//
//  Underground track → a tunnel you can SEE: an arch where the bed dives
//  under the ground, another where it comes back up, and lamps strung
//  along the buried run between them.
//
//  `TunnelPlan` is pure geometry off a solved layout (no RealityKit) so
//  the placement is unit-testable; `TunnelDressing` turns it into
//  entities. Decoration only — nothing here carries collision, so a car
//  that flies off sails straight through an arch.
//

import CoreGraphics
import RealityKit
import simd
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Where the tunnels are, in world space.
nonisolated enum TunnelPlan {

    /// Elevation level the piece hands to the next one.
    static func exitLevel(_ piece: PlacedPiece) -> Int {
        piece.entryLevel + piece.definition.elevationDelta
    }

    /// Below the ground at EITHER end. This is THE definition of
    /// "underground" — the tunnel dressing, the builder's x-ray ground and
    /// (through `moundFootprints`) the arena's dirt all ask this one
    /// question, so they can't drift apart the way three copies did.
    static func isUnderground(_ piece: PlacedPiece) -> Bool {
        min(piece.entryLevel, exitLevel(piece)) < 0
    }

    /// Below the ground at BOTH ends.
    static func isFullyUnderground(_ piece: PlacedPiece) -> Bool {
        max(piece.entryLevel, exitLevel(piece)) < 0
    }

    /// Ground rects for `ArenaEnvironment.make(tunnels:)` — the pieces the
    /// terrain mounds a hill over.
    ///
    /// FULLY underground, not merely underground: a dive ramp runs from
    /// ground level DOWN, so mounding dirt over it buries the very hole
    /// the car drives into. Leaving the ramps out drops the dome to
    /// exactly zero at the mouth, because the two distances are the same
    /// number by construction — the mouth sits one ramp (0.8 m) back from
    /// the first buried piece's near edge, and `TunnelMound` pads its
    /// radius by 0.8 m past that piece's half-depth.
    static func moundFootprints(in layout: TrackLayout) -> [FootprintRect] {
        layout.pieces.filter(isFullyUnderground).map(\.worldFootprint)
    }

    /// One end of a tunnel: the seam where the bed crosses ground level.
    struct Mouth: Sendable, Equatable {
        var position: SIMD3<Float>
        var yaw: Float
        /// Diving in (true) or climbing back out (false). Same arch either
        /// way — it's here so a caller can name them apart.
        var isEntrance: Bool
        var pieceIndex: Int
        var isGhost: Bool
    }

    /// An arch for every end of every buried run that actually reaches the
    /// surface. A track that STARTS buried (or ends that way) never
    /// crosses the ground there, so it gets no arch — an arch floating in
    /// the dirt reads as a bug, not a tunnel.
    static func mouths(in layout: TrackLayout) -> [Mouth] {
        var mouths: [Mouth] = []
        let pieces = layout.pieces
        var i = 0
        while i < pieces.count {
            guard isUnderground(pieces[i]) else { i += 1; continue }
            var j = i
            while j + 1 < pieces.count, isUnderground(pieces[j + 1]) { j += 1 }
            let first = pieces[i], last = pieces[j]
            if first.entryLevel >= 0 {
                mouths.append(Mouth(
                    position: first.entryPosition, yaw: first.entryYaw,
                    isEntrance: true, pieceIndex: first.index,
                    isGhost: first.isGhost))
            }
            if exitLevel(last) >= 0 {
                // The solver's own step, so the arch lands exactly on the
                // seam the next piece starts from.
                mouths.append(Mouth(
                    position: last.entryPosition
                        + rotated(last.definition.exitOffset, by: last.entryYaw),
                    yaw: last.entryYaw + last.definition.headingChange,
                    isEntrance: false, pieceIndex: last.index,
                    isGhost: last.isGhost))
            }
            i = j + 1
        }
        return mouths
    }

    /// A lamp on the tunnel wall, with the track frame at that point so
    /// its pool of light can lie ON the bed rather than float
    /// horizontally through a pitched one.
    struct Lamp: Sendable, Equatable {
        var position: SIMD3<Float>
        var forward: SIMD3<Float>
        var up: SIMD3<Float>
        /// Which wall this one is on: −1 right, +1 left. They alternate.
        var side: Float
        var isGhost: Bool
    }

    /// Lamps every `RaceTuning.tunnelLampSpacing` of arc length down each
    /// buried run, set `tunnelLampHeight` up and `tunnelLampSideOffset`
    /// out, alternating walls.
    static func lamps(in layout: TrackLayout) -> [Lamp] {
        let lanes = layout.lanes
        guard lanes.center.count > 1,
              lanes.pieceStartIndices.count == layout.pieces.count else { return [] }
        var lamps: [Lamp] = []
        // Primed, so the first step into a tunnel lights immediately —
        // the lamp nearest the mouth is the one that sells the effect.
        var travelled = RaceTuning.tunnelLampSpacing
        var previous = -2
        for (index, piece) in layout.pieces.enumerated() where isUnderground(piece) {
            // A separate tunnel elsewhere on the track starts its own count.
            if index != previous + 1 { travelled = RaceTuning.tunnelLampSpacing }
            previous = index
            let start = lanes.pieceStartIndices[index]
            let end = index + 1 < lanes.pieceStartIndices.count
                ? lanes.pieceStartIndices[index + 1] : lanes.center.count - 1
            for j in start..<min(end, lanes.center.count - 1) {
                // A portal gap is a teleport, not track: no lamp hangs in
                // it, and the spacing starts again on the far side.
                if lanes.teleports.contains(j) {
                    travelled = RaceTuning.tunnelLampSpacing
                    continue
                }
                travelled += simd_distance(lanes.center[j], lanes.center[j + 1])
                guard travelled >= RaceTuning.tunnelLampSpacing else { continue }
                // Only where the whole lamp fits under the ground. A dive
                // ramp counts as underground the moment its far end dips,
                // but its near half is still at the surface — lamps there
                // stand up out of the field like mushrooms.
                guard lanes.center[j].y + RaceTuning.tunnelLampHeight <= 0
                else { continue }
                let step = lanes.center[j + 1] - lanes.center[j]
                guard simd_length(step) > 1e-5 else { continue }
                let forward = simd_normalize(step)
                // The rail follower's own frame: up is cross(tangent,
                // lateral), orthogonalised against the tangent.
                var up = simd_cross(forward, lanes.laterals[j])
                up -= forward * simd_dot(up, forward)
                guard simd_length(up) > 1e-4 else { continue }
                up = simd_normalize(up)
                travelled = 0
                // Alternate walls, so a run reads as a lit corridor
                // rather than a single dotted line.
                let side: Float = lamps.count.isMultiple(of: 2) ? 1 : -1
                let lateral = simd_normalize(simd_cross(up, forward)) * -side
                lamps.append(Lamp(
                    position: lanes.center[j]
                        + up * RaceTuning.tunnelLampHeight
                        + lateral * RaceTuning.tunnelLampSideOffset,
                    forward: forward, up: up, side: side, isGhost: piece.isGhost))
            }
        }
        return lamps
    }
}

/// The tunnel, as entities. Every one is named `tunnel-…` and carries
/// `TrackVisualComponent`, so the arena's show/hide switch fades a
/// tunnel with its piece and groundless worlds can strip it by prefix.
@MainActor
enum TunnelDressing {

    // Arch dimensions, metres. Sized off the 0.4 m wide bed: 0.28 inner
    // radius clears the monster truck with room to spare. Purely
    // cosmetic, so they live here rather than in RaceTuning — the same
    // rule as `TrackSpawner.legPlant` and ArenaEnvironment's ground/sky
    // numbers.
    private static let archInnerRadius: Float = 0.28
    private static let archThickness: Float = 0.06
    private static let archDepth: Float = 0.10
    private static let archSegments = 9
    private static let bulbRadius: Float = 0.025

    /// Arch + lamp entities for `layout`, ready to hang off the track
    /// root as DIRECT children (which is where `TrackSpawner.setOpacity`
    /// looks for `TrackVisualComponent`).
    static func spawn(layout: TrackLayout) async -> [Entity] {
        let mouths = TunnelPlan.mouths(in: layout)
        let lamps = TunnelPlan.lamps(in: layout)
        guard !mouths.isEmpty || !lamps.isEmpty else { return [] }

        var entities: [Entity] = []
        if !mouths.isEmpty {
            // One mesh and one material for every stone of every arch.
            let radius = archInnerRadius + archThickness / 2
            let segment = MeshResource.generateBox(
                size: [archThickness,
                       // 15% overlap hides the facets between stones.
                       .pi * radius / Float(archSegments) * 1.15,
                       archDepth],
                cornerRadius: 0.008)
            let stone = archMaterial()
            for mouth in mouths {
                entities.append(arch(at: mouth, mesh: segment, material: stone,
                                     radius: radius))
            }
        }
        if !lamps.isEmpty {
            let bulb = MeshResource.generateSphere(radius: bulbRadius)
            let bulbMaterial = UnlitMaterial(color: .init(
                red: 1, green: 0.87, blue: 0.55, alpha: 1))
            let pool = MeshResource.generatePlane(
                width: RaceTuning.tunnelLampGlowRadius * 2,
                depth: RaceTuning.tunnelLampGlowRadius * 2)
            let poolMaterial = await glowMaterial()
            for (n, lamp) in lamps.enumerated() {
                entities.append(self.lamp(lamp, index: n, bulb: bulb,
                                          bulbMaterial: bulbMaterial,
                                          pool: pool, poolMaterial: poolMaterial))
            }
        }
        return entities
    }

    /// A ring of stones swept over a semicircle springing from the bed —
    /// the hole in the hillside. Its plane is perpendicular to travel:
    /// built in the traversal frame (across = X, up = Y, thin along the
    /// +Z direction of travel), then yawed into place.
    private static func arch(at mouth: TunnelPlan.Mouth, mesh: MeshResource,
                             material: PhysicallyBasedMaterial,
                             radius: Float) -> Entity {
        let arch = Entity()
        arch.name = "tunnel-mouth-\(mouth.pieceIndex)-\(mouth.isEntrance ? "in" : "out")"
        arch.position = mouth.position
        // Spring from the DRAWN bed, which sits `bedSurfaceHeight` over
        // the connect point (the same residual cars add to ride height).
        arch.position.y += RaceTuning.bedSurfaceHeight
        arch.orientation = simd_quatf(angle: mouth.yaw, axis: [0, 1, 0])
        for k in 0..<archSegments {
            // Half-step in, so the two springing stones sit ON the ground
            // instead of half under it.
            let angle = .pi * (Float(k) + 0.5) / Float(archSegments)
            let stone = ModelEntity(mesh: mesh, materials: [material])
            stone.position = [radius * cos(angle), radius * sin(angle), 0]
            // Rotating by the same angle about +Z carries the stone's own
            // X (its thickness) onto the radius, so the ring reads as
            // voussoirs rather than a fan of loose bricks.
            stone.orientation = simd_quatf(angle: angle, axis: [0, 0, 1])
            arch.addChild(stone)
        }
        arch.components.set(TrackVisualComponent(isGhost: mouth.isGhost))
        return arch
    }

    /// A warm bulb over the bed with a soft pool of light under it. The
    /// pool is the lighting: RealityKit caps a scene at eight dynamic
    /// lights and the arena already spends one on its key light, so a
    /// tunnel of real point lights isn't on the table. An unlit bulb and
    /// a gradient decal cost nothing and read correctly at any length.
    private static func lamp(_ lamp: TunnelPlan.Lamp, index: Int,
                             bulb: MeshResource, bulbMaterial: UnlitMaterial,
                             pool: MeshResource,
                             poolMaterial: UnlitMaterial) -> Entity {
        let entity = Entity()
        entity.name = "tunnel-lamp-\(index)"
        entity.position = lamp.position
        entity.addChild(ModelEntity(mesh: bulb, materials: [bulbMaterial]))

        let light = ModelEntity(mesh: pool, materials: [poolMaterial])
        let right = simd_normalize(simd_cross(lamp.up, lamp.forward))
        // Down onto the bed (just clear of it, so it can't z-fight) and
        // back IN to the lane — the lamp is out on the wall, but the pool
        // it throws belongs on the track the car drives.
        light.position = -lamp.up
            * (RaceTuning.tunnelLampHeight - RaceTuning.bedSurfaceHeight - 0.004)
            + right * lamp.side * RaceTuning.tunnelLampSideOffset
        // Lie the decal IN the track frame — a horizontal quad cuts
        // through a pitched bed on the way down a hill.
        light.orientation = simd_quatf(simd_float3x3(
            columns: (right, lamp.up, lamp.forward)))
        entity.addChild(light)

        entity.components.set(TrackVisualComponent(isGhost: lamp.isGhost))
        return entity
    }

    private static func archMaterial() -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: .init(red: 0.60, green: 0.58, blue: 0.56, alpha: 1))
        material.roughness = 0.9
        material.metallic = 0.0
        return material
    }

    /// `SceneryPlacer`'s radial glow, drawn once, unlit so it reads as
    /// light rather than catching the scene's key light.
    ///
    /// CUT OUT, not blended — and that difference is the whole reason
    /// this isn't a copy of the nebula recipe. A blended surface doesn't
    /// write depth, so it sorts by guesswork against the OTHER
    /// see-through things in a race: the x-ray terrain and the sky dome.
    /// Blended pools showed up as yellow blobs floating over the hills
    /// and the sky, because a lamp on the far side of the track drew on
    /// top of the world in front of it. Alpha-testing writes depth, so
    /// each pool is occluded by whatever is actually nearer.
    ///
    /// The threshold is where the gradient's alpha is cut: 0.15 lands the
    /// edge at ~0.76 of the quad, so a `tunnelLampGlowRadius` pool washes
    /// about the width of the bed.
    private static func glowMaterial() async -> UnlitMaterial {
        var material = UnlitMaterial()
        if let image = SpaceStuff.glowImage(red: 1, green: 0.84, blue: 0.5),
           let texture = try? await TextureResource(
               image: image, options: .init(semantic: .color)) {
            material.color = .init(texture: .init(texture))
        }
        material.opacityThreshold = 0.15
        return material
    }
}
