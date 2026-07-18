//
//  LookalikeView.swift
//  Hot Wheels v Human
//
//  The "Make it look like ME!" flow: one front-camera picture, on-device
//  analysis, colors applied, picture gone — pinky promise. iPad only.
//

#if os(iOS)
import SwiftUI
import UIKit

struct LookalikeView: View {
    /// Called with the palette-snapped colors when the kid keeps them.
    let onKeep: (LookalikeAnalyzer.Result) -> Void
    @Environment(\.dismiss) private var dismiss

    private enum Phase {
        case intro
        case analyzing
        case done(LookalikeAnalyzer.Result)
        case noFace
    }
    @State private var phase: Phase = .intro
    @State private var showingCamera = false

    var body: some View {
        VStack(spacing: 28) {
            switch phase {
            case .intro:
                bigText("Say cheese!")
                Text("One picture, then it disappears — pinky promise.")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    bigButton("Take My Picture", systemImage: "camera.fill") {
                        showingCamera = true
                    }
                } else {
                    Text("Hmm, this iPad can't find its camera.")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                }
            case .analyzing:
                bigText("Ta-da... almost!")
                ProgressView().scaleEffect(2)
            case .done(let result):
                bigText("Ta-da!")
                Text("Your racer got your colors!")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                HStack(spacing: 16) {
                    swatch(result.skinToneHex, label: "Skin")
                    swatch(result.suggestBald ? result.skinToneHex : result.hairColorHex,
                           label: result.suggestBald ? "Shiny!" : "Hair")
                    swatch(result.eyeColorHex, label: "Eyes")
                }
                bigButton("Keep it!", systemImage: "checkmark.circle.fill") {
                    onKeep(result)
                    dismiss()
                }
                retryButton("Try Again")
            case .noFace:
                bigText("Hmm...")
                Text("The camera can't find a face. Are you a robot? Try again!")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                retryButton("One More Try")
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.09, green: 0.10, blue: 0.16))
        .foregroundStyle(.white)
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker { image in
                showingCamera = false
                guard let cgImage = image?.fixedOrientationCGImage else {
                    phase = .noFace
                    return
                }
                phase = .analyzing
                SoundBank.shared.play("camera_shutter")
                Task.detached {
                    // On-device Vision; the image is never written anywhere
                    // and goes away with this task.
                    let result = LookalikeAnalyzer.analyze(cgImage)
                    await MainActor.run {
                        if let result {
                            phase = .done(result)
                            SoundBank.shared.play("confirm_sparkle")
                        } else {
                            phase = .noFace
                            SoundBank.shared.play("nice_try_kazoo")
                        }
                    }
                }
            }
            .ignoresSafeArea()
        }
    }

    private func bigText(_ text: String) -> some View {
        Text(text).font(.system(size: 44, weight: .heavy, design: .rounded))
    }

    private func bigButton(_ title: String, systemImage: String,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 30, weight: .black, design: .rounded))
                .frame(width: 380, height: 84)
        }
        .buttonStyle(.borderedProminent)
        .tint(.yellow)
        .foregroundStyle(.black)
    }

    private func retryButton(_ title: String) -> some View {
        Button {
            phase = .intro
        } label: {
            Label(title, systemImage: "arrow.counterclockwise")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .frame(width: 300, height: 64)
        }
        .buttonStyle(.bordered)
        .tint(.yellow)
    }

    private func swatch(_ hex: String, label: String) -> some View {
        VStack(spacing: 8) {
            Circle().fill(Color(hex: hex)).frame(width: 64, height: 64)
            Text(label).font(.system(size: 18, weight: .bold, design: .rounded))
        }
    }
}

/// Front camera via the system picker: native chrome, ~30 lines, and the
/// image only ever exists in memory (no photo-library involvement).
private struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        if UIImagePickerController.isCameraDeviceAvailable(.front) {
            picker.cameraDevice = .front
        }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onImage: onImage) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate,
                             UINavigationControllerDelegate {
        let onImage: (UIImage?) -> Void
        init(onImage: @escaping (UIImage?) -> Void) { self.onImage = onImage }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onImage(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onImage(nil)
        }
    }
}

private extension UIImage {
    /// Camera images carry EXIF orientation; Vision wants upright pixels.
    var fixedOrientationCGImage: CGImage? {
        if imageOrientation == .up { return cgImage }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered.cgImage
    }
}
#endif
