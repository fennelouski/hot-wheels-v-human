//
//  TunnelTests.swift
//  Hot Wheels v HumanTests
//
//  A track that digs gets a tunnel you can see: an arch where the bed
//  crosses the ground going down, another where it comes back up, and
//  lamps along the buried run. These pin the PLACEMENT — the arch has to
//  land on the seam where the bed is actually at ground level, or it
//  floats in mid-air at one end and is buried in dirt at the other.
//

import Foundation
import RealityKit
import Testing
import simd
@testable import Hot_Wheels_v_Human

private func blueprint(_ types: [PieceType]) -> TrackBlueprint {
    TrackBlueprint(trackId: UUID(), lanes: 2,
                   segments: types.enumerated().map {
                       SegmentSpec(index: $0.offset, type: $0.element) })
}

private func layout(_ types: [PieceType]) -> TrackLayout {
    TrackLayoutSolver.solve(blueprint(types))
}

struct TunnelPlanTests {

    /// The plain dig: dive, cruise, climb out. One arch in, one arch out,
    /// both standing at ground level — that's the whole feature in one
    /// assertion.
    @Test func aDigGetsAnArchAtEachEnd() {
        let mouths = TunnelPlan.mouths(in: layout(
            [.startGate, .hillDown, .straight, .hillUp, .finishGate]))
        #expect(mouths.count == 2)
        #expect(mouths.filter(\.isEntrance).count == 1)
        #expect(mouths.filter { !$0.isEntrance }.count == 1)
        // Both mouths sit ON the ground: that's what makes them a hole in
        // a hillside rather than a ring floating over/under one.
        for mouth in mouths {
            #expect(abs(mouth.position.y) < 1e-5)
        }
        // The entrance is the dive ramp's entry, the exit the climb's exit.
        let entrance = mouths.first(where: \.isEntrance)!
        #expect(entrance.position == SIMD3<Float>(0, 0, 0.8))
    }

    /// The arch has to land exactly where the NEXT piece starts, or there
    /// is a visible seam between the mouth and the track through it.
    @Test func theExitArchLandsOnTheSeamTheNextPieceStartsFrom() {
        let solved = layout([.startGate, .hillDown, .straight, .hillUp, .finishGate])
        let exit = TunnelPlan.mouths(in: solved).first { !$0.isEntrance }!
        let finishGate = solved.pieces[4]
        #expect(simd_length(exit.position - finishGate.entryPosition) < 1e-5)
        #expect(abs(exit.yaw - finishGate.entryYaw) < 1e-5)
    }

    /// A RUN of hills is not a stack of solo hills — the solver resolves
    /// it into `hill-beginning` / pitched middles / `hill-end`, and the
    /// middles drop TWO levels each over a shorter advance. The mouth
    /// still belongs on the first piece's entry, which is the only place
    /// the bed is at ground level.
    @Test func aMultiLevelDigStillPutsTheArchOnTheSurface() {
        for digs in 2...4 {
            let types: [PieceType] = [.startGate]
                + Array(repeating: .hillDown, count: digs)
                + [.straight, .finishGate]
            let mouths = TunnelPlan.mouths(in: layout(types))
            let entrance = mouths.first(where: \.isEntrance)
            #expect(entrance != nil, "\(digs) hillDowns: no entrance arch")
            #expect(abs(entrance?.position.y ?? 1) < 1e-5,
                    "\(digs) hillDowns: arch is not at ground level")
            // Nothing climbs back out, so there is no exit arch.
            #expect(mouths.contains { !$0.isEntrance } == false)
        }
    }

    /// Two tunnels on one track are two tunnels, not one big one.
    @Test func separateDigsEachGetTheirOwnPair() {
        let mouths = TunnelPlan.mouths(in: layout(
            [.startGate, .hillDown, .straight, .hillUp,
             .straight, .straight,
             .hillDown, .straight, .hillUp, .finishGate]))
        #expect(mouths.filter(\.isEntrance).count == 2)
        #expect(mouths.filter { !$0.isEntrance }.count == 2)
    }

    /// A track that never surfaces has no hillside to punch through, so
    /// an arch would just hang in the dirt. No crossing, no arch.
    @Test func aTrackThatNeverSurfacesGetsNoArch() {
        // Level ground the whole way: nothing is underground at all.
        #expect(TunnelPlan.mouths(in: layout(
            [.startGate, .straight, .straight, .finishGate])).isEmpty)
        // Dug in and left there: an entrance, but no exit arch.
        let oneWay = TunnelPlan.mouths(in: layout(
            [.startGate, .hillDown, .straight, .finishGate]))
        #expect(oneWay.count == 1)
        #expect(oneWay[0].isEntrance)
    }

    /// The dirt mounds over pieces buried at BOTH ends. Mounding the dive
    /// ramp too — which is what it used to do — buries the very hole the
    /// car drives into.
    @Test func theDirtMoundsOverTheBuriedRunButNotTheRamps() {
        let solved = layout([.startGate, .hillDown, .straight, .hillUp, .finishGate])
        let mounded = TunnelPlan.moundFootprints(in: solved)
        // Only the middle straight is buried at both ends.
        #expect(mounded.count == 1)
        let straight = solved.pieces[2]
        #expect(mounded[0] == straight.worldFootprint)
        // The ramps ARE underground — they're just not fully buried.
        #expect(TunnelPlan.isUnderground(solved.pieces[1]))
        #expect(!TunnelPlan.isFullyUnderground(solved.pieces[1]))
        #expect(TunnelPlan.isFullyUnderground(straight))
    }

    /// The point of excluding the ramps: the dome has to reach zero AT
    /// the mouth, or the arch is swallowed by the hill it stands in.
    /// The two distances are equal by construction — this is the check
    /// that says so out loud, for a solo dig and for a hill run.
    @Test func theDirtDomeReachesZeroAtTheArch() {
        for digs in 1...3 {
            let types: [PieceType] = [.startGate]
                + Array(repeating: .hillDown, count: digs)
                + [.straight, .straight, .finishGate]
            let solved = layout(types)
            let entrance = TunnelPlan.mouths(in: solved).first(where: \.isEntrance)!
            let mounds = TunnelPlan.moundFootprints(in: solved).map { rect in
                ArenaEnvironment.TunnelMound(
                    center: SIMD2((rect.minX + rect.maxX) / 2,
                                  (rect.minZ + rect.maxZ) / 2),
                    radius: max(rect.maxX - rect.minX, rect.maxZ - rect.minZ) / 2 + 0.8)
            }
            // Without this the check is vacuous: no mounds at all also
            // measures zero at the arch.
            #expect(!mounds.isEmpty, "\(digs) hillDowns: nothing was mounded")
            let flat = FootprintRect(minX: -9, minZ: -9, maxX: 9, maxZ: 9)
            let height = ArenaEnvironment.terrainHeight(
                x: entrance.position.x, z: entrance.position.z,
                flat: flat, mounds: mounds)
            #expect(height < 0.02, "\(digs) hillDowns: dirt is \(height) m deep at the arch")
        }
    }

    /// The shallowest possible dig — straight down and straight back up,
    /// with nothing buried in between. It still gets both arches, and it
    /// gets NO dirt mound, because no piece is buried at both ends. That
    /// is the intended trade: a one-down-one-up dip is a dip, not a
    /// tunnel through a hill, and mounding its ramps would bury the two
    /// arches that are the whole point.
    @Test func aDipWithNoBuriedMiddleGetsArchesButNoHill() {
        let solved = layout([.startGate, .hillDown, .hillUp, .finishGate])
        let mouths = TunnelPlan.mouths(in: solved)
        #expect(mouths.count == 2)
        #expect(mouths.filter(\.isEntrance).count == 1)
        for mouth in mouths { #expect(abs(mouth.position.y) < 1e-5) }
        #expect(TunnelPlan.moundFootprints(in: solved).isEmpty)
    }

    /// Lamps hang over the buried bed, spaced along it — and nowhere else.
    @Test func lampsHangOverTheBuriedRunOnly() {
        let solved = layout([.startGate, .hillDown, .straight, .straight,
                             .hillUp, .finishGate])
        let lamps = TunnelPlan.lamps(in: solved)
        #expect(!lamps.isEmpty)
        for lamp in lamps {
            // Hung the lamp height over a bed that is itself below ground.
            #expect(lamp.position.y < RaceTuning.tunnelLampHeight)
            #expect(abs(simd_length(lamp.up) - 1) < 1e-4)
            #expect(abs(simd_dot(lamp.up, lamp.forward)) < 1e-4)
        }
        // Level track has nothing to light.
        #expect(TunnelPlan.lamps(in: layout(
            [.startGate, .straight, .straight, .finishGate])).isEmpty)
    }

    /// Spacing is arc length down the run, so a long dig gets more lamps
    /// than a short one instead of the same handful stretched out.
    @Test func lampsAreSpacedDownTheRun() {
        func lampCount(buried: Int) -> Int {
            let types: [PieceType] = [.startGate, .hillDown]
                + Array(repeating: .straight, count: buried)
                + [.hillUp, .finishGate]
            return TunnelPlan.lamps(in: layout(types)).count
        }
        let short = lampCount(buried: 1), long = lampCount(buried: 5)
        #expect(long > short)
        // Roughly one per `tunnelLampSpacing` of the four extra straights.
        let expected = Float(4) * 0.8 / RaceTuning.tunnelLampSpacing
        #expect(abs(Float(long - short) - expected) <= 1)

        // No two lamps land on top of each other.
        let lamps = TunnelPlan.lamps(in: layout(
            [.startGate, .hillDown] + Array(repeating: .straight, count: 5)
            + [.hillUp, .finishGate]))
        for (a, b) in zip(lamps, lamps.dropFirst()) {
            #expect(simd_distance(a.position, b.position)
                    > RaceTuning.tunnelLampSpacing * 0.5)
        }
    }

    /// A portal gap is a teleport, not track. No lamp may hang in it —
    /// the rail follower crosses it instantly, and a lamp out there would
    /// float in open space between two rings.
    @Test func noLampHangsInAPortalGap() {
        var segments = [PieceType.startGate, .hillDown, .straight,
                        .portalIn, .portalOut, .straight, .hillUp, .finishGate]
            .enumerated()
            .map { SegmentSpec(index: $0.offset, type: $0.element) }
        // Send the exit ring well off to the side.
        segments[4] = SegmentSpec(index: 4, type: .portalOut, portalX: 6, portalZ: 6)
        let solved = TrackLayoutSolver.solve(
            TrackBlueprint(trackId: UUID(), lanes: 2, segments: segments))
        #expect(!solved.lanes.teleports.isEmpty)   // not a vacuous test
        let lamps = TunnelPlan.lamps(in: solved)
        for index in solved.lanes.teleports {
            let a = solved.lanes.center[index], b = solved.lanes.center[index + 1]
            let gap = simd_distance(a, b)
            for lamp in lamps {
                // Nothing may sit strictly between the two ends of a jump.
                let along = simd_distance(a, lamp.position)
                    + simd_distance(lamp.position, b)
                #expect(along > gap + 0.05,
                        "a lamp is stranded inside the portal jump")
            }
        }
    }

    /// The lamp walk indexes `lanes.center`, `pieceStartIndices` and
    /// `laterals` together, and those don't line up as simply as they
    /// look: `pieceStartIndices` is appended BEFORE duplicate joint
    /// waypoints are dropped, so a piece can contribute none at all and
    /// the last piece's end has to be clamped. Fuzz it rather than argue
    /// about it — every shipped preset plus 300 random tracks, checking
    /// it doesn't crash and that what comes out is sane.
    @Test func mouthsAndLampsSurviveEveryTrackWeCanThrowAtThem() {
        var blueprints = TrackBlueprint.presets.map(\.1)
        for i in 0..<300 {
            blueprints.append(RandomTrackGenerator.generate(pieceCount: 3 + i % 12))
        }
        for bp in blueprints {
            let solved = TrackLayoutSolver.solve(bp)
            for mouth in TunnelPlan.mouths(in: solved) {
                #expect(mouth.position.y.isFinite)
                #expect(mouth.yaw.isFinite)
                // An arch only ever stands where the bed meets the ground.
                #expect(abs(mouth.position.y) < 1e-4)
            }
            for lamp in TunnelPlan.lamps(in: solved) {
                #expect(lamp.position.x.isFinite && lamp.position.y.isFinite
                        && lamp.position.z.isFinite)
                // Never above the ground it is supposed to be lighting under.
                #expect(lamp.position.y <= 0)
                #expect(abs(simd_length(lamp.up) - 1) < 1e-3)
                #expect(abs(simd_length(lamp.forward) - 1) < 1e-3)
                #expect(abs(lamp.side) == 1)
            }
        }
    }

    /// Ghost pieces carry their ghostliness onto their tunnel — a piece
    /// you can't see, lit up by lamps you can, gives the trick away.
    @Test func aGhostPiecesTunnelIsGhostlyToo() {
        var segments = [PieceType.startGate, .hillDown, .straight, .hillUp, .finishGate]
            .enumerated()
            .map { SegmentSpec(index: $0.offset, type: $0.element) }
        segments[1] = SegmentSpec(index: 1, type: .hillDown, isGhost: true)
        let solved = TrackLayoutSolver.solve(
            TrackBlueprint(trackId: UUID(), lanes: 2, segments: segments))
        let entrance = TunnelPlan.mouths(in: solved).first(where: \.isEntrance)!
        #expect(entrance.isGhost)
        // The pieces past it are solid, so their lamps are too.
        #expect(TunnelPlan.lamps(in: solved).contains { !$0.isGhost })
    }
}

@MainActor
struct TunnelDressingTests {

    /// The spawned track carries the tunnel: arches and lamps, as DIRECT
    /// children of the root (which is where `setOpacity` looks), tagged
    /// as visuals, and carrying no collision — a car that flies off has
    /// to sail through an arch, not bounce off it.
    @Test func aDugTrackSpawnsArchesAndLampsWithNoCollision() async throws {
        let solved = TrackLayoutSolver.solve(blueprint(
            [.startGate, .hillDown, .straight, .straight, .hillUp, .finishGate]))
        let track = try await TrackSpawner.spawn(layout: solved)

        let arches = track.children.filter { $0.name.hasPrefix("tunnel-mouth-") }
        let lamps = track.children.filter { $0.name.hasPrefix("tunnel-lamp-") }
        #expect(arches.count == 2)
        #expect(!lamps.isEmpty)

        for dressing in arches + lamps {
            #expect(dressing.components[TrackVisualComponent.self] != nil)
            for part in [dressing] + dressing.children.map({ $0 }) {
                #expect(part.components[CollisionComponent.self] == nil)
                #expect(part.components[PhysicsBodyComponent.self] == nil)
            }
        }
        // The arch is a ring of stones, not one lonely brick.
        #expect(arches.allSatisfy { $0.children.count > 4 })
    }

    /// A level track spawns no tunnel at all — no stray entities, no
    /// wasted meshes.
    @Test func aLevelTrackSpawnsNoTunnel() async throws {
        let track = try await TrackSpawner.spawn(layout: TrackLayoutSolver.solve(
            blueprint([.startGate, .straight, .straight, .finishGate])))
        #expect(!track.children.contains { $0.name.hasPrefix("tunnel-") })
    }

    /// The arena's hide-track switch reaches the tunnel: a ghost dig goes
    /// dark with its piece rather than glowing on an invisible track.
    @Test func hidingAGhostPieceHidesItsTunnel() async throws {
        var segments = [PieceType.startGate, .hillDown, .straight, .hillUp, .finishGate]
            .enumerated()
            .map { SegmentSpec(index: $0.offset, type: $0.element) }
        for i in 1...3 { segments[i] = SegmentSpec(index: i, type: segments[i].type,
                                                   isGhost: true) }
        let track = try await TrackSpawner.spawn(layout: TrackLayoutSolver.solve(
            TrackBlueprint(trackId: UUID(), lanes: 2, segments: segments)))
        TrackSpawner.setOpacity(on: track, ghosts: 0)
        let dressing = track.children.filter { $0.name.hasPrefix("tunnel-") }
        #expect(!dressing.isEmpty)
        for entity in dressing {
            #expect(entity.components[OpacityComponent.self]?.opacity == 0)
        }
    }
}
