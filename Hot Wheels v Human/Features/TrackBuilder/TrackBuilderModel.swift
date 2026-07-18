//
//  TrackBuilderModel.swift
//  Hot Wheels v Human
//
//  The ONLY mutations are append/removeLast — pieces always attach to the
//  open exit, so invalid tracks are unrepresentable, not error-messaged.
//

import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class TrackBuilderModel {

    private(set) var types: [PieceType] = [.startGate]

    var blueprint: TrackBlueprint {
        TrackBlueprint(trackId: UUID(), lanes: 2,
                       segments: types.enumerated().map { SegmentSpec(index: $0.offset, type: $0.element) })
    }

    var layout: TrackLayout { TrackLayoutSolver.solve(blueprint) }

    /// Ready to race: validator-approved as-is (finish gate or circuit).
    var isRaceable: Bool { BlueprintValidator.validate(blueprint).isValid }
    var hasFinish: Bool { types.last == .finishGate }

    /// Spice count — loops/bumps/ramps make a track harder.
    var difficulty: Int {
        types.filter { [.loop, .bump, .rampJump].contains($0) }.count
    }

    /// Would appending this piece keep the track buildable?
    func canAppend(_ type: PieceType) -> Bool {
        guard !hasFinish, types.count < RaceTuning.maxTrackPieces else { return false }
        guard type != .startGate else { return false }
        let candidate = makeBlueprint(types + [type])
        // Finish gate must produce a fully valid track; anything else only
        // needs to keep the structure sound (ending comes later).
        return BlueprintValidator.validate(candidate, requireEnding: type == .finishGate).isValid
    }

    func append(_ type: PieceType) {
        guard canAppend(type) else {
            SoundBank.shared.play("nope_wobble")
            return
        }
        types.append(type)
        SoundBank.shared.play("track_snap_connect")
    }

    func removeLast() {
        if types.count > 1 {
            types.removeLast()
            SoundBank.shared.play("piece_delete_pop")
        }
    }

    func clear() { types = [.startGate] }

    func shuffle() {
        types = RandomTrackGenerator.generate(pieceCount: Int.random(in: 8...14))
            .segments.map(\.type)
        SoundBank.shared.play("shuffle_dice")
    }

    func save(named name: String, into context: ModelContext, appModel: AppModel) {
        let bp = blueprint
        if let record = try? TrackBlueprintRecord(name: name, blueprint: bp) {
            context.insert(record)
            try? context.save()
        }
        appModel.selectedBlueprint = bp
        SoundBank.shared.play("track_save_stamp")
    }

    private func makeBlueprint(_ types: [PieceType]) -> TrackBlueprint {
        TrackBlueprint(trackId: UUID(), lanes: 2,
                       segments: types.enumerated().map { SegmentSpec(index: $0.offset, type: $0.element) })
    }
}
