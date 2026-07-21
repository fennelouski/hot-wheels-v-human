//
//  DriverThumbnail.swift
//  Hot Wheels v Human
//
//  Off-screen 3D → still-image renderer for grid avatars.
//
//  Why this contortion exists: a live RealityView per grid tile crashes a
//  real device — RealityKit can't hold several simultaneous scenes inside a
//  recycling LazyVGrid/ScrollView, and aborts in the render thread even with
//  a few (OPEN-THREADS "3D grid avatars"). A single, non-recycled scene is
//  fine (the editor turntable proves it). So this renders each character
//  through ONE transient ARView, one at a time, into a UIImage the grid shows
//  statically. The number of live scenes on a grid stays zero.
//
//  iOS only: ARView (and the snapshot API) don't exist on tvOS, which never
//  shows these workshop grids anyway.
//

#if os(iOS)
import RealityKit
import SwiftUI
import UIKit

@MainActor
@Observable
final class DriverThumbnailStore {
    static let shared = DriverThumbnailStore()

    /// Keyed by appearance signature, so two identical-looking racers share
    /// one render and a colour change re-renders.
    private var cache: [String: UIImage] = [:]
    /// Serial tail: each render waits for the previous, so there is never more
    /// than ONE ARView alive. That single-scene guarantee is the entire reason
    /// this is safe where a grid of live scenes was not.
    private var tail: Task<UIImage?, Never>?

    /// Rendered thumbnail if it's already in hand — lets a tile show 3D
    /// instantly on a re-appear instead of flashing the 2D badge again.
    func cached(_ driver: DriverProfile) -> UIImage? {
        cache[DriverPainter.appearanceSignature(for: driver)]
    }

    /// The thumbnail for `driver`, rendering it if needed. `nil` means the
    /// render failed or isn't possible — the caller keeps the 2D badge, so a
    /// miss is a cosmetic downgrade, never a crash.
    func thumbnail(for driver: DriverProfile, size: CGFloat = 160) async -> UIImage? {
        let key = DriverPainter.appearanceSignature(for: driver)
        if let hit = cache[key] { return hit }

        let previous = tail
        let task = Task { @MainActor () -> UIImage? in
            _ = await previous?.value                    // one render at a time
            if let hit = cache[key] { return hit }
            let image = await Self.snapshot(driver, size: size)
            if let image { cache[key] = image }
            return image
        }
        tail = task
        return await task.value
    }

    /// Renders one driver through a throwaway ARView and grabs a still.
    private static func snapshot(_ driver: DriverProfile, size: CGFloat) async -> UIImage? {
        guard let window = keyWindow() else { return nil }

        let arView = ARView(frame: CGRect(x: 0, y: 0, width: size, height: size),
                            cameraMode: .nonAR,
                            automaticallyConfigureSession: false)
        // Transparent so the character composites over the tile's own circle.
        arView.environment.background = .color(.clear)
        // Parked off-screen but IN the window: an ARView that isn't in a
        // hierarchy never ticks its renderer, and then snapshots come back
        // blank. Off-screen keeps it invisible while still drawing.
        arView.frame.origin = CGPoint(x: -size - 50, y: 0)
        window.addSubview(arView)
        defer { arView.removeFromSuperview() }

        // Same rig and framing as the live turntable (one code path), so the
        // still can't drift from what the editor shows.
        let height = RaceTuning.driverSourceHeight
        let turntable = Entity()
        await DriverPreviewView.rebuild(turntable, driver: driver)

        let camera = PerspectiveCamera()
        camera.look(at: [0, height * 0.5, 0],
                    from: [0, height * 0.67, height * 2.21], relativeTo: nil)
        let light = DirectionalLight()
        light.light.intensity = 5000
        light.look(at: [0, height * 0.5, 0],
                   from: [height, height, height], relativeTo: nil)

        let anchor = AnchorEntity(world: .zero)
        anchor.addChild(turntable)
        anchor.addChild(camera)
        anchor.addChild(light)
        arView.scene.addAnchor(anchor)

        // Give the renderer a few frames to load and draw before grabbing it.
        try? await Task.sleep(for: .milliseconds(250))
        let image = await withCheckedContinuation { continuation in
            arView.snapshot(saveToHDR: false) { continuation.resume(returning: $0) }
        }
        // A fully transparent grab means it drew nothing (rig still loading,
        // no window tick) — treat as a miss so the tile keeps its 2D badge
        // rather than showing an empty circle.
        guard let image, !image.isTransparent else { return nil }
        return image
    }

    private static func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first
    }
}

private extension UIImage {
    /// True if every pixel is fully transparent — a blank snapshot. Samples a
    /// small grid rather than every pixel; a real render trips it on the first
    /// opaque sample.
    var isTransparent: Bool {
        guard let cg = cgImage else { return true }
        let width = cg.width, height = cg.height
        guard width > 0, height > 0 else { return true }
        var pixel = [UInt8](repeating: 0, count: 4)
        guard let ctx = CGContext(data: &pixel, width: 1, height: 1,
                                  bitsPerComponent: 8, bytesPerRow: 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return false }
        let step = max(1, width / 8)
        var y = height / 4
        while y < height {
            var x = 0
            while x < width {
                pixel[3] = 0
                ctx.clear(CGRect(x: 0, y: 0, width: 1, height: 1))
                ctx.draw(cg, in: CGRect(x: -x, y: -y, width: width, height: height))
                if pixel[3] != 0 { return false }
                x += step
            }
            y += max(1, height / 8)
        }
        return true
    }
}
#endif
