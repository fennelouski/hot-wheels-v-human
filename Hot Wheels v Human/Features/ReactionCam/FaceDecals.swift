//
//  FaceDecals.swift
//  Hot Wheels v Human
//
//  The lightweight 2D driver avatar: a hand-drawn cartoon face in the
//  driver's own skin tone, expression driven by reaction state. Custom-drawn
//  vector paths, not emoji (CLAUDE.md: no stock emoji as art).
//
//  This is the CHEAP avatar — pure SwiftUI Canvas, no RealityKit. It exists
//  so the profile and character GRIDS can show one per tile without paying
//  for a live RealityView each: N simultaneous RealityKit scenes render on
//  the Simulator but drain a real device's Metal drawable pools until it
//  aborts (see OPEN-THREADS "3D grid avatars"). Single-instance previews use
//  the live 3D DriverPreviewView; grids use this.
//

import SwiftUI

/// The player's face icon everywhere a per-driver thumbnail is needed: their
/// character's own skin tone, never a generic smiley.
struct DriverFaceBadge: View {
    var driver: DriverProfile?
    var state: ReactionState = .idle

    var body: some View {
        DriverFaceView(state: state, skinToneHex: driver?.skinToneHex)
            .clipShape(Circle())
    }
}

/// Round cartoon face whose eyes/mouth change with the driver's reaction.
struct DriverFaceView: View {
    let state: ReactionState
    /// Character skin tone for the head; nil keeps the classic toy yellow.
    var skinToneHex: String? = nil

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let stroke = w * 0.05

            // Head
            let head = Path(ellipseIn: CGRect(x: stroke, y: stroke,
                                              width: w - 2 * stroke, height: h - 2 * stroke))
            ctx.fill(head, with: .color(skinToneHex.map { Color(hex: $0) }
                                        ?? Color(red: 1.0, green: 0.85, blue: 0.4)))
            ctx.stroke(head, with: .color(.black.opacity(0.7)), lineWidth: stroke)

            let eyeY = h * 0.4
            let eyeL = CGPoint(x: w * 0.34, y: eyeY)
            let eyeR = CGPoint(x: w * 0.66, y: eyeY)
            let eyeRadius = w * 0.06

            func dotEyes() {
                for p in [eyeL, eyeR] {
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - eyeRadius, y: p.y - eyeRadius,
                                                    width: eyeRadius * 2, height: eyeRadius * 2)),
                             with: .color(.black))
                }
            }
            func xEyes() {
                for p in [eyeL, eyeR] {
                    var path = Path()
                    let r = eyeRadius * 1.4
                    path.move(to: CGPoint(x: p.x - r, y: p.y - r))
                    path.addLine(to: CGPoint(x: p.x + r, y: p.y + r))
                    path.move(to: CGPoint(x: p.x + r, y: p.y - r))
                    path.addLine(to: CGPoint(x: p.x - r, y: p.y + r))
                    ctx.stroke(path, with: .color(.black), lineWidth: stroke)
                }
            }
            func starEyes() {
                for p in [eyeL, eyeR] {
                    var path = Path()
                    let r = eyeRadius * 1.8
                    for i in 0..<10 {
                        let angle = Double(i) * .pi / 5 - .pi / 2
                        let radius = i.isMultiple(of: 2) ? r : r * 0.45
                        let pt = CGPoint(x: p.x + cos(angle) * radius, y: p.y + sin(angle) * radius)
                        i == 0 ? path.move(to: pt) : path.addLine(to: pt)
                    }
                    path.closeSubpath()
                    ctx.fill(path, with: .color(Color(red: 1.0, green: 0.6, blue: 0.1)))
                }
            }
            func happyEyes() {   // upside-down arcs
                for p in [eyeL, eyeR] {
                    var path = Path()
                    path.addArc(center: p, radius: eyeRadius * 1.5,
                                startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
                    ctx.stroke(path, with: .color(.black), lineWidth: stroke)
                }
            }
            func squintEyes() {  // flat lines
                for p in [eyeL, eyeR] {
                    var path = Path()
                    path.move(to: CGPoint(x: p.x - eyeRadius * 1.5, y: p.y))
                    path.addLine(to: CGPoint(x: p.x + eyeRadius * 1.5, y: p.y))
                    ctx.stroke(path, with: .color(.black), lineWidth: stroke)
                }
            }

            let mouthCenter = CGPoint(x: w * 0.5, y: h * 0.66)
            func smile(_ radius: CGFloat, open: Bool = false) {
                var path = Path()
                path.addArc(center: mouthCenter, radius: radius,
                            startAngle: .degrees(20), endAngle: .degrees(160), clockwise: false)
                if open {
                    path.closeSubpath()
                    ctx.fill(path, with: .color(.black.opacity(0.8)))
                } else {
                    ctx.stroke(path, with: .color(.black), lineWidth: stroke)
                }
            }
            func oMouth(_ radius: CGFloat) {
                ctx.fill(Path(ellipseIn: CGRect(x: mouthCenter.x - radius, y: mouthCenter.y - radius,
                                                width: radius * 2, height: radius * 2)),
                         with: .color(.black.opacity(0.8)))
            }
            func wavyMouth() {
                var path = Path()
                let r = w * 0.16
                path.move(to: CGPoint(x: mouthCenter.x - r, y: mouthCenter.y))
                for i in 1...4 {
                    let x = mouthCenter.x - r + CGFloat(i) * r / 2
                    let y = mouthCenter.y + (i.isMultiple(of: 2) ? -1 : 1) * w * 0.04
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                ctx.stroke(path, with: .color(.black), lineWidth: stroke)
            }
            func flatMouth() {
                var path = Path()
                path.move(to: CGPoint(x: mouthCenter.x - w * 0.16, y: mouthCenter.y))
                path.addLine(to: CGPoint(x: mouthCenter.x + w * 0.16, y: mouthCenter.y))
                ctx.stroke(path, with: .color(.black), lineWidth: stroke)
            }

            switch state {
            case .idle:
                dotEyes(); smile(w * 0.14)
            case .steerLeft, .steerRight:
                dotEyes(); oMouth(w * 0.07)
            case .braced:
                squintEyes(); flatMouth()
            case .boosted:
                starEyes(); smile(w * 0.16, open: true)
            case .crashed:
                xEyes(); wavyMouth()
            case .celebrating:
                happyEyes(); smile(w * 0.18, open: true)
            }
        }
    }
}
