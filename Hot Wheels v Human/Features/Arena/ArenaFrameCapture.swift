import Foundation
import RealityKit
@preconcurrency import Metal
import CoreImage
import ImageIO
import UniformTypeIdentifiers

/// A one-shot request, consumed by RealityKit's render callback. It reads the
/// actual finished scene, without UIKit window screenshots or fake car art.
nonisolated final class ArenaFrameCapture: @unchecked Sendable {
    typealias Completion = @Sendable (Data?) -> Void
    private let lock = NSLock()
    private var pending: Completion?

    func request(_ completion: @escaping Completion) {
        lock.lock(); defer { lock.unlock() }; pending = completion
    }
    func cancel() { lock.lock(); defer { lock.unlock() }; pending = nil }
    func takeRequest() -> Completion? {
        lock.lock(); defer { lock.unlock() }
        defer { pending = nil }; return pending
    }

    static func jpeg(from texture: any MTLTexture) -> Data? {
        let context = CIContext(options: [.cacheIntermediates: false])
        guard let image = CIImage(mtlTexture: texture, options: [.colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!]) else { return nil }
        // RealityKit's Metal frame has a top-left texture origin. Core Image
        // interprets that memory with a bottom-left origin; normalize the whole
        // genuine frame before encoding, without changing the displayed scene.
        let upright = image.transformed(by: CGAffineTransform(a: 1, b: 0, c: 0, d: -1,
            tx: 0, ty: image.extent.minY + image.extent.maxY))
        let scale = min(1, 1600 / max(upright.extent.width, upright.extent.height))
        let scaled = upright.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        let bytes = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(bytes, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, cgImage, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
        guard CGImageDestinationFinalize(destination), bytes.length <= RaceSharePayload.maximumImageBytes else { return nil }
        return bytes as Data
    }
}

/// Identity post-processing: source pixels are passed to the display unchanged;
/// only a pending user/result request copies one frame into CPU-readable memory.
nonisolated struct ArenaSnapshotEffect: PostProcessEffect, @unchecked Sendable {
    let capture: ArenaFrameCapture
    private var imageContext: CIContext?
    init(capture: ArenaFrameCapture) { self.capture = capture }

    mutating func prepare(for device: any MTLDevice) {
        imageContext = CIContext(mtlDevice: device, options: [.cacheIntermediates: false])
    }

    mutating func postProcess(context: borrowing PostProcessEffectContext<any MTLCommandBuffer>) {
        let source = context.sourceColorTexture
        let target = context.targetColorTexture
        let completion = capture.takeRequest()
        if source.pixelFormat == target.pixelFormat, source.width == target.width, source.height == target.height,
           let blit = context.commandBuffer.makeBlitCommandEncoder() {
            blit.copy(from: source, to: target)
            blit.endEncoding()
        } else if let image = CIImage(mtlTexture: source, options: nil) {
            let renderer = imageContext ?? CIContext(mtlDevice: context.device)
            renderer.render(image, to: target, commandBuffer: context.commandBuffer,
                            bounds: image.extent, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
        } else {
            completion?(nil)
            return
        }
        guard let completion else { return }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: target.pixelFormat,
            width: target.width, height: target.height, mipmapped: false)
        descriptor.storageMode = .shared
        descriptor.usage = [.shaderRead, .shaderWrite]
        guard let copy = context.device.makeTexture(descriptor: descriptor),
              let blit = context.commandBuffer.makeBlitCommandEncoder() else { completion(nil); return }
        blit.copy(from: target, to: copy)
        blit.endEncoding()
        context.commandBuffer.addCompletedHandler { buffer in
            guard buffer.status == .completed else { completion(nil); return }
            DispatchQueue.global(qos: .userInitiated).async {
                completion(ArenaFrameCapture.jpeg(from: copy))
            }
        }
    }
}
