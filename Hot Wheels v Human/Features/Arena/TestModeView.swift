//
//  TestModeView.swift
//  Hot Wheels v Human
//
//  Physics A/B bench (PRD §2.1): pick two builds, run them side by side
//  on the demo track, read the stats. No lives, no boosts — pure feel test.
//  Until the Customizer ships (Phase 4), builds are picked from presets.
//

import SwiftUI

struct TestModeView: View {
    @State private var designA = CarDesign.demoPair[0]
    @State private var designB = CarDesign.demoPair[1]
    @State private var running = false
    @State private var onRails = RaceTuning.railPinned

    var body: some View {
        VStack(spacing: 32) {
            Label("Test Mode", systemImage: "stopwatch.fill")
                .font(.system(size: 56, weight: .black, design: .rounded))
            HStack(spacing: 48) {
                designPicker("Car A", design: $designA)
                designPicker("Car B", design: $designB)
            }
            // The physics A/B bench's other A/B: rails (cars pinned to the
            // track, drift + ballistic jumps) vs the chaotic free physics.
            Toggle(isOn: $onRails) {
                Label("Glued to the Track", systemImage: "pin.fill")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
            }
            .frame(width: 480)
            .padding(.vertical, 8)
            .onChange(of: onRails) { RaceTuning.railPinned = $1 }
            Button {
                running = true
            } label: {
                Label("RUN", systemImage: "flag.checkered")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .padding(.horizontal, 60)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.09, green: 0.10, blue: 0.16))
        .foregroundStyle(.white)
        .racePreview(isPresented: $running, designs: [designA, designB],
                     config: MatchConfig(mode: .test))
    }

    private func designPicker(_ title: String, design: Binding<CarDesign>) -> some View {
        VStack(spacing: 16) {
            Text(title).font(.system(size: 32, weight: .heavy, design: .rounded))
            Picker("Chassis", selection: design.chassis) {
                Label("Muscle", systemImage: "truck.pickup.side.fill").tag(ChassisClass.heavyMuscle)
                Label("Formula", systemImage: "car.side.fill").tag(ChassisClass.balancedFormula)
                Label("Drift", systemImage: "hare.fill").tag(ChassisClass.superlightDrift)
            }
            .pickerStyle(.segmented)
            Picker("Tires", selection: design.tires) {
                Text("Standard").tag(TireType.standard)
                Text("Slick").tag(TireType.slickRacing)
                Text("Grippy").tag(TireType.grippyOffroad)
            }
            .pickerStyle(.segmented)
        }
        .frame(width: 340)
        .padding(24)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
    }
}

#Preview {
    TestModeView()
}
