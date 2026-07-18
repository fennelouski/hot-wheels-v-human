//
//  TrackKitTests.swift
//  Hot Wheels v HumanTests
//
//  Validator rules, solver placement, and lane spline sanity — the pure
//  math half of Phase 1. Physics feel is human-tested in Test Mode.
//

import Foundation
import Testing
import RealityKit
import simd
@testable import Hot_Wheels_v_Human

private func blueprint(_ types: [PieceType]) -> TrackBlueprint {
    TrackBlueprint(trackId: UUID(), lanes: 2,
                   segments: types.enumerated().map { SegmentSpec(index: $0.offset, type: $0.element) })
}

struct ValidatorTests {

    @Test func demoBlueprintIsValid() {
        #expect(BlueprintValidator.validate(.demo).isValid)
    }

    @Test func rejectsEmptyTrack() {
        #expect(!BlueprintValidator.validate(blueprint([])).isValid)
    }

    @Test func rejectsMissingStartGate() {
        #expect(!BlueprintValidator.validate(blueprint([.straight, .finishGate])).isValid)
    }

    @Test func rejectsStartGateNotFirst() {
        #expect(!BlueprintValidator.validate(blueprint([.straight, .startGate, .finishGate])).isValid)
    }

    @Test func rejectsTwoStartGates() {
        #expect(!BlueprintValidator.validate(blueprint([.startGate, .startGate, .finishGate])).isValid)
    }

    @Test func rejectsNoFinishAndNoCircuit() {
        #expect(!BlueprintValidator.validate(blueprint([.startGate, .straight])).isValid)
    }

    @Test func rejectsFinishGateNotLast() {
        #expect(!BlueprintValidator.validate(blueprint([.startGate, .finishGate, .straight])).isValid)
    }

    @Test func rejectsSelfOverlap() {
        // Four right turns come full circle: the finish straight lands
        // exactly on the start gate straight.
        let result = BlueprintValidator.validate(blueprint(
            [.startGate, .curve90R, .curve90R, .curve90R, .curve90R, .finishGate]))
        #expect(result.reasons.contains { $0.contains("on top of each other") })
    }

    @Test func rejectsUndergroundTrack() {
        #expect(!BlueprintValidator.validate(blueprint([.startGate, .hillDown, .finishGate])).isValid)
    }

    @Test func rejectsOversizedTrack() {
        let types: [PieceType] = [.startGate]
            + Array(repeating: .straight, count: RaceTuning.maxTrackPieces)
            + [.finishGate]
        #expect(!BlueprintValidator.validate(blueprint(types)).isValid)
    }

    @Test func acceptsClosedCircuitWithoutFinishGate() {
        // Rectangle: two long sides (2 straight-lengths + corner), two short.
        let circuit = blueprint([.startGate, .straight, .curve90R, .straight, .curve90R,
                                 .straight, .straight, .curve90R, .straight, .curve90R])
        #expect(BlueprintValidator.validate(circuit).isValid)
        #expect(TrackLayoutSolver.solve(circuit).isClosedCircuit)
    }

    @Test func kidReadableReasons() {
        let result = BlueprintValidator.validate(blueprint([.straight]))
        #expect(result.reasons.allSatisfy { !$0.isEmpty && $0.count < 90 })
    }
}

struct SolverTests {

    @Test func demoPlacementsAccumulateCorrectly() {
        let layout = TrackLayoutSolver.solve(.demo)
        #expect(layout.pieces.count == 5)
        // startGate 0→0.8, straight 0.8→1.6, loop advances 0.18 & shifts left 0.2.
        #expect(layout.pieces[1].entryPosition == SIMD3<Float>(0, 0, 0.8))
        #expect(layout.pieces[2].entryPosition == SIMD3<Float>(0, 0, 1.6))
        let curveEntry = layout.pieces[3].entryPosition
        #expect(abs(curveEntry.x - 0.2) < 1e-5 && abs(curveEntry.z - 1.78) < 1e-5)
        // curve90R turns the heading −90°: finish gate runs toward −X.
        #expect(abs(layout.pieces[4].entryYaw + .pi / 2) < 1e-5)
        #expect(!layout.isClosedCircuit)
    }

    @Test func splineArcLengthIsMonotonicAndDense() {
        let lanes = TrackLayoutSolver.solve(.demo).lanes
        for spline in [lanes.center, lanes.left, lanes.right] {
            #expect(spline.count > 30)
            var cumulative: Float = 0
            for i in 1..<spline.count {
                let step = simd_length(spline[i] - spline[i - 1])
                #expect(step > 0.001, "duplicate/backtracking waypoint at \(i)")
                #expect(step < 0.3, "gap too large at \(i)")
                cumulative += step
            }
            #expect(cumulative > 3.0)  // demo track is a few metres of lane
            #expect(spline.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite })
        }
    }

    @Test func loopSplineActuallyLoops() {
        let center = TrackLayoutSolver.solve(.demo).lanes.center
        // Vertical circle radius 0.4 → top of loop ≈ 0.8 m up.
        #expect(center.map(\.y).max()! > 0.7)
        #expect(center.map(\.y).min()! > -0.01)
    }

    @Test func lanesStayOffsetFromCenter() {
        let lanes = TrackLayoutSolver.solve(blueprint([.startGate, .straight, .curve90L, .finishGate])).lanes
        for i in 0..<lanes.center.count {
            let d = simd_length(lanes.left[i] - lanes.right[i])
            #expect(d > 0.08 && d < 0.19, "lane spacing off at waypoint \(i): \(d)")
        }
    }

    @Test func randomTracksAlwaysValidate() {
        // Fuzz the shuffle button (TrackKit README: ×500).
        for i in 0..<500 {
            let track = RandomTrackGenerator.generate(pieceCount: 3 + i % 12)
            let result = BlueprintValidator.validate(track)
            #expect(result.isValid, "invalid random track at iteration \(i): \(result.reasons)")
        }
        // 8+ piece tracks guarantee a loop.
        for _ in 0..<20 {
            let track = RandomTrackGenerator.generate(pieceCount: 10)
            #expect(track.segments.contains { $0.type == .loop })
        }
    }

    @Test func everyPieceTypeHasADefinitionAndSolves() {
        for type in PieceType.allCases {
            _ = PieceCatalog.definition(for: type)  // force-unwrap traps if missing
        }
        // A track using every piece type still solves without NaNs.
        let everything = blueprint([.startGate, .straight, .hillUp, .hillDown, .bump,
                                    .curve90L, .curve90R, .loop, .curveLarge, .rampJump])
        let layout = TrackLayoutSolver.solve(everything)
        #expect(layout.lanes.center.allSatisfy {
            $0.x.isFinite && $0.y.isFinite && $0.z.isFinite
        })
    }
}

/// The catalog's hand-measured geometry vs the REAL bundled models — the
/// seam where "pieces don't line up" bugs live. Kenney straights/hills have
/// 0.04 m connector tabs past each end and a 0.06 m thick bed, so:
///   run  = bounds z-span − 2 × tab
///   rise = bounds y-span − bed thickness
/// (Only meaningful for straight-family pieces; corners/loop have their own
/// shapes.) Regression for the hillUp/hillDown model mix-up: hill-BEGINNING
/// is a slope-transition piece with an angled connector; flat→flat is
/// hill-COMPLETE.
@MainActor
struct PieceModelGeometryTests {

    private static let tab: Float = 0.04
    private static let bedThickness: Float = 0.06

    private func measured(_ modelName: String) async throws -> (run: Float, rise: Float) {
        let entity = try await Entity(named: modelName)
        let bounds = entity.visualBounds(relativeTo: nil)
        return (run: (bounds.max.z - bounds.min.z) - 2 * Self.tab,
                rise: (bounds.max.y - bounds.min.y) - Self.bedThickness)
    }

    @Test func straightModelMatchesCatalog() async throws {
        let def = PieceCatalog.definition(for: .straight)
        let m = try await measured(def.modelName)
        #expect(abs(m.run - def.exitOffset.z) < 0.005)
        #expect(abs(m.rise - def.exitOffset.y) < 0.005)
    }

    @Test func hillModelMatchesCatalog() async throws {
        let def = PieceCatalog.definition(for: .hillUp)
        let m = try await measured(def.modelName)
        #expect(abs(m.run - def.exitOffset.z) < 0.005)
        #expect(abs(m.rise - def.exitOffset.y) < 0.005)
    }

    @Test func hillDownMirrorsHillUp() {
        let up = PieceCatalog.definition(for: .hillUp)
        let down = PieceCatalog.definition(for: .hillDown)
        #expect(up.modelName == down.modelName)
        #expect(down.exitOffset.y == -up.exitOffset.y)
        #expect(down.exitOffset.z == up.exitOffset.z)
        // Reversed model: origin shifted so the high-end connector sits at
        // the traversal entry — bedLift minus the full rise.
        #expect(abs(down.modelOffset.y - (0.19 - up.exitOffset.y)) < 0.001)
        #expect(abs(down.modelOffset.z - up.exitOffset.z) < 0.001)
    }
}
