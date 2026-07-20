//
//  TurntableOrbit.swift
//  Hot Wheels v Human
//
//  Drag to spin it, pinch to zoom. Shared by the car turntable and the
//  character preview so a model handles the same wherever a kid grabs one.
//

import CoreGraphics
import RealityKit
import simd

/// Where the camera sits relative to the framing its preview was built with.
/// Zero yaw/pitch at 1× zoom reproduces that framing exactly, so a preview
/// nobody touches looks exactly as it did before it could be touched.
struct TurntableOrbit: Equatable {
    private(set) var yaw: Float = 0
    private(set) var pitch: Float = 0
    private(set) var zoom: Float = 1
    /// Set the moment a kid grabs the model, and never cleared. The idle
    /// spin/sway stops for good then — an auto-rotating model fights every
    /// attempt to hold it still and look at one particular side.
    private(set) var grabbed = false

    private var dragStart: SIMD2<Float>?
    private var zoomStart: Float?

    /// Radians per point dragged: a swipe across the iPad is a bit over one
    /// full turn, so "spin it right round" is one flick.
    static let dragSensitivity: Float = 0.012
    /// Nearer the pole than this and `look(at:from:)` runs out of up vector
    /// and the model flips over.
    static let pitchLimit: Float = 1.2          // ~69°
    static let zoomRange: ClosedRange<Float> = 0.4...2.5

    /// `translation` is cumulative from the start of the gesture, so the
    /// angle at grab time is the anchor — tracking deltas instead drifts.
    mutating func drag(_ translation: CGSize, ended: Bool) {
        let start = dragStart ?? SIMD2(yaw, pitch)
        dragStart = start
        grabbed = true
        // Drag right and the model turns right to follow the finger, which
        // means the camera swings the other way. Drag down and the camera
        // rises, so you're looking at the roof — same as every 3D viewer.
        yaw = start.x - Float(translation.width) * Self.dragSensitivity
        pitch = clampPitch(start.y + Float(translation.height) * Self.dragSensitivity)
        if ended { dragStart = nil }
    }

    mutating func pinch(_ magnification: CGFloat, ended: Bool) {
        let start = zoomStart ?? zoom
        zoomStart = start
        grabbed = true
        // Pinch out = "bring it closer" = less camera distance, so divide.
        let scale = max(Float(magnification), 0.01)
        zoom = min(max(start / scale, Self.zoomRange.lowerBound), Self.zoomRange.upperBound)
        if ended { zoomStart = nil }
    }

    /// Camera position for this orbit, given the framing the view was built
    /// with (`home`, looking at `target`).
    func cameraPosition(target: SIMD3<Float>, home: SIMD3<Float>) -> SIMD3<Float> {
        let offset = home - target
        let distance = length(offset)
        guard distance > 0.0001 else { return home }
        // Read the view's own framing back out as angles, so each preview
        // keeps its hand-tuned starting shot and orbits away from there.
        let baseYaw = atan2(offset.x, offset.z)
        let basePitch = asin(min(max(offset.y / distance, -1), 1))
        let yaw = baseYaw + self.yaw
        let pitch = clampPitch(basePitch + self.pitch)
        let d = distance * zoom
        return target + SIMD3(d * cos(pitch) * sin(yaw),
                              d * sin(pitch),
                              d * cos(pitch) * cos(yaw))
    }

    private func clampPitch(_ value: Float) -> Float {
        min(max(value, -Self.pitchLimit), Self.pitchLimit)
    }
}

/// The camera a preview orbits plus the shot it started from. A reference
/// type on purpose: the gesture writes it and the per-frame Update closure
/// reads it, so dragging never re-renders the SwiftUI view.
@MainActor
final class OrbitRefs {
    weak var camera: PerspectiveCamera?
    /// The previewed entity. Only the car turntable uses it (raycasting
    /// stickers onto the body); the character preview leaves it nil.
    weak var model: Entity?

    var orbit = TurntableOrbit()
    private var target: SIMD3<Float> = .zero
    private var home: SIMD3<Float> = .zero

    /// Record the shot the view framed, so orbiting starts from it.
    func frame(_ camera: PerspectiveCamera, target: SIMD3<Float>, from home: SIMD3<Float>) {
        self.camera = camera
        self.target = target
        self.home = home
        camera.look(at: target, from: home, relativeTo: nil)
    }

    func apply() {
        camera?.look(at: target,
                     from: orbit.cameraPosition(target: target, home: home),
                     relativeTo: nil)
    }
}
