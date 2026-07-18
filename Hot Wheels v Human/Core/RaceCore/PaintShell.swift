//
//  PaintShell.swift
//  Hot Wheels v Human
//
//  The paint shell (CUSTOMIZATION-GRAPHICS.md): a copy of the body mesh,
//  inflated along smoothed vertex normals, with planar side-projection UVs
//  computed in code. One RGBA overlay texture (livery + stickers + drawing)
//  alpha-blends over the tinted base model. The Kenney palette-atlas UVs
//  are useless for decals — this shell replaces them.
//

import CoreGraphics
import RealityKit
import simd

/// Pure geometry helpers — unit-tested.
nonisolated enum ShellGeometry {

    /// Planar side-projection: u = normalized z (car length), v = normalized y
    /// (height). x is ignored → both sides mirror the same texture.
    static func projectUV(_ p: SIMD3<Float>, boundsMin: SIMD3<Float>,
                          boundsMax: SIMD3<Float>) -> SIMD2<Float> {
        let size = boundsMax - boundsMin
        let u = size.z > 0 ? (p.z - boundsMin.z) / size.z : 0.5
        let v = size.y > 0 ? (p.y - boundsMin.y) / size.y : 0.5
        return [u, v]
    }

    /// Kenney meshes are flat-shaded: co-located vertices carry different
    /// normals, so naive inflation cracks at every hard edge. Weld by
    /// position and average so the shell stays watertight.
    static func smoothedNormals(positions: [SIMD3<Float>],
                                normals: [SIMD3<Float>]) -> [SIMD3<Float>] {
        var sums: [SIMD3<Float>: SIMD3<Float>] = [:]
        for (p, n) in zip(positions, normals) {
            sums[p, default: .zero] += n
        }
        return positions.map { p in
            let sum = sums[p] ?? .zero
            let length = simd_length(sum)
            return length > 0 ? sum / length : SIMD3<Float>(0, 1, 0)
        }
    }

    static func inflate(positions: [SIMD3<Float>], normals: [SIMD3<Float>],
                        offset: Float) -> [SIMD3<Float>] {
        zip(positions, smoothedNormals(positions: positions, normals: normals))
            .map { $0 + $1 * offset }
    }

    /// Stickers live on the side panels: above ~v 0.55 the side projection
    /// smears them across the roof, so stamps clamp into this band (taps on
    /// the roof still stick — they just land at the top of the side).
    static func clampStickerUV(_ uv: SIMD2<Float>) -> SIMD2<Float> {
        [min(max(uv.x, 0.04), 0.96), min(max(uv.y, 0.08), 0.55)]
    }
}

/// Screen-point → world ray for a PerspectiveCamera (raycast stamping).
/// Pure math — unit-tested.
nonisolated enum CameraRay {
    /// `point` in view coords (origin top-left), vertical `fovDegrees`.
    static func direction(point: CGPoint, viewSize: CGSize, fovDegrees: Float,
                          cameraTransform: simd_float4x4) -> SIMD3<Float> {
        let tanHalf = tan(fovDegrees * .pi / 360)
        let aspect = Float(viewSize.width / viewSize.height)
        let ndcX = Float(point.x / viewSize.width) * 2 - 1
        let ndcY = 1 - Float(point.y / viewSize.height) * 2
        // Camera space: +x right, +y up, looks down -z.
        let local = SIMD3<Float>(ndcX * tanHalf * aspect, ndcY * tanHalf, -1)
        let rotated = simd_float3x3(
            SIMD3(cameraTransform.columns.0.x, cameraTransform.columns.0.y, cameraTransform.columns.0.z),
            SIMD3(cameraTransform.columns.1.x, cameraTransform.columns.1.y, cameraTransform.columns.1.z),
            SIMD3(cameraTransform.columns.2.x, cameraTransform.columns.2.y, cameraTransform.columns.2.z)
        ) * local
        return simd_normalize(rotated)
    }
}

@MainActor
enum PaintShell {

    /// Inflation as a fraction of the body's largest extent (~1–2 mm at toy
    /// scale, but robust to model-space units).
    static let inflationRatio: Float = 0.012

    /// Build the shell mesh for a body ModelEntity: same topology, inflated,
    /// with side-projection UVs. Returns nil for meshes without normals.
    static func makeShellMesh(from mesh: MeshResource) -> MeshResource? {
        var contents = mesh.contents
        let bounds = mesh.bounds
        let offset = simd_reduce_max(bounds.max - bounds.min) * inflationRatio

        var models: [MeshResource.Model] = []
        for var model in contents.models {
            var parts: [MeshResource.Part] = []
            for var part in model.parts {
                let positions = part.positions.elements
                guard let normals = part.normals?.elements,
                      normals.count == positions.count else { return nil }
                let inflated = ShellGeometry.inflate(
                    positions: positions, normals: normals, offset: offset)
                part.positions = MeshBuffers.Positions(inflated)
                part.textureCoordinates = MeshBuffers.TextureCoordinates(
                    positions.map {
                        ShellGeometry.projectUV($0, boundsMin: bounds.min,
                                                boundsMax: bounds.max)
                    })
                parts.append(part)
            }
            model.parts = MeshPartCollection(parts)
            models.append(model)
        }
        contents.models = MeshModelCollection(models)
        return try? MeshResource.generate(from: contents)
    }

    /// The body is the biggest painted mesh that isn't a wheel.
    static func bodyEntity(of visual: Entity) -> Entity? {
        visual.descendantsAndSelf()
            .filter { $0.components.has(ModelComponent.self)
                && $0.name != "paint-shell"
                && CarPaintSlot.slot(forPartName: $0.name) == CarPaintSlot.body }
            .max { a, b in
                let ea = a.visualBounds(relativeTo: a).extents
                let eb = b.visualBounds(relativeTo: b).extents
                return ea.x * ea.y * ea.z < eb.x * eb.y * eb.z
            }
    }

    /// Body length / height — how much the side-projection stretches u
    /// relative to v (sticker aspect correction).
    static func bodyAspect(of visual: Entity) -> CGFloat {
        guard let body = bodyEntity(of: visual),
              let mesh = body.components[ModelComponent.self]?.mesh else { return 2 }
        let size = mesh.bounds.max - mesh.bounds.min
        return size.y > 0.001 ? CGFloat(size.z / size.y) : 2
    }

    /// Attach (or refresh) the overlay shell on a painted car visual.
    /// No overlay content → removes any existing shell. When the shell
    /// already exists only the texture is swapped (fast path for live edits).
    static func apply(overlay: CGImage?, to visual: Entity) async {
        guard let body = bodyEntity(of: visual) else { return }
        let existing = body.children.first { $0.name == "paint-shell" }
        guard let overlay else {
            existing?.removeFromParent()
            return
        }
        guard let texture = try? await TextureResource(
            image: overlay, options: .init(semantic: .color)) else { return }

        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(texture: .init(texture))
        material.roughness = 0.5
        material.metallic = 0.0
        material.blending = .transparent(opacity: 1.0)
        material.opacityThreshold = 0.0

        if let shell = existing as? ModelEntity {
            shell.model?.materials = [material]
            return
        }
        guard let bodyModel = body.components[ModelComponent.self],
              let shellMesh = makeShellMesh(from: bodyModel.mesh) else { return }
        let shell = ModelEntity(mesh: shellMesh, materials: [material])
        shell.name = "paint-shell"
        body.addChild(shell)
    }
}
