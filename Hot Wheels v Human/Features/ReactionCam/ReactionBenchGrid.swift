//
//  ReactionBenchGrid.swift
//  Hot Wheels v Human
//
//  Dev harness (`--reaction-cam`): every ReactionState side by side, each
//  in a real ReactionCamView, so the driver's clips can be screenshotted
//  repeatably. Racing can't do this — `crashed` needs an actual wipeout and
//  rail-mode races finish with 0 crashes, so the crash clip would never be
//  seen — and `celebrating` only fires on the last frame of a race.
//
//  Two drivers, so one screenshot answers both questions the reaction cam
//  keeps getting wrong: does each state animate, and is the face in the
//  circle the same person who is sitting in the car?
//

import SwiftUI

struct ReactionBenchGrid: View {
    /// Built once and held: `ReactionDirector` is a state machine with a
    /// min-hold clock, so a fresh one per redraw would re-enter every state
    /// and the bench would never settle.
    @State private var directors: [ReactionDirector] = []

    /// Two visibly different people from the roster, each in their own car,
    /// so a PiP showing the wrong driver is obvious rather than plausible.
    private static let drivers = [0, 2]

    private static func design(_ index: Int) -> CarDesign {
        var design = CarDesign.presets[index % CarDesign.presets.count]
        design.driver = DriverProfile.presets[index % DriverProfile.presets.count]
        return design
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ForEach(Array(Self.drivers.enumerated()), id: \.offset) { row, driverIndex in
                    let design = Self.design(driverIndex)
                    VStack(spacing: 8) {
                        Text("\(design.driver?.name ?? "?") — \(design.name)")
                            .font(.headline)
                        ScrollView(.horizontal) {
                            HStack(spacing: 28) {
                                ForEach(Array(ReactionState.allCases.enumerated()),
                                        id: \.offset) { column, state in
                                    let slot = row * ReactionState.allCases.count + column
                                    VStack(spacing: 26) {
                                        if slot < directors.count {
                                            ReactionCamView(director: directors[slot],
                                                            design: design)
                                        }
                                        Text(state.rawValue)
                                            .font(.caption).bold()
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                }
            }
            .padding(.vertical, 24)
        }
        .task {
            guard directors.isEmpty else { return }
            // `fire` sets any state outright, which is the whole point here:
            // the continuous path would need a yaw rate held past minHold.
            directors = Self.drivers.flatMap { _ in
                ReactionState.allCases.map { state in
                    let director = ReactionDirector()
                    director.fire(state)
                    return director
                }
            }
        }
    }
}
