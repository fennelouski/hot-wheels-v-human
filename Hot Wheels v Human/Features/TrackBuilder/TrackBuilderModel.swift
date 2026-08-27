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
    /// Portal exit spots, keyed by SEGMENT INDEX of the portalOut piece.
    /// Indices are stable because mutations are append/removeLast only.
    private(set) var portalExits: [Int: SIMD2<Float>] = [:]
    /// The portal exit awaiting placement — the next ground tap puts it
    /// there (then normal tapping resumes).
    private(set) var placingPortalIndex: Int?
    /// Segment indices built as ghost pieces. Stable for the same reason
    /// `portalExits` is: mutations are append/removeLast only.
    private(set) var ghostIndices: Set<Int> = []
    /// Ghost mode: pieces placed while this is on come out invisible.
    /// Sticky, so a kid can lay a whole ghost stretch without re-tapping.
    var placingGhost = false
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
        // Portals only arrive as a pair, through appendPortal().
        guard type != .portalIn, type != .portalOut else { return false }
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
        if placingGhost { ghostIndices.insert(types.count - 1) }
        SoundBank.shared.play("track_snap_connect")
    }

    /// Tap a piece already on the track to flip it solid ↔ ghost. Placing
    /// in ghost mode is for a run of them; this is for changing your mind
    /// about one, which is most of what building actually is.
    func toggleGhost(at index: Int) {
        guard types.indices.contains(index) else { return }
        if ghostIndices.remove(index) == nil { ghostIndices.insert(index) }
        SoundBank.shared.play("confirm_sparkle")
    }

    func removeLast() {
        guard types.count > 1 else { return }
        // Portals leave as the pair they arrived as — a lone ring is
        // nothing (and the validator would brick every further append).
        if types.last == .portalOut {
            portalExits.removeValue(forKey: types.count - 1)
            ghostIndices.remove(types.count - 1)
            placingPortalIndex = nil
            types.removeLast()
        }
        ghostIndices.remove(types.count - 1)
        types.removeLast()
        SoundBank.shared.play("piece_delete_pop")
    }

    func clear() {
        types = [.startGate]
        scenery = []
        movingIndex = nil
        portalExits = [:]
        ghostIndices = []
        placingPortalIndex = nil
    }

    /// "Start from one of these" — replace the build with a preset track.
    func load(preset: TrackBlueprint) {
        types = preset.segments.map(\.type)
        portalExits = Dictionary(uniqueKeysWithValues:
            preset.segments.compactMap { segment in
                guard let x = segment.portalX, let z = segment.portalZ else { return nil }
                return (segment.index, SIMD2(x, z))
            })
        ghostIndices = Set(preset.segments.filter { $0.isGhost == true }.map(\.index))
        placingPortalIndex = nil
        worldTheme = preset.worldTheme
        scenery = preset.scenery ?? []
        SoundBank.shared.play("confirm_sparkle")
    }

    // MARK: Portals

    /// Any piece of the track below the ground? (The 3D view fades the
    /// terrain so digging feels fluid — never a fight with the dirt.)
    var isDigging: Bool {
        layout.pieces.contains(where: TunnelPlan.isUnderground)
    }

    var canAppendPortal: Bool {
        !hasFinish && types.count + 2 <= RaceTuning.maxTrackPieces
    }

    /// Add a portal PAIR: the entry ring on the open exit, the exit ring
    /// at a default spot beside the track — then the next ground tap
    /// moves it wherever the kid wants.
    func appendPortal() {
        guard canAppendPortal else {
            SoundBank.shared.play("nope_wobble")
            return
        }
        let exit = layout.exitPosition
        let side = rotated([1.6, 0, 0], by: layout.exitYaw)
        types.append(.portalIn)
        types.append(.portalOut)
        if placingGhost {
            ghostIndices.formUnion([types.count - 2, types.count - 1])
        }
        portalExits[types.count - 1] = SIMD2(exit.x + side.x, exit.z + side.z)
        placingPortalIndex = types.count - 1
        SoundBank.shared.play("track_snap_connect")
    }

    /// Set the pending portal exit down where the kid tapped — rejected
    /// (with the nope sound) if the track would land on top of itself.
    func placePortalExit(atX x: Float, z: Float) {
        guard let index = placingPortalIndex else { return }
        let previous = portalExits[index]
        portalExits[index] = SIMD2(x, z)
        let check = BlueprintValidator.validate(blueprint, requireEnding: false)
        guard check.isValid else {
            portalExits[index] = previous
            SoundBank.shared.play("nope_wobble")
            return
        }
        placingPortalIndex = nil
        SoundBank.shared.play("track_snap_connect")
    }

    /// Tiles tile: street pieces snap to the FULL 0.7 m traffic grid
    /// (so hand-laid roads join the street graph placed cars drive),
    /// paths to a half-tile grid; both place un-rotated so pieces butt
    /// cleanly. People place un-rotated so their patrol axis is
    /// predictable. Everything else lands on a random quarter turn —
    /// tidy but not stamped.
    private static func isTile(_ model: String) -> Bool {
        model.hasPrefix("street-") || model.hasPrefix("city-path")
    }

    private static func snapped(_ value: Float, model: String) -> Float {
        if model.hasPrefix("street-") { return (value / 0.7).rounded() * 0.7 }
        if model.hasPrefix("city-path") { return (value / 0.35).rounded() * 0.35 }
        return value
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
        portalExits = [:]
        ghostIndices = []
        placingPortalIndex = nil
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
                       segments: types.enumerated().map { index, type in
                           SegmentSpec(index: index, type: type,
                                       portalX: portalExits[index]?.x,
                                       portalZ: portalExits[index]?.y,
                                       isGhost: ghostIndices.contains(index) ? true : nil)
                       })
    }
}
