//
//  ReactionCamView.swift
//  Hot Wheels v Human
//
//  Circular driver PiP: a look into the car's cockpit, from over the hood
//  looking BACK at the driver. Mini RealityView bust leans into turns
//  between the car's interior behind them (seat, rear bench, rear glass
//  with the world sliding past) and the car's own steering wheel in
//  front, which counter-turns with the live yaw rate. One
//  `daylight` colour drives the sky, the cabin bounce AND the 3D key
//  light, so a boost warms the driver's face the same frame it warms
//  the glass. Face-decal badge, player-colored ring. Shown on the TV
//  arena (and Solo Arena) while a player holds their camera button.
//

import SwiftUI
import RealityKit
import UIKit

/// Every cockpit number the PiP tuner can move, in one value so the tuner
/// can drive a REAL `ReactionCamView` rather than a mock-up. `.standard`
/// reads the shipped constants, so normal callers pass nothing and get
/// exactly what RaceTuning says.
struct CockpitTuning: Equatable {
    /// How far the driver is scaled, and how far they're moved up or down
    /// afterwards (scale is about the rig's FEET, so growing them alone
    /// pushes the head out of the top of the circle). Lift is in BODY
    /// HEIGHTS of the scaled rig, so it means the same thing on every
    /// character and at every scale — see `DriverPoser.applyFraming`.
    var bustScale: Float
    var bustLift: Float
    var wheelCenterY: Float
    var wheelRadius: Float
    var wheelAngle: Float
    var horizonRatio: Float
    var vanishShift: Float
    var keyLightWash: Float

    static let standard = CockpitTuning(
        bustScale: RaceTuning.cockpitBustScale,
        bustLift: RaceTuning.cockpitBustLift,
        wheelCenterY: RaceTuning.cockpitWheelCenterY,
        wheelRadius: RaceTuning.cockpitWheelRadiusRatio,
        wheelAngle: RaceTuning.cockpitWheelAngle,
        horizonRatio: RaceTuning.cockpitHorizonRatio,
        vanishShift: RaceTuning.cockpitVanishShift,
        keyLightWash: RaceTuning.cockpitKeyLightWash)
}

struct ReactionCamView: View {
    let director: ReactionDirector
    let design: CarDesign
    /// Defaults to the shipped constants; the PiP tuner passes live values.
    var tuning: CockpitTuning = .standard

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
            CarInteriorView(chassis: design.chassis,
                            trim: Color(hex: design.paint.colorHex),
                            daylight: daylight,
                            speed01: director.speed01,
                            lean: director.lean,
                            tuning: tuning)

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
                        busts.poser?.frameOnHead()
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
                    daylight.mix(with: .white, by: Double(tuning.keyLightWash)))
                keyLight?.light.intensity =
                    director.state == .boosted ? 9000 : 6000
                // Size and lift the driver here, every update, so the tuner's
                // sliders move a live rig instead of needing a rebuild — and
                // unconditionally, so the shipped PiP is the same code path
                // the tuner shows. (This used to skip at `.standard` while
                // the numbers were unsettled, which quietly meant the
                // shipped constants did nothing at all.)
                poser?.applyFraming(scale: tuning.bustScale, lift: tuning.bustLift)
                rebuildIfDriverChanged()
            }

            // The car's own wheel, in front of the driver. Counter-turns:
            // lean is + for a left turn, screen-left is a negative rotation.
            SteeringWheelView(chassis: design.chassis,
                              angle: -CGFloat(director.lean * tuning.wheelAngle),
                              rim: Color(hex: design.partColors?[CarPaintSlot.wheels]
                                         ?? design.paint.colorHex),
                              hub: Color(hex: design.paint.colorHex),
                              tuning: tuning)
                .allowsHitTesting(false)

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

/// What's actually behind the driver. The PiP camera looks BACK at them from
/// over the hood, so a road rushing at us was the one thing that could never
/// be there — it's behind the lens. Drawn far-to-near: sky and scenery
/// sliding across the rear glass (with the car's motion, i.e. the opposite
/// way a forward view scrolls), the rear bench, then the driver's own
/// seatback, which the RealityView bust sits in front of.
///
/// No vignette, no letterbox, no pillars hugging the edges: the PiP is
/// already cropped to a circle, and anything dark around the rim reads as a
/// second, broken crop rather than as a car.
private struct CarInteriorView: View {
    let chassis: ChassisClass
    let trim: Color
    let daylight: Color
    let speed01: Float
    let lean: Float
    let tuning: CockpitTuning

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                let w = size.width, h = size.height
                let sill = h * CGFloat(tuning.horizonRatio)
                // Lean swings what's framed in the glass the other way.
                let slide = -CGFloat(lean) * w * CGFloat(tuning.vanishShift)

                // Cabin fills the whole tile — mid-toned and daylight-tinted,
                // never near-black, so the circle's edge is the only edge.
                ctx.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .color(Color(red: 0.30, green: 0.29, blue: 0.34)
                            .mix(with: daylight, by: 0.22)))

                // Rear glass: generous, so daylight is what's behind them.
                let glass = CGRect(x: w * 0.06, y: h * 0.04,
                                   width: w * 0.88, height: sill - h * 0.04)
                let glassPath = Path(roundedRect: glass, cornerRadius: w * 0.09)
                ctx.fill(glassPath, with: .linearGradient(
                    Gradient(colors: [daylight.opacity(0.95), daylight.opacity(0.45)]),
                    startPoint: CGPoint(x: 0, y: glass.minY),
                    endPoint: CGPoint(x: 0, y: glass.maxY)))

                ctx.drawLayer { sky in
                    sky.clip(to: glassPath)
                    let horizonY = glass.maxY - glass.height * 0.28
                    // Everything behind us converges here — the road we've
                    // already driven, running away into the distance.
                    let vanishX = glass.midX + slide

                    sky.fill(Path(CGRect(x: glass.minX, y: horizonY,
                                         width: glass.width, height: glass.height * 0.28)),
                             with: .color(Color(red: 0.24, green: 0.30, blue: 0.24)))

                    // Scenery RECEDES rather than sliding sideways: we're
                    // facing backwards, so a post we pass rushes away from
                    // the glass and shrinks into the vanishing point. `n` is
                    // 1 at the bumper and 0 at the horizon, squared so
                    // things pile up in the distance and snap away up close
                    // — the same depth curve the old forward road used, run
                    // the other direction.
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    let scroll = t * Double(0.15 + speed01 * RaceTuning.cockpitSceneryDrift)
                    let count = RaceTuning.cockpitSceneryCount
                    for i in 0..<count {
                        let phase = (scroll + Double(i) / Double(count))
                            .truncatingRemainder(dividingBy: 1)
                        let n = CGFloat((1 - phase) * (1 - phase))
                        let side: CGFloat = i.isMultiple(of: 2) ? -1 : 1
                        // Out from the vanishing point as it comes at us,
                        // and down the glass with it.
                        let cx = vanishX + side * glass.width * 0.62 * n
                        let baseY = horizonY + glass.height * 0.30 * n
                        let tall = glass.height * 0.52 * n
                        sky.fill(Path(CGRect(x: cx - glass.width * 0.06 * n, y: baseY - tall,
                                             width: glass.width * 0.12 * n, height: tall)),
                                 with: .color(.white.opacity(0.22)))
                    }

                    // Road running away from the bumper to the horizon —
                    // wide at the bottom of the glass, a point in the
                    // distance. This is what makes the recession read as
                    // depth rather than as things just getting smaller.
                    var road = Path()
                    road.move(to: CGPoint(x: vanishX - glass.width * 0.03, y: horizonY))
                    road.addLine(to: CGPoint(x: vanishX + glass.width * 0.03, y: horizonY))
                    road.addLine(to: CGPoint(x: glass.midX + glass.width * 0.75, y: glass.maxY))
                    road.addLine(to: CGPoint(x: glass.midX - glass.width * 0.75, y: glass.maxY))
                    road.closeSubpath()
                    sky.fill(road, with: .color(Color(red: 0.17, green: 0.17, blue: 0.21)))

                    // Centre dashes shrinking away down it, same depth curve.
                    for i in 0..<RaceTuning.cockpitSceneryCount {
                        let phase = (scroll + Double(i) / Double(RaceTuning.cockpitSceneryCount)
                                     + 0.5).truncatingRemainder(dividingBy: 1)
                        let n = CGFloat((1 - phase) * (1 - phase))
                        let y = horizonY + (glass.maxY - horizonY) * n
                        let cx = vanishX + (glass.midX - vanishX) * n
                        sky.fill(Path(CGRect(x: cx - glass.width * 0.02 * n, y: y,
                                             width: glass.width * 0.04 * n,
                                             height: (glass.maxY - horizonY) * 0.22 * n)),
                                 with: .color(.white.opacity(0.7)))
                    }
                }

                // Roll cage bars over the glass, on the cars that have one.
                if RaceTuning.cockpitRollCage.contains(chassis) {
                    for side in [CGFloat(-1), 1] {
                        var bar = Path()
                        bar.move(to: CGPoint(x: glass.midX + side * glass.width * 0.34,
                                             y: glass.minY))
                        bar.addLine(to: CGPoint(x: glass.midX - side * glass.width * 0.22,
                                                y: glass.maxY))
                        ctx.stroke(bar, with: .color(trim.opacity(0.85)),
                                   style: StrokeStyle(lineWidth: w * 0.035, lineCap: .round))
                    }
                }

                // Rear bench, two humps peeking over the parcel shelf.
                for side in [CGFloat(-1), 1] {
                    let cx = w * 0.5 + side * w * 0.26
                    ctx.fill(Path(roundedRect: CGRect(x: cx - w * 0.16, y: sill - h * 0.02,
                                                      width: w * 0.32, height: h * 0.22),
                                  cornerRadius: w * 0.07),
                             with: .color(Color(red: 0.22, green: 0.21, blue: 0.26)))
                }

                // The driver's own seat, closest to us and widest on a muscle
                // car — this is the interior's per-car tell.
                let seatW = w * CGFloat(RaceTuning.cockpitSeatWidth[chassis]!)
                let seatTop = sill + h * 0.10
                ctx.fill(Path(roundedRect: CGRect(x: (w - seatW) / 2, y: seatTop,
                                                  width: seatW, height: h - seatTop),
                              cornerRadius: w * 0.10),
                         with: .color(Color(red: 0.17, green: 0.16, blue: 0.20)))
                // Headrest above it, and a paint-coloured stripe so the seat
                // belongs to this car and not a generic one.
                ctx.fill(Path(roundedRect: CGRect(x: w * 0.5 - seatW * 0.26,
                                                  y: seatTop - h * 0.09,
                                                  width: seatW * 0.52, height: h * 0.13),
                              cornerRadius: w * 0.05),
                         with: .color(Color(red: 0.20, green: 0.19, blue: 0.24)))
                ctx.fill(Path(roundedRect: CGRect(x: w * 0.5 - seatW * 0.06, y: seatTop,
                                                  width: seatW * 0.12, height: h - seatTop),
                              cornerRadius: w * 0.02),
                         with: .color(trim.opacity(0.55)))
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
    let tuning: CockpitTuning

    // The roster rig's DRIVE pose already holds its arms out at wheel
    // height, so the rim wants to land under those hands — that's what
    // cockpitWheelCenterY is tuned against.
    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let radius = w * CGFloat(tuning.wheelRadius)
            let rimWidth = radius * CGFloat(RaceTuning.cockpitWheelRimWidth[chassis]!)
            let spokes = RaceTuning.cockpitWheelSpokes[chassis]!

            ctx.translateBy(x: w / 2,
                            y: size.height * CGFloat(tuning.wheelCenterY))
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
