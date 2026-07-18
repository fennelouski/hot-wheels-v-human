//
//  CustomizerSplitView.swift
//  Hot Wheels v Human
//
//  2P on one iPad: top half rotated 180° so the kid across the table
//  builds right-side-up. Both designs land in AppModel.
//

import SwiftUI

struct CustomizerSplitView: View {
    var body: some View {
        VStack(spacing: 0) {
            CustomizerView(isPlayerTwo: true)
                .rotationEffect(.degrees(180))
            Divider().background(.yellow)
            CustomizerView()
        }
        .ignoresSafeArea(.keyboard)   // half-rotated layouts fight the keyboard
    }
}
