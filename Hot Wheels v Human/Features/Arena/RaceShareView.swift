import SwiftUI
import UIKit

struct RaceShareCard: View {
    let payload: RaceSharePayload
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(alignment: .firstTextBaseline) {
                Label(AppBranding.name, systemImage: "flag.checkered")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                Spacer()
                Text(payload.result.trackName).font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.trailing)
            }
            if let image = UIImage(data: payload.arenaImage) {
                Image(uiImage: image).resizable().scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            }
            Text(payload.result.winner.map { "\($0.carName) wins!" } ?? "Race complete")
                .font(.system(size: 64, weight: .black, design: .rounded))
                .foregroundStyle(.yellow)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(Array(payload.result.rankedEntries.enumerated()), id: \.element.id) { index, racer in
                HStack(alignment: .firstTextBaseline, spacing: 18) {
                    Image(systemName: index == 0 && racer.finishTime != nil ? "trophy.fill" : "car.side.fill")
                        .foregroundStyle(index == 0 ? .yellow : .white)
                        .frame(width: 48)
                    Text(racer.carName).font(.system(size: 36, weight: .heavy, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 24)
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(racer.finishTime.map { String(format: "%.1f s", $0) } ?? "Out")
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                        Text(String(format: "Top speed %.1f m/s · %d crashes", racer.topSpeed, racer.crashes))
                            .font(.system(size: 23, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
                .padding(.vertical, 10)
            }
            Rectangle().fill(.yellow).frame(height: 5)
            Text(RaceShareResult.appURL.absoluteString)
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(44).frame(width: 1200)
        .foregroundStyle(.white)
        .background(Color(red: 0.06, green: 0.07, blue: 0.12))
    }
}

@MainActor enum RaceShareRenderer {
    static func image(_ payload: RaceSharePayload) -> UIImage? {
        guard payload.isValid, UIImage(data: payload.arenaImage) != nil else { return nil }
        let renderer = ImageRenderer(content: RaceShareCard(payload: payload))
        renderer.scale = 1
        renderer.isOpaque = true
        return renderer.uiImage
    }
    static func file(_ payload: RaceSharePayload) throws -> URL {
        guard let image = image(payload), let bytes = image.pngData() else { throw ExportError.unreadableImage }
        let root = HWTestSession.isActive ? HWTestSession.directory
            : FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let folder = root.appendingPathComponent("FinishedRaces", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("Race-\(payload.result.id.uuidString).png")
        try bytes.write(to: file, options: .atomic)
        return file
    }
    enum ExportError: Error { case unreadableImage }
}

struct RaceShareSheet: View {
    let payload: RaceSharePayload
    var nearbyHost = false
    @Environment(\.dismiss) private var dismiss
    @State private var file: URL?
    @State private var image: UIImage?
    @State private var exportFailed = false
    @State private var handoff = RaceShareHandoff()

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Label("Share This Race", systemImage: "square.and.arrow.up")
                    .font(.system(.title2, design: .rounded, weight: .black))
                Spacer()
                Button("Done") { dismiss() }
                    #if os(tvOS)
                    .buttonStyle(TVWorkshopButtonStyle())
                    #else
                    .buttonStyle(.bordered).tint(.white).frame(minHeight: 60)
                    #endif
                    .accessibilityIdentifier("race-share-close")
            }
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
                    .frame(maxWidth: 780, maxHeight: .infinity)
                    .accessibilityLabel("Finished race image with results")
                    .accessibilityIdentifier("race-share-image")
            }
            #if os(tvOS)
            Label(nearbyHost ? (handoff.connected ? "Connected to your iPad" : "Open Race on TV on your iPad") : "Share from your connected iPad", systemImage: handoff.connected ? "checkmark.circle.fill" : "ipad.and.arrow.forward")
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .foregroundStyle(.yellow).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("race-share-handoff")
            #else
            if let file, let image {
                ShareLink(item: file, subject: Text("\(AppBranding.name) race"),
                          message: Text(RaceShareResult.appURL.absoluteString),
                          preview: SharePreview("Finished race", image: Image(uiImage: image))) {
                    Label("Share Image", systemImage: "square.and.arrow.up")
                        .font(.system(.title2, design: .rounded, weight: .heavy))
                        .frame(minWidth: 260, minHeight: 72)
                }
                .buttonStyle(.borderedProminent).tint(.yellow).foregroundStyle(.black)
                .accessibilityIdentifier("race-share-system")
            }
            #endif
            if exportFailed {
                Text("The image couldn't be prepared. Close and try again.")
                    .font(.headline).foregroundStyle(.yellow).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(32).frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.09, green: 0.10, blue: 0.16).ignoresSafeArea())
        .foregroundStyle(.white)
        .task {
            image = RaceShareRenderer.image(payload)
            #if os(tvOS)
            if nearbyHost { handoff.start(payload: payload) }
            #else
            do { file = try RaceShareRenderer.file(payload) }
            catch { exportFailed = true }
            #endif
            if image == nil { exportFailed = true }
        }
        .onDisappear { handoff.stop() }
    }
}

/// A presentation owns the exact immutable result and bytes passed to its sheet.
struct RaceSharePresentation: Identifiable {
    let payload: RaceSharePayload
    var id: UUID { payload.result.id }
}

struct RaceResultShareButton: View {
    let coordinator: RaceCoordinator
    @State private var presentation: RaceSharePresentation?
    @State private var requestedResult: UUID?
    @State private var waitingForImage = false
    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
        if let error = coordinator.shareError, !waitingForImage {
            Text(error).font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.white).multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true).frame(maxWidth: 320)
        }
        Button {
            requestedResult = coordinator.session.completedResult?.id
            if let payload = coordinator.sharePayload {
                show(payload)
            } else {
                // A covered RealityView may stop drawing on tvOS. Prepare the
                // real frame while the arena is still visible, then present.
                waitingForImage = true
                coordinator.captureResult(using: coordinator.frameCapture)
            }
        } label: {
            Label(waitingForImage ? "PREPARING…" : "SHARE", systemImage: "square.and.arrow.up")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .frame(minWidth: 260, minHeight: 66)
        }
        #if os(tvOS)
        .buttonStyle(TVWorkshopButtonStyle())
        .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 16))
        #else
        .buttonStyle(.bordered).tint(.white)
        .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 16))
        #endif
        .accessibilityIdentifier("race-share")
        .accessibilityValue(coordinator.sharePayload != nil ? "Ready" : coordinator.shareError != nil ? "Try again" : "Preparing")
        .disabled(waitingForImage)
        .sheet(item: $presentation, onDismiss: {
            coordinator.isPresentingResultShare = false
        }) { item in
            RaceShareSheet(payload: item.payload, nearbyHost: coordinator.needsNearbyShareHost)
        }
        .onChange(of: coordinator.sharePayload?.result.id) { _, id in
            if waitingForImage, id == requestedResult, let payload = coordinator.sharePayload {
                show(payload)
            }
        }
        .onChange(of: coordinator.shareError) { _, error in
            if error != nil { waitingForImage = false }
        }
        .onChange(of: coordinator.session.completedResult?.id) { _, id in
            if id != requestedResult { waitingForImage = false }
        }
        }
    }

    private func show(_ payload: RaceSharePayload) {
        waitingForImage = false
        coordinator.isPresentingResultShare = true
        presentation = RaceSharePresentation(payload: payload)
    }
}
