//
//  ReactionCamView.swift
//  Hot Wheels v Human
//
//  Circular driver PiP: a look into the car's cockpit. Mini RealityView
//  bust leans into turns between a windshield (road rushing at the
//  camera, vanishing point sliding into the corner) and the car's own
//  steering wheel, which counter-turns with the live yaw rate. One
//  `daylight` colour drives the sky, the cabin bounce AND the 3D key
//  light, so a boost warms the driver's face the same frame it warms
//  the glass. Face-decal badge, player-colored ring. Shown on the TV
//  arena (and Solo Arena) while a player holds their camera button.
//

import SwiftUI
import RealityKit
import UIKit

struct ReactionCamView: View {
    let director: ReactionDirector
    let design: CarDesign

    /// The live poser, in a reference box rather than plain `@State`: the
    /// per-frame tick below is a long-lived closure, and the character editor
    /// swaps the poser whenever a kid changes a hat. A closure that captured
    /// the poser directly would keep driving a retired camera.
    @State private var busts = PoserBox()
    /// Kept so the driver's face relights with the world outside the glass.
    @State private var keyLight: DirectionalLight?
    /// Retains the per-render-frame framing tick; dropping it stops the chase.
    @State private var frameTick: EventSubscription?

    private var poser: DriverPoser? { busts.poser }

    private var daylight: Color {
        director.state.daylight(carTint: Color(hex: design.paint.colorHex))
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            WindshieldView(daylight: daylight,
                           speed01: director.speed01,
                           lean: director.lean)

            RealityView { content in
                content.camera = .virtual

                guard let poser = try? await DriverPoser.make(
                    profile: design.driver ?? DriverProfile.presets[0]) else { return }
                content.add(poser.bust)

                // The poser owns the camera and chases the driver's head with
                // it every update — framing is per-rig mutable state, and it
                // does not survive a round trip through SwiftUI `@State`.
                content.add(poser.camera)
                let head = RaceTuning.driverSourceHeight * RaceTuning.driverHeadHeightRatio

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

                // Chase the head on every RENDER frame, not every SwiftUI
                // update. `update` only fires when the director publishes a
                // change, and the moment a racer finishes it stops changing —
                // while the cheer clip plays on and jumps the driver clean out
                // of the now-frozen framing, leaving the PiP on their knees.
                frameTick = content.subscribe(to: SceneEvents.Update.self) { [busts] _ in
                    MainActor.assumeIsolated {
                        busts.poser?.frameOnHead(isIdle: director.state == .idle)
                    }
                }

                busts.poser = poser
                self.keyLight = key
            } update: { _ in
                poser?.apply(director.state)
                // Lean with the live car: roll into the turn, glance into it.
                poser?.bust.orientation =
                    simd_quatf(angle: director.lean * RaceTuning.reactionLeanAngle, axis: [0, 0, 1])
                    * simd_quatf(angle: director.lean * RaceTuning.reactionLeanAngle * 0.5, axis: [0, 1, 0])
                // Relight the face from the same source lighting the glass —
                // boost flare, crash red, the car's own colour on the podium —
                // washed toward white so it tints the driver instead of
                // painting them one flat colour.
                keyLight?.light.color = UIColor(
                    daylight.mix(with: .white, by: Double(RaceTuning.cockpitKeyLightWash)))
                keyLight?.light.intensity =
                    director.state == .boosted ? 9000 : 6000
                rebuildIfDriverChanged()
            }

            // The car's own wheel, in front of the driver. Counter-turns:
            // lean is + for a left turn, screen-left is a negative rotation.
            SteeringWheelView(chassis: design.chassis,
                              angle: -CGFloat(director.lean * RaceTuning.cockpitWheelAngle),
                              rim: Color(hex: design.partColors?[CarPaintSlot.wheels]
                                         ?? design.paint.colorHex),
                              hub: Color(hex: design.paint.colorHex))
                .allowsHitTesting(false)

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
            // The camera belongs to the poser, so the replacement brings its
            // own — swap it in with the bust, or the scene keeps rendering
            // from the retired one and the new character never appears. Its
            // framing latches start empty, which is what we want: a body-type
            // change swaps in a differently-sized rig, and the height should
            // re-read off the new skull rather than inherit the old one's.
            parent.addChild(fresh.camera)
            current.camera.removeFromParent()
            current.bust.removeFromParent()
            busts.poser = fresh
        }
    }
}

/// Holds whichever poser is currently on screen, so the per-frame framing
/// tick reads it live instead of capturing one that may since have been
/// swapped out from under it.
@MainActor
private final class PoserBox {
    var poser: DriverPoser?
}

private extension ReactionState {
    /// The world outside the glass. One colour lights the sky, bounces into
    /// the cabin and drives the 3D key light on the driver's face, so every
    /// surface in the PiP agrees about what just happened.
    func daylight(carTint: Color) -> Color {
        switch self {
        case .boosted:     Color(red: 1.0, green: 0.62, blue: 0.20)   // flare
        case .crashed:     Color(red: 0.80, green: 0.20, blue: 0.16)  // hazard
        case .celebrating: carTint                                    // podium
        default:           Color(red: 0.42, green: 0.62, blue: 0.92)  // track day
        }
    }
}

/// The view out the windshield: sky, a road rushing at the camera, and the
/// cabin framing it. The vanishing point slides opposite the turn (that's
/// what makes a corner *feel* like a corner) and the dashes scroll with the
/// car's real speed. `daylight` washes the glass and bounces off the trim.
private struct WindshieldView: View {
    let daylight: Color
    let speed01: Float
    let lean: Float

    private static let asphalt = Color(red: 0.16, green: 0.16, blue: 0.20)
    private static let cabin = Color(red: 0.09, green: 0.09, blue: 0.12)

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                let w = size.width, h = size.height
                let speed = CGFloat(speed01)
                let horizon = h * CGFloat(RaceTuning.cockpitHorizonRatio)
                // Corner into the turn: the road's far end swings the other way.
                let vanishX = w * 0.5
                    - CGFloat(lean) * w * CGFloat(RaceTuning.cockpitVanishShift)

                // Sky, then ground, then the road laid over both.
                ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: horizon)),
                         with: .linearGradient(
                            Gradient(colors: [daylight.opacity(0.85), daylight.opacity(0.35)]),
                            startPoint: .zero, endPoint: CGPoint(x: 0, y: horizon)))
                ctx.fill(Path(CGRect(x: 0, y: horizon, width: w, height: h - horizon)),
                         with: .color(Color(red: 0.20, green: 0.26, blue: 0.20)))

                var road = Path()
                road.move(to: CGPoint(x: vanishX - w * 0.04, y: horizon))
                road.addLine(to: CGPoint(x: vanishX + w * 0.04, y: horizon))
                road.addLine(to: CGPoint(x: w * 1.6, y: h))
                road.addLine(to: CGPoint(x: -w * 0.6, y: h))
                road.closeSubpath()
                ctx.fill(road, with: .color(Self.asphalt))

                // Centre dashes and roadside posts share one depth sweep.
                // `u` is 0 at the horizon, 1 at the bumper — squared so they
                // bunch up in the distance and snap past up close.
                let t = timeline.date.timeIntervalSinceReferenceDate
                let scroll = t * Double(0.3 + speed01 * RaceTuning.cockpitDashSpeed)
                for i in 0..<RaceTuning.cockpitDashCount {
                    let phase = (scroll + Double(i) / Double(RaceTuning.cockpitDashCount))
                        .truncatingRemainder(dividingBy: 1)
                    let u = CGFloat(phase * phase)
                    let y = horizon + (h - horizon) * u
                    let cx = vanishX + (w * 0.5 - vanishX) * u
                    let scale = 0.04 + 0.9 * u
                    ctx.fill(Path(CGRect(x: cx - w * 0.035 * scale, y: y,
                                         width: w * 0.07 * scale,
                                         height: (h - horizon) * 0.18 * scale)),
                             with: .color(.white.opacity(0.75)))
                    // Posts whipping past the shoulders sell speed at the edges.
                    for side in [CGFloat(-1), 1] {
                        let px = cx + side * (w * 0.09 + w * 1.1 * u)
                        ctx.fill(Path(CGRect(x: px, y: y - (h - horizon) * 0.34 * scale,
                                             width: max(1, w * 0.02 * scale),
                                             height: (h - horizon) * 0.34 * scale)),
                                 with: .color(.white.opacity(0.5)))
                    }
                }

                // Overhead lights strobing across the glass — the faster we
                // go, the harder they sweep.
                if speed > 0.05 {
                    let sweep = CGFloat((t * Double(0.5 + speed01))
                        .truncatingRemainder(dividingBy: 1))
                    ctx.fill(Path(CGRect(x: (sweep * 2 - 0.5) * w, y: 0,
                                         width: w * 0.35, height: h)),
                             with: .linearGradient(
                                Gradient(colors: [.clear, .white.opacity(0.22 * speed), .clear]),
                                startPoint: CGPoint(x: (sweep * 2 - 0.5) * w, y: 0),
                                endPoint: CGPoint(x: (sweep * 2 - 0.15) * w, y: 0)))
                }

                // Cabin: roof lining above, A-pillars down the sides, and the
                // daylight bouncing off the trim so the interior shares the mood.
                ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: h * 0.13)),
                         with: .color(Self.cabin))
                for side in [CGFloat(0), 1] {
                    var pillar = Path()
                    let outer = side * w
                    let inner = side == 0 ? w * 0.16 : w * 0.84
                    pillar.move(to: CGPoint(x: outer, y: 0))
                    pillar.addLine(to: CGPoint(x: inner, y: 0))
                    pillar.addLine(to: CGPoint(x: outer, y: h))
                    pillar.closeSubpath()
                    ctx.fill(pillar, with: .color(Self.cabin))
                }
                ctx.fill(Path(CGRect(x: 0, y: h * 0.13, width: w, height: h * 0.05)),
                         with: .color(daylight.opacity(0.35)))
            }
        }
    }
}

/// The car's own steering wheel, drawn in front of the driver and turning
/// with the live yaw rate. Shape comes from the chassis (spokes, rim heft,
/// formula flat-bottom), colours from the car's paint — so a kid's build
/// reads from inside the cockpit too.
private struct SteeringWheelView: View {
    let chassis: ChassisClass
    let angle: CGFloat
    let rim: Color
    let hub: Color

    // The roster rig's DRIVE pose already holds its arms out at wheel
    // height, so the rim wants to land under those hands — that's what
    // cockpitWheelCenterY is tuned against.
    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let radius = w * CGFloat(RaceTuning.cockpitWheelRadiusRatio)
            let rimWidth = radius * CGFloat(RaceTuning.cockpitWheelRimWidth[chassis]!)
            let spokes = RaceTuning.cockpitWheelSpokes[chassis]!

            ctx.translateBy(x: w / 2,
                            y: size.height * CGFloat(RaceTuning.cockpitWheelCenterY))
            ctx.rotate(by: .radians(Double(angle)))

            var ring = Path()
            if RaceTuning.cockpitWheelFlatBottom.contains(chassis) {
                // Long way round from 120° to 60°, then close the chord —
                // that missing 60° arc is the flat bottom.
                ring.addArc(center: .zero, radius: radius,
                            startAngle: .degrees(120), endAngle: .degrees(420),
                            clockwise: false)
                ring.closeSubpath()
            } else {
                ring.addEllipse(in: CGRect(x: -radius, y: -radius,
                                           width: radius * 2, height: radius * 2))
            }
            // Grip first, then a thin paint accent inside it.
            ctx.stroke(ring, with: .color(Color(red: 0.10, green: 0.10, blue: 0.13)),
                       style: StrokeStyle(lineWidth: rimWidth, lineCap: .round))
            ctx.stroke(ring, with: .color(rim.opacity(0.9)),
                       style: StrokeStyle(lineWidth: rimWidth * 0.22, lineCap: .round))

            let hubRadius = radius * 0.24
            for i in 0..<spokes {
                // Two spokes lie flat across; three put one at the bottom;
                // four make a cross.
                let step = 2 * Double.pi / Double(spokes)
                let base = spokes == 3 ? Double.pi : 0.0
                let a = base + step * Double(i)
                var spoke = Path()
                spoke.move(to: CGPoint(x: cos(a) * hubRadius * 0.8,
                                       y: sin(a) * hubRadius * 0.8))
                spoke.addLine(to: CGPoint(x: cos(a) * (radius - rimWidth * 0.3),
                                          y: sin(a) * (radius - rimWidth * 0.3)))
                ctx.stroke(spoke, with: .color(Color(red: 0.14, green: 0.14, blue: 0.17)),
                           style: StrokeStyle(lineWidth: rimWidth * 0.7, lineCap: .round))
            }

            let hubRect = CGRect(x: -hubRadius, y: -hubRadius,
                                 width: hubRadius * 2, height: hubRadius * 2)
            ctx.fill(Path(ellipseIn: hubRect), with: .color(hub))
            ctx.stroke(Path(ellipseIn: hubRect),
                       with: .color(.black.opacity(0.5)), lineWidth: 2)
        }
    }
}
