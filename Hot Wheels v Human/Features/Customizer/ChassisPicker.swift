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
                        Image(systemName: symbol(chassis)).font(.system(size: 38, weight: .bold))
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

    private func symbol(_ c: ChassisClass) -> String {
        switch c {
        case .heavyMuscle: "truck.pickup.side.fill"
        case .balancedFormula: "car.side.fill"
        case .superlightDrift: "hare.fill"
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

/// Pick the car's body shape up front — the thing a kid actually pictures
/// when they say "my car". Rides in `modelOverride`; physics still comes from
/// the chassis class picked on the next tab. (Used to be buried in the
/// Garage's Body Shop as a separate "make a new car" flow.)
struct BodyPicker: View {
    @Binding var selection: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(CarDesign.bodyShop, id: \.model) { body in
                    let isSelected = selection == body.model
                    Button {
                        selection = body.model
                        SoundBank.shared.play("car_select_vroom")
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: body.symbol).font(.system(size: 38, weight: .bold))
                                .frame(height: 44)
                            Text(body.name)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .lineLimit(1)
                        }
                        .padding(16)
                        .frame(width: 150)
                        .background(isSelected ? .yellow.opacity(0.25) : .white.opacity(0.08),
                                    in: RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18)
                            .stroke(isSelected ? .yellow : .clear, lineWidth: 3))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
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
