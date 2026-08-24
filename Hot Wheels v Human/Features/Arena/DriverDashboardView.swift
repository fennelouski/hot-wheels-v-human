//
//  DriverDashboardView.swift
//  Hot Wheels v Human
//
//  The strip of dashboard you see from the driver's seat: a padded dash lip
//  along the bottom of the FPV, with the car radio bolted to it. Six presets,
//  one tap each, music swaps on the spot.
//
//  Only shown in driver view — in the chase camera there's no cockpit to
//  bolt it to. Same control for both platforms: tapped on iPad, clicked with
//  the Siri Remote on the TV, exactly like the camera toggle above it.
//

import SwiftUI

struct DriverDashboardView: View {
    let station: RadioStation
    let onPick: (RadioStation) -> Void

    var body: some View {
        // Sized to clear the boost dial in the bottom-trailing corner even
        // in portrait, where the iPad is only 834 pt wide — hence the icon
        // alone instead of a "RADIO" label.
        HStack(spacing: 10) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(.white.opacity(0.7))
            ForEach(RadioStation.allCases, id: \.self) { preset in
                Button { onPick(preset) } label: {
                    VStack(spacing: 2) {
                        Image(systemName: preset.symbol)
                            .font(.system(size: 22, weight: .bold))
                        Text(preset.label)
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .lineLimit(1)
                    }
                    .frame(width: 76, height: 62)
                }
                .buttonStyle(.bordered)
                .tint(preset == station ? .yellow : .white.opacity(0.35))
                .foregroundStyle(preset == station ? .yellow : .white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            // The dash itself: dark moulding with a lit top edge, so it
            // reads as a surface in front of the hood rather than a floating
            // toolbar.
            RoundedRectangle(cornerRadius: 22)
                .fill(.black.opacity(0.6))
                .overlay {
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(.white.opacity(0.18), lineWidth: 2)
                }
        }
    }
}
