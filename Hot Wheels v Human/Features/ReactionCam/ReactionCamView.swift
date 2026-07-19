//
//  ReactionCamView.swift
//  Hot Wheels v Human
//
//  Circular driver PiP: mini RealityView bust (key + rim lit), leaning
//  into turns with the live car, over a speed-line backdrop that scales
//  with the car's actual speed and tints on boost/crash. Face-decal
//  badge, player-colored ring. Shown on the TV arena (and Solo Arena)
//  while a player holds their camera button.
//

import SwiftUI
import RealityKit
import UIKit

struct ReactionCamView: View {
    let director: ReactionDirector
    let design: CarDesign

    @State private var poser: DriverPoser?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ReactionBackdrop(state: director.state,
                             speed01: director.speed01,
                             lean: director.lean,
                             tint: Color(hex: design.paint.colorHex))

            RealityView { content in
                content.camera = .virtual

                guard let poser = try? await DriverPoser.make(
                    profile: design.driver ?? DriverProfile.presets[0]) else { return }
                content.add(poser.bust)

                // Bust framing: the rig is 5.54 m tall — park the camera at
                // chest height, close in, facing the model's front (+Z).
                let head = RaceTuning.driverSourceHeight * 0.82
                let camera = PerspectiveCamera()
                camera.look(at: [0, head, 0], from: [0, head - 0.2, 2.4], relativeTo: nil)
                content.add(camera)

                let key = DirectionalLight()
                key.light.intensity = 6000
                key.look(at: [0, head, 0], from: [1, head + 1, 2], relativeTo: nil)
                content.add(key)

                // Cool rim from behind-left so the bust pops off the backdrop.
                let rim = DirectionalLight()
                rim.light.intensity = 3500
                rim.light.color = UIColor(red: 0.6, green: 0.75, blue: 1.0, alpha: 1)
                rim.look(at: [0, head, 0], from: [-1.5, head + 0.8, -2], relativeTo: nil)
                content.add(rim)

                self.poser = poser
            } update: { _ in
                poser?.apply(director.state)
                // Lean with the live car: roll into the turn, glance into it.
                poser?.bust.orientation =
                    simd_quatf(angle: director.lean * RaceTuning.reactionLeanAngle, axis: [0, 0, 1])
                    * simd_quatf(angle: director.lean * RaceTuning.reactionLeanAngle * 0.5, axis: [0, 1, 0])
                rebuildIfDriverChanged()
            }

            // Kid's face paint rides over every expression. The driver's
            // own paint wins; CarDesign's is the pre-C3 fallback.
            DriverFaceBadge(driver: design.driver, state: director.state,
                            fallbackPaintPNG: design.faceDrawingPNG)
                .frame(width: 48, height: 48)
                .overlay(Circle().stroke(.white.opacity(0.8), lineWidth: 2))
                .padding(6)
        }
        .frame(width: 180, height: 180)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color(hex: design.paint.colorHex), lineWidth: 5))
        .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1).padding(4))
        .overlay(alignment: .bottom) {
            Text(design.name)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(.black.opacity(0.6), in: Capsule())
                .offset(y: 12)
        }
        // Event pops: swell on boost/celebrate, knock askew on crash.
        .scaleEffect(director.state == .boosted || director.state == .celebrating ? 1.08 : 1)
        .rotationEffect(.degrees(director.state == .crashed ? -7 : 0))
        .animation(.spring(duration: 0.35, bounce: 0.5), value: director.state)
        .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
    }

    /// Swap the bust when the character it's wearing changes. A race never
    /// changes driver mid-lap, but the character editor shows this PiP live
    /// while a kid picks hair and hats — without this the bust stays frozen on
    /// whoever it happened to load with.
    ///
    /// Rebuilds rather than repaints: `DriverPainter.apply` on a bust that's
    /// mid-animation swaps the wardrobe geometry but leaves the stripe texture
    /// stale, so a kid going bald kept their hair colour. A fresh poser is
    /// cheap anyway — AssetStore caches the rig, DriverPainter caches the
    /// texture. Signature-guarded because `update` fires on director ticks too.
    @MainActor
    private func rebuildIfDriverChanged() {
        guard let current = poser, let driver = design.driver else { return }
        let signature = DriverPainter.appearanceSignature(for: driver)
        guard current.bust.components[PreviewSignature.self]?.value != signature else { return }
        current.bust.components.set(PreviewSignature(value: signature))
        Task {
            guard let fresh = try? await DriverPoser.make(profile: driver),
                  let parent = current.bust.parent,
                  // A newer edit landed while this one loaded — let that win.
                  current.bust.components[PreviewSignature.self]?.value == signature
            else { return }
            fresh.bust.components.set(PreviewSignature(value: signature))
            parent.addChild(fresh.bust)
            current.bust.removeFromParent()
            poser = fresh
        }
    }
}

/// Radial anime speed lines behind the bust — density, length and drift
/// speed all follow the car's real speed; the whole field tips with the
/// lean and the vignette tints on boost (warm) and crash (red).
private struct ReactionBackdrop: View {
    let state: ReactionState
    let speed01: Float
    let lean: Float
    let tint: Color

    private var glow: Color {
        switch state {
        case .boosted:     Color(red: 0.9, green: 0.45, blue: 0.1)
        case .crashed:     Color(red: 0.75, green: 0.15, blue: 0.1)
        case .celebrating: tint
        default:           Color(red: 0.22, green: 0.28, blue: 0.5)
        }
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = size.width * 0.72
                let speed = CGFloat(speed01)

                ctx.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .radialGradient(
                            Gradient(colors: [glow.opacity(0.55),
                                              Color(red: 0.07, green: 0.08, blue: 0.15)]),
                            center: center, startRadius: 0, endRadius: radius))

                guard speed > 0.03 else { return }
                let t = timeline.date.timeIntervalSinceReferenceDate
                for i in 0..<18 {
                    let seed = Double(i) * 2.399963       // golden angle scatter
                    let angle = seed + Double(lean) * 0.5
                    let phase = (t * (0.4 + Double(speed) * 1.6) + seed)
                        .truncatingRemainder(dividingBy: 1)
                    let inner = radius * (0.45 + 0.55 * CGFloat(phase))
                    let length = radius * 0.3 * speed * CGFloat(0.4 + phase)
                    let dir = CGPoint(x: cos(angle), y: sin(angle))
                    var line = Path()
                    line.move(to: CGPoint(x: center.x + dir.x * inner,
                                          y: center.y + dir.y * inner))
                    line.addLine(to: CGPoint(x: center.x + dir.x * (inner + length),
                                             y: center.y + dir.y * (inner + length)))
                    ctx.stroke(line,
                               with: .color(.white.opacity(0.35 * phase * Double(speed))),
                               style: StrokeStyle(lineWidth: size.width * 0.012, lineCap: .round))
                }
            }
        }
    }
}
