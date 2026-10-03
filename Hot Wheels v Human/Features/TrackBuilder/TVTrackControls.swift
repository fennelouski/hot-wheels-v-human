import Foundation
import Observation
import simd

/// Camera and ground-cursor input for a remote, independent of focus and
/// RealityKit. The iPad continues to own its touch camera inside the view.
@MainActor
@Observable
final class TVTrackControls {
    enum Direction { case left, right, forward, backward }

    private(set) var azimuth: Float = 2.5
    private(set) var elevation: Float = 0.55
    private(set) var zoom: Float = 1
    private(set) var cursor = SIMD2<Float>.zero
    private(set) var pan = SIMD3<Float>.zero
    var fineStep = false
    var selectedPiece: Int?

    /// Thirty meters of scenery space around the whole current track.
    /// Absolute ±30 bounds would make distant exits on long tracks
    /// unreachable, even though the touch canvas can place them.
    private let surroundingSpace: Float = 30

    func positionCursor(at point: SIMD2<Float>, layout: TrackLayout) {
        guard point.x.isFinite, point.y.isFinite else { return }
        let rects = layout.pieces.map(\.worldFootprint)
        let minX = (rects.map(\.minX).min() ?? 0) - surroundingSpace
        let maxX = (rects.map(\.maxX).max() ?? 0) + surroundingSpace
        let minZ = (rects.map(\.minZ).min() ?? 0) - surroundingSpace
        let maxZ = (rects.map(\.maxZ).max() ?? 0) + surroundingSpace
        cursor = SIMD2(min(maxX, max(minX, point.x)), min(maxZ, max(minZ, point.y)))
        aimAtCursor(layout: layout)
    }

    /// Move in the direction shown by the current camera, so "Left"
    /// continues to mean left after orbiting the scene.
    func nudge(_ direction: Direction, layout: TrackLayout) {
        let right = SIMD2<Float>(cos(azimuth), -sin(azimuth))
        let forward = SIMD2<Float>(-sin(azimuth), -cos(azimuth))
        let delta: SIMD2<Float>
        switch direction {
        case .left: delta = -right
        case .right: delta = right
        case .forward: delta = forward
        case .backward: delta = -forward
        }
        positionCursor(at: cursor + delta * (fineStep ? 0.35 : 0.7), layout: layout)
    }

    func orbitLeft() { azimuth -= .pi / 8 }
    func orbitRight() { azimuth += .pi / 8 }
    func tiltUp() { elevation = min(1.4, elevation + 0.15) }
    func tiltDown() { elevation = max(0.1, elevation - 0.15) }
    func zoomIn() { zoom = max(0.25, zoom / 1.25) }
    func zoomOut() { zoom = min(6, zoom * 1.25) }

    func panCamera(_ direction: Direction) {
        let right = SIMD2<Float>(cos(azimuth), -sin(azimuth))
        let forward = SIMD2<Float>(-sin(azimuth), -cos(azimuth))
        let delta: SIMD2<Float>
        switch direction {
        case .left: delta = -right
        case .right: delta = right
        case .forward: delta = forward
        case .backward: delta = -forward
        }
        pan.x = clamp(pan.x + delta.x * 0.7)
        pan.z = clamp(pan.z + delta.y * 0.7)
    }

    func resetCamera() {
        azimuth = 2.5
        elevation = 0.55
        zoom = 1
        pan = .zero
    }

    func aimAtCursor(layout: TrackLayout) {
        let pose = TrackBuilder3DView.cameraPose(layout: layout,
            azimuth: azimuth, elevation: elevation, zoom: zoom)
        pan = SIMD3(cursor.x - pose.target.x, 0, cursor.y - pose.target.z)
    }

    private func clamp(_ value: Float) -> Float {
        min(surroundingSpace, max(-surroundingSpace, value))
    }
}
