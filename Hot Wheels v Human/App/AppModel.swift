//
//  AppModel.swift
//  Hot Wheels v Human
//
//  The one shared app state: which car/track ride into the next race.
//  Features never talk to each other directly — they meet here.
//

import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    /// Car design racing next (garage selection). Nil = demo car.
    var selectedDesign: CarDesign?
    /// Second player's design (2P split-screen customizer).
    var playerTwoDesign: CarDesign?
    /// Track for the next race. Nil = demo track.
    var selectedBlueprint: TrackBlueprint?

    var raceDesign: CarDesign { selectedDesign ?? CarDesign.demoPair[0] }
    var raceBlueprint: TrackBlueprint { selectedBlueprint ?? .demo }
}
