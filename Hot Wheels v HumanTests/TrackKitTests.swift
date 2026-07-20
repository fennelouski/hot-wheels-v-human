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

    /// Was `rejectsUndergroundTrack`. A track that opens with a hillDown is
    /// no longer digging — it's a downhill start, which is a feature now.
    /// The solver lifts the whole layout so the lowest point rests on the
    /// ground, so there is nothing left to reject: underground is
    /// unreachable by construction rather than by rule.
    /// (Geometry side: aTrackThatDescendsFromTheStartIsLiftedNotBuried.)
    @Test func acceptsATrackThatStartsDownhill() {
        #expect(BlueprintValidator.validate(
            blueprint([.startGate, .hillDown, .finishGate])).isValid)
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

    /// A jump launches you STRAIGHT — it used to be a banked corner, which is
    /// exactly the bug ("no straight-line jump"). Pin it kinematically to a
    /// straight (drops into any straightaway, no re-layout) that still gates
    /// on entry speed so it stays a launch, not a lump.
    @Test func rampJumpIsAStraightLaunch() {
        let jump = PieceCatalog.definition(for: .rampJump)
        let straight = PieceCatalog.definition(for: .straight)
        #expect(jump.headingChange == 0)                       // not a turn
        #expect(jump.exitOffset == straight.exitOffset)        // straight kinematics
        #expect(jump.minEntrySpeed != nil)                     // still a launch
        // Swappable with .bump/.straight in presets without moving anything:
        // that's what kept the locked layouts valid.
        #expect(jump.exitOffset == PieceCatalog.definition(for: .bump).exitOffset)
    }

    /// The ramp's centreline has to CREST — a flat spline is a flat
    /// straight in rail mode, which is the mode we ship. Entry and exit
    /// stay at y = 0 so all 7 locked presets keep their layouts.
    @Test func rampJumpCrestsAndStillEndsLevel() {
        guard case .crest(let length, let height) =
            PieceCatalog.definition(for: .rampJump).shape else {
            Issue.record("rampJump must crest, not run flat"); return
        }
        #expect(height > 0)

        let lanes = TrackLayoutSolver.solve(blueprint([.startGate, .rampJump, .finishGate])).lanes
        let ys = lanes.center.map(\.y)
        #expect(ys.max()! >= height - 0.001)     // it really rises
        #expect(ys.first! == 0)                  // ...and both seams are level
        #expect(abs(ys.last!) < 1e-5)
        #expect(abs(length - PieceCatalog.definition(for: .straight).exitOffset.z) < 1e-5)
    }

    /// End to end on the geometry the game actually builds: a car driven
    /// down a solved lane must leave the ground over the ramp and land
    /// back on the lane. This is the check that a flat rampJump failed.
    @Test func rampJumpThrowsACarOffTheSolvedLane() {
        /// Ground distance covered while off the bed, metres (0 = never flew).
        func airDistance(_ types: [PieceType]) -> Float {
            let lanes = TrackLayoutSolver.solve(blueprint(types)).lanes
            var follow = LaneFollowComponent(waypoints: lanes.left, laterals: lanes.laterals)
            var state = CarComponent(playerID: UUID(), design: .demoPair[0],
                                     livesLeft: 5, rideHeight: 0.05)
            var takeOff: SIMD3<Float>?
            var distance: Float = 0
            for _ in 0..<1200 {
                let wasFlying = follow.airborne
                let pose = DriveSystem.railStep(follow: &follow, state: &state, dt: 1 / 60)
                if follow.airborne, !wasFlying { takeOff = pose.position }
                if !follow.airborne, let up = takeOff {
                    distance = max(distance, simd_length(SIMD3(pose.position.x - up.x, 0,
                                                               pose.position.z - up.z)))
                    takeOff = nil
                }
            }
            #expect(!follow.airborne)   // whatever went up came back down
            return distance
        }
        let runway: [PieceType] = Array(repeating: .straight, count: 5)
        // Real air, not a one-frame jitter: at rail pace the arc carries
        // the car most of a piece length.
        #expect(airDistance([.startGate] + runway + [.rampJump] + runway + [.finishGate]) > 0.3)
        // Control: the same track with a plain straight in the ramp's slot
        // must NOT launch, or the test is passing on something else.
        #expect(airDistance([.startGate] + runway + [.straight] + runway + [.finishGate]) == 0)
    }

    /// The downhill start: a track may now BEGIN on a descent. The solver
    /// normalises levels so the lowest point rests on the ground, which
    /// lifts the start above it instead of digging the first hillDown
    /// underground (which is what `solve` hardcoding level 0 used to do,
    /// and what BlueprintValidator then rejected).
    @Test func aTrackThatDescendsFromTheStartIsLiftedNotBuried() {
        let layout = TrackLayoutSolver.solve(
            blueprint([.startGate, .hillDown, .straight, .finishGate]))

        // Nothing underground, ever — the lowest point sits exactly on it.
        #expect(layout.pieces.allSatisfy { $0.entryLevel >= 0 })
        #expect(layout.pieces.map(\.entryPosition.y).min()! == 0)
        // ...and the start really is up in the air, on a descent.
        #expect(layout.startPosition.y == RaceTuning.elevationLevelHeight)
        #expect(layout.pieces[1].entryPosition.y > layout.pieces[2].entryPosition.y)
        // Which the validator now accepts rather than calling it digging.
        #expect(BlueprintValidator.validate(
            blueprint([.startGate, .hillDown, .straight, .finishGate])).isValid)
    }

    /// A flat track must be exactly where it always was — normalising levels
    /// is a no-op unless something actually descends below the start.
    @Test func levelNormalisationLeavesFlatTracksAtTheOrigin() {
        let layout = TrackLayoutSolver.solve(
            blueprint([.startGate, .straight, .hillUp, .straight, .finishGate]))
        #expect(layout.startPosition == .zero)
        #expect(layout.pieces[0].entryLevel == 0)
    }

    /// Circuit closure is measured against the START, not the origin — an
    /// elevated circuit returns to where it began, which is no longer zero.
    @Test func closedCircuitStillClosesWhenTheStartIsLifted() {
        let ring: [PieceType] = [.startGate, .hillDown, .straight]
            + [.curve90R, .curve90R] + [.straight, .hillUp, .straight]
            + [.curve90R, .curve90R]
        let layout = TrackLayoutSolver.solve(blueprint(ring))
        #expect(layout.startPosition.y > 0)          // not vacuous
        #expect(layout.isClosedCircuit)
    }

    /// TrackSpawner stacks `entryLevel` cosmetic legs of one
    /// `elevationLevelHeight` each under an elevated piece, so the solver's
    /// world Y must stay exactly that product — drift and the legs either
    /// float under the bed or pierce it.
    @Test func entryHeightMatchesElevationLevel() {
        // Climb two levels, cruise, come back down.
        let pieces = TrackLayoutSolver.solve(
            blueprint([.startGate, .hillUp, .straight, .hillUp,
                       .straight, .hillDown, .straight, .hillDown])).pieces
        #expect(pieces.contains { $0.entryLevel == 2 })   // not vacuous
        for piece in pieces {
            let expected = Float(piece.entryLevel) * RaceTuning.elevationLevelHeight
            #expect(abs(piece.entryPosition.y - expected) < 1e-5)
        }
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
/// What TrackSpawner actually puts in the entity tree. The chase camera
/// can't see undersides, so "do the legs float / pierce the bed" is settled
/// here rather than by eye — and gate overlays are pinned because nothing
/// else covers them: a `if false,` debug experiment once disabled every
/// overlay (and with it every CheckpointComponent) and the whole suite
/// still went green.
@MainActor
struct TrackSpawnerTests {

    /// Gate arches carry the CheckpointComponent that RaceRulesSystem
    /// counts laps and finishes with — no overlay, no finish line.
    @Test func gatesSpawnOverlaysCarryingCheckpoints() async throws {
        let layout = TrackLayoutSolver.solve(
            blueprint([.startGate, .straight, .curve90L, .finishGate]))
        let root = try await TrackSpawner.spawn(layout: layout)
        let checkpoints = root.children.compactMap {
            $0.components[CheckpointComponent.self]
        }
        #expect(checkpoints.count == 2)                       // start + finish
        #expect(checkpoints.filter(\.isFinish).count == 1)
        #expect(root.children.contains { $0.name.hasPrefix("overlay-") })
    }

    /// A hill's collision slab has to be pitched the SAME way its spline
    /// runs. It was pitched the opposite way — `simd_quatf(angle:axis:[1,0,0])`
    /// rotates +Z toward −Y, so a positive rise tipped the slab downhill —
    /// which stood the slab's high end up as a 20 cm lip right at the
    /// entry seam. That lip is what wedged cars on hills (chaos mode; rail
    /// cars are kinematic and float straight through it, which is why the
    /// rescue counter went quiet without the defect ever being fixed).
    @Test func hillBedSlabsPitchAlongTheirOwnRise() async throws {
        let layout = TrackLayoutSolver.solve(
            blueprint([.startGate, .hillUp, .straight, .hillDown, .finishGate]))
        let root = try await TrackSpawner.spawn(layout: layout)

        for piece in layout.pieces {
            guard case .line(let length, let rise) = piece.definition.shape else { continue }
            let bed = try #require(root.children.first { $0.name == "bed-\(piece.index)" })
            // Slab's own forward axis in world space = the surface it presents.
            let forward = bed.convert(direction: SIMD3<Float>(0, 0, 1), to: nil)
            let slope = forward.y / simd_length(SIMD3(forward.x, 0, forward.z))
            #expect(abs(slope - rise / length) < 0.01)
        }
        // Not vacuous: the track really does contain a rise and a drop.
        #expect(layout.pieces.contains { $0.definition.elevationDelta > 0 })
        #expect(layout.pieces.contains { $0.definition.elevationDelta < 0 })
    }

    /// Climbs to level 2 and back down, so the top flats need two legs each.
    private static let climb: [PieceType] =
        [.startGate, .straight, .hillUp, .straight, .hillUp,
         .straight, .hillDown, .straight, .hillDown]

    @Test func elevatedFlatsGetStackedCollisionFreeLegs() async throws {
        let layout = TrackLayoutSolver.solve(blueprint(Self.climb))
        let root = try await TrackSpawner.spawn(layout: layout)
        let legs = root.children.filter { $0.name.hasPrefix("support-") }

        // One leg per level under flat elevated pieces; hills carry none.
        let expected = layout.pieces
            .filter { $0.definition.elevationDelta == 0 }
            .reduce(0) { $0 + $1.entryLevel }
        #expect(expected > 0)                       // not vacuous
        #expect(legs.count == expected)
        // A car that flies off has to fall PAST them.
        #expect(legs.allSatisfy { $0.components[CollisionComponent.self] == nil })
    }

    @Test func legStackReachesTheBedItHoldsUp() async throws {
        let layout = TrackLayoutSolver.solve(blueprint(Self.climb))
        let root = try await TrackSpawner.spawn(layout: layout)
        let highest = layout.pieces
            .filter { $0.entryLevel > 0 && $0.definition.elevationDelta == 0 }
            .max { $0.entryLevel < $1.entryLevel }!
        let stack = root.children.filter { $0.name.hasPrefix("support-\(highest.index)-") }

        // Top of the stack tucks inside the 0.06 m bed: no daylight gap
        // under the track, no post poking up through the driving surface.
        let reach = stack.max { $0.position.y < $1.position.y }!
            .visualBounds(relativeTo: nil).max.y
        #expect(reach <= highest.entryPosition.y + 0.005)
        #expect(reach >= highest.entryPosition.y - 0.06)
        // Foot of the stack plants in the mat (−0.03), not hovering over it.
        let foot = stack.min { $0.position.y < $1.position.y }!
            .visualBounds(relativeTo: nil).min.y
        #expect(foot <= -0.025)
    }
}

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
