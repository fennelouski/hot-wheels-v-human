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
    /// Picked world (ArenaEnvironment theme name); nil = surprise me.
    private(set) var worldTheme: String?
    /// Hand-placed decorations — any prop from any world.
    private(set) var scenery: [SceneryItem] = []
    /// The decoration the kid is currently placing (palette selection);
    /// taps on the ground drop one of these.
    var placingModel: String?
    /// A placed decoration picked up for moving (tap it → tap the ground).
    var movingIndex: Int?
    /// Decorate mode: palette shows the decoration box, drag pans the
    /// world instead of orbiting. Lives here (not view state) so the 3D
    /// view can switch its gestures on it.
    var decorating = false
    /// Empty world — theme look only, the kid places everything.
    private(set) var worldEmpty = false

    var blueprint: TrackBlueprint {
        var bp = makeBlueprint(types)
        bp.worldTheme = worldTheme
        bp.scenery = scenery.isEmpty ? nil : scenery
        bp.worldEmpty = worldEmpty ? true : nil
        return bp
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

    func clear() {
        types = [.startGate]
        scenery = []
        movingIndex = nil
    }

    /// "Start from one of these" — replace the build with a preset track.
    func load(preset: TrackBlueprint) {
        types = preset.segments.map(\.type)
        worldTheme = preset.worldTheme
        scenery = preset.scenery ?? []
        SoundBank.shared.play("confirm_sparkle")
    }

    /// Street/sidewalk tiles tile: they snap to a half-tile grid and
    /// place un-rotated so pieces butt cleanly; people place un-rotated
    /// so their patrol axis is predictable. Everything else lands on a
    /// random quarter turn — tidy but not stamped.
    private static func isTile(_ model: String) -> Bool {
        model.hasPrefix("street-") || model.hasPrefix("city-path")
    }

    private static func snapped(_ value: Float, model: String) -> Float {
        Self.isTile(model) ? (value / 0.35).rounded() * 0.35 : value
    }

    /// Drop the selected decoration where the kid tapped.
    func placeScenery(atX x: Float, z: Float) {
        guard let model = placingModel,
              scenery.count < RaceTuning.maxSceneryItems else {
            SoundBank.shared.play("nope_wobble")
            return
        }
        let yaw: Float = Self.isTile(model) || SceneryPlacer.isPerson(model)
            ? 0 : [0, .pi / 2, .pi, 3 * .pi / 2].randomElement() ?? 0
        scenery.append(SceneryItem(model: model,
                                   x: Self.snapped(x, model: model),
                                   z: Self.snapped(z, model: model), yaw: yaw))
        SoundBank.shared.play("track_snap_connect")
    }

    /// Set the picked-up decoration down where the kid tapped.
    func moveScenery(atX x: Float, z: Float) {
        guard let index = movingIndex, scenery.indices.contains(index) else {
            movingIndex = nil
            return
        }
        scenery[index].x = Self.snapped(x, model: scenery[index].model)
        scenery[index].z = Self.snapped(z, model: scenery[index].model)
        movingIndex = nil
        SoundBank.shared.play("track_snap_connect")
    }

    /// Tap the picked-up item again: spin it a quarter turn (stays held).
    func rotatePickedScenery() {
        guard let index = movingIndex, scenery.indices.contains(index) else { return }
        scenery[index].yaw += .pi / 2
        SoundBank.shared.play("track_snap_connect")
    }

    func removeLastScenery() {
        movingIndex = nil
        if !scenery.isEmpty {
            scenery.removeLast()
            SoundBank.shared.play("piece_delete_pop")
        }
    }

    /// World picker: nil = surprise me (trackId hash picks).
    func selectWorld(_ name: String?) {
        guard worldTheme != name else { return }
        worldTheme = name
        SoundBank.shared.play("confirm_sparkle")
    }

    /// Empty world toggle — keep the sky and ground, clear the stuff.
    func toggleWorldEmpty() {
        worldEmpty.toggle()
        SoundBank.shared.play("confirm_sparkle")
    }

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
