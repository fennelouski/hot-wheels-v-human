//
//  DriverEditorView.swift
//  Hot Wheels v Human
//
//  Helmet/suit/skin/hair + name with a random-name dice. The 3D seated
//  avatar arrives with the Quaternius rig in Phase 6 — colors are stored
//  on the wire format today.
//

import SwiftUI

struct DriverEditorView: View {
    @Binding var driver: DriverProfile

    private static let skinTones = ["#FFDBB4", "#F1C27D", "#E0AC69", "#C68642", "#8D5524"]

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 12) {
                TextField("Driver name", text: $driver.name)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    #if !os(tvOS)
                    .textFieldStyle(.roundedBorder)
                    #endif
                    .frame(maxWidth: 280)
                Button {
                    driver.name = ["Max", "Zip", "Dot", "Rex", "Sky", "Pip",
                                   "Ace", "Juno", "Bolt", "Nova"].randomElement()!
                } label: {
                    Text("🎲").font(.system(size: 40))
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 28) {
                colorDot("Helmet", hex: $driver.helmetColorHex)
                colorDot("Suit", hex: $driver.suitColorHex)
                VStack(spacing: 6) {
                    Text("Skin").font(.system(size: 15, weight: .semibold, design: .rounded))
                    HStack(spacing: 6) {
                        ForEach(Self.skinTones, id: \.self) { tone in
                            Button {
                                driver.skinToneHex = tone
                            } label: {
                                Circle().fill(Color(hex: tone))
                                    .frame(width: 34, height: 34)
                                    .overlay(Circle().stroke(
                                        driver.skinToneHex == tone ? .yellow : .clear, lineWidth: 3))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                VStack(spacing: 6) {
                    Text("Hair").font(.system(size: 15, weight: .semibold, design: .rounded))
                    Picker("Hair", selection: $driver.hair) {
                        Text("✂️").tag(HairStyle.short)
                        Text("🎸").tag(HairStyle.long)
                        Text("🌀").tag(HairStyle.curly)
                        Text("🥚").tag(HairStyle.bald)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }
            }
        }
    }

    private func colorDot(_ label: String, hex: Binding<String>) -> some View {
        VStack(spacing: 6) {
            Text(label).font(.system(size: 15, weight: .semibold, design: .rounded))
            HStack(spacing: 6) {
                ForEach(["#FFD500", "#FF3B30", "#2266FF", "#34C759", "#F2F2F7"], id: \.self) { option in
                    Button {
                        hex.wrappedValue = option
                    } label: {
                        Circle().fill(Color(hex: option))
                            .frame(width: 34, height: 34)
                            .overlay(Circle().stroke(
                                hex.wrappedValue == option ? .yellow : .clear, lineWidth: 3))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
