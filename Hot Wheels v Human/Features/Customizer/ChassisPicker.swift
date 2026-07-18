//
//  ChassisPicker.swift
//  Hot Wheels v Human
//
//  Horizontal chassis cards with stat bars derived from RaceTuning —
//  the bars can never lie about the physics.
//

import SwiftUI

struct ChassisPicker: View {
    @Binding var selection: ChassisClass

    var body: some View {
        HStack(spacing: 16) {
            ForEach(ChassisClass.allCases, id: \.self) { chassis in
                Button {
                    selection = chassis
                    SoundBank.shared.play("car_select_vroom")
                } label: {
                    VStack(spacing: 8) {
                        Text(emoji(chassis)).font(.system(size: 44))
                        Text(label(chassis))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                        StatBar(name: "Speed", value: normalized(RaceTuning.maxSpeed[chassis]!,
                                                                among: RaceTuning.maxSpeed))
                        StatBar(name: "Weight", value: normalized(chassis.mass,
                                                                  among: RaceTuning.chassisMass))
                    }
                    .padding(16)
                    .frame(width: 190)
                    .background(selection == chassis ? .yellow.opacity(0.25) : .white.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18)
                        .stroke(selection == chassis ? .yellow : .clear, lineWidth: 3))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func emoji(_ c: ChassisClass) -> String {
        switch c {
        case .heavyMuscle: "🚙"
        case .balancedFormula: "🏎️"
        case .superlightDrift: "🏁"
        }
    }

    private func label(_ c: ChassisClass) -> String {
        switch c {
        case .heavyMuscle: "Muscle"
        case .balancedFormula: "Formula"
        case .superlightDrift: "Drift"
        }
    }
}

func normalized(_ value: Float, among table: [some Hashable: Float]) -> Float {
    let lo = table.values.min() ?? 0
    let hi = table.values.max() ?? 1
    guard hi > lo else { return 1 }
    return 0.25 + 0.75 * (value - lo) / (hi - lo)
}

struct StatBar: View {
    let name: String
    let value: Float   // 0…1

    var body: some View {
        HStack(spacing: 8) {
            Text(name)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .frame(width: 52, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.15))
                    Capsule().fill(.yellow)
                        .frame(width: geo.size.width * CGFloat(min(max(value, 0), 1)))
                }
            }
            .frame(height: 8)
        }
    }
}
