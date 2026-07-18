//
//  ReactionCamView.swift
//  Hot Wheels v Human
//
//  Circular driver PiP: mini RealityView bust + key light, face-decal
//  emoji badge, player-colored ring. Shown on the TV arena (and Solo
//  Arena) while a player holds their camera button.
//

import SwiftUI
import RealityKit

struct ReactionCamView: View {
    let director: ReactionDirector
    let design: CarDesign

    @State private var poser: DriverPoser?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RealityView { content in
                content.camera = .virtual

                guard let poser = try? await DriverPoser.make(paint: design.paint) else { return }
                content.add(poser.bust)

                // Bust framing: the rig is 5.54 m tall — park the camera at
                // chest height, close in, facing the model's front (+Z).
                let head = RaceTuning.driverSourceHeight * 0.82
                let camera = PerspectiveCamera()
                camera.look(at: [0, head, 0], from: [0, head - 0.2, 2.4], relativeTo: nil)
                content.add(camera)

                let light = DirectionalLight()
                light.light.intensity = 6000
                light.look(at: [0, head, 0], from: [1, head + 1, 2], relativeTo: nil)
                content.add(light)

                self.poser = poser
            } update: { _ in
                poser?.apply(director.state)
            }
            .background(Color(red: 0.13, green: 0.15, blue: 0.24))

            Text(FaceDecals.emoji(for: director.state))
                .font(.system(size: 44))
                .padding(6)
        }
        .frame(width: 180, height: 180)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color(hex: design.paint.colorHex), lineWidth: 5))
        .overlay(alignment: .bottom) {
            Text(design.name)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(.black.opacity(0.6), in: Capsule())
                .offset(y: 12)
        }
    }
}
