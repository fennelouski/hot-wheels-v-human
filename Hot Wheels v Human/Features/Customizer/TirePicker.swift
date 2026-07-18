//
//  TirePicker.swift
//  Hot Wheels v Human
//

import SwiftUI

struct TirePicker: View {
    @Binding var selection: TireType

    var body: some View {
        HStack(spacing: 16) {
            ForEach(TireType.allCases, id: \.self) { tire in
                Button {
                    selection = tire
                } label: {
                    VStack(spacing: 8) {
                        Text(emoji(tire)).font(.system(size: 44))
                        Text(label(tire))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                        StatBar(name: "Grip", value: normalized(tire.staticFriction,
                                                                among: RaceTuning.tireStaticFriction))
                        StatBar(name: "Slide", value: 1.25 - normalized(tire.staticFriction,
                                                                        among: RaceTuning.tireStaticFriction))
                    }
                    .padding(16)
                    .frame(width: 190)
                    .background(selection == tire ? .yellow.opacity(0.25) : .white.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18)
                        .stroke(selection == tire ? .yellow : .clear, lineWidth: 3))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func emoji(_ t: TireType) -> String {
        switch t {
        case .standard: "🛞"
        case .slickRacing: "💨"
        case .grippyOffroad: "🕸️"
        }
    }

    private func label(_ t: TireType) -> String {
        switch t {
        case .standard: "Standard"
        case .slickRacing: "Slicks"
        case .grippyOffroad: "Grippy"
        }
    }
}
