//
//  ChipRow.swift
//  Hot Wheels v Human
//
//  Kid-sized replacement for segmented pickers: big capsule chips with
//  guaranteed contrast on the dark workshop screens (segmented controls
//  rendered white-on-light-gray there and sat far under the 60 pt
//  tap-target rule).
//

import SwiftUI

struct ChipRow<Value: Hashable>: View {
    struct Chip {
        let value: Value
        let title: String
        var symbol: String? = nil
    }

    let chips: [Chip]
    @Binding var selection: Value
    /// false = plain HStack, for rows that live inside another ScrollView.
    var scrolls = true

    var body: some View {
        if scrolls {
            ScrollView(.horizontal, showsIndicators: false) { row }
                .defaultScrollAnchor(.center)
        } else {
            row
        }
    }

    private var row: some View {
        HStack(spacing: 10) {
            ForEach(chips, id: \.value) { chip in
                Button {
                    selection = chip.value
                    SoundBank.shared.play("ui_tap")
                } label: {
                    HStack(spacing: 8) {
                        if let symbol = chip.symbol { Image(systemName: symbol) }
                        Text(chip.title)
                    }
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(selection == chip.value ? .black : .white)
                    .padding(.horizontal, 20)
                    .frame(height: 60)
                    .background(selection == chip.value ? Color.yellow : .white.opacity(0.1),
                                in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
    }
}
