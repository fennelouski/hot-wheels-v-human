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
    /// Who's playing (profile picker). Nil = not picked yet.
    var selectedProfile: KidProfile?
    /// The character racing next. Nil = first starter character.
    var selectedDriver: DriverProfile?

    var raceDesign: CarDesign { selectedDesign ?? CarDesign.demoPair[0] }
    var raceBlueprint: TrackBlueprint { selectedBlueprint ?? .demo }
    var raceDriver: DriverProfile { selectedDriver ?? DriverProfile.presets[0] }

    /// The design that actually races: the selected car with the selected
    /// character stamped in, so the driver rides the wire inside the design.
    func stampedRaceDesign() -> CarDesign {
        var design = raceDesign
        design.driver = raceDriver
        return design
    }
}
