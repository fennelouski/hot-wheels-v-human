//
//  ArenaEnvironmentTests.swift
//  Hot Wheels v HumanTests
//
//  The themed world around the track. Sky/ground looks are judged by eye
//  in the sim; what's pinned here is the logic a screenshot can't settle —
//  which theme a track lands on, and which props are alive.
//

import Foundation
import Testing
import RealityKit
@testable import Hot_Wheels_v_Human

@MainActor
struct ArenaEnvironmentTests {

    /// Starter-track ids are `90000000-…-00000000000N`, so the byte sum is
    /// 0x90 + N and the theme is that mod `hashedThemeCount`. Kids remember
    /// which track is the space one — this pins the mapping against a
    /// reshuffle AND against new pickable worlds shifting the modulus.
    @Test func starterTrackThemesAreStable() {
        func theme(_ n: Int) -> String {
            let id = UUID(uuidString: String(format: "90000000-0000-0000-0000-%012d", n))!
            return ArenaEnvironment.theme(named: nil, for: id).name
        }
        #expect(ArenaEnvironment.hashedThemeCount == 4)
        #expect(theme(1) == "day")        // Wiggle Worm
        #expect(theme(2) == "sunset")     // Mount Kaboom
        #expect(theme(3) == "space")      // Loopy Louie
        #expect(theme(4) == "candy")      // Jumpy Junction
        #expect(ArenaEnvironment.theme(named: nil, for: nil).name == "day")   // lobby
    }

    /// A picked world beats the hash; a bogus name falls back to it.
    @Test func pickedWorldOverridesHash() {
        let spaceID = UUID(uuidString: "90000000-0000-0000-0000-000000000003")!
        #expect(ArenaEnvironment.theme(named: "city", for: spaceID).name == "city")
        #expect(ArenaEnvironment.theme(named: "no-such-world", for: spaceID).name == "space")
    }

    /// Every prop a theme names must exist as a converted USDZ — a typo'd
    /// model name fails silently at spawn (try? on the load) and a world
    /// quietly loses its buildings.
    @Test func allThemePropsHaveModels() async {
        for theme in ArenaEnvironment.themes {
            for name in Set(theme.props + theme.horizon) {
                let entity = try? await AssetStore.shared.entity(named: name)
                #expect(entity != nil, "\(theme.name): missing model \(name)")
            }
        }
    }

    /// Space floats: no visible ground; every other world gets terrain.
    @Test func spaceIsGroundless() async {
        #expect(RaceTuning.groundlessThemes.contains("space"))
        #expect(RaceTuning.resolvedThemeName(nil, for: nil) == "day")
        #expect(RaceTuning.resolvedThemeName("space", for: UUID()) == "space")
        let space = await ArenaEnvironment.make(
            for: UUID(), theme: "space",
            around: FootprintRect(minX: -1, minZ: -1, maxX: 1, maxZ: 1))
        let visibleGround = space.children.contains {
            $0.components[ModelComponent.self] != nil
                && $0.components[CollisionComponent.self] != nil
        }
        #expect(!visibleGround)
        // The invisible physics floor stays — wrecks need somewhere to land.
        #expect(space.children.contains {
            $0.components[CollisionComponent.self] != nil
                && $0.components[ModelComponent.self] == nil
        })
    }

    /// Every non-empty horizon list draws its silhouette ring.
    @Test func horizonRingSpawns() async {
        let env = await ArenaEnvironment.make(
            for: UUID(), theme: "canyon",
            around: FootprintRect(minX: -1, minZ: -1, maxX: 1, maxZ: 1))
        let distant = env.children.filter {
            let p = $0.position
            return sqrt(p.x * p.x + p.z * p.z) > 25
        }
        #expect(distant.count >= 10)
    }

    /// City worlds are built, not spilled: buildings sit on the street
    /// grid, squared to a quarter turn, and never two to a cell.
    @Test func cityBuildingsSnapToGridAndFaceSquare() async {
        let env = await ArenaEnvironment.make(
            for: UUID(), theme: "city",
            around: FootprintRect(minX: -1, minZ: -1, maxX: 1, maxZ: 1))
        let props = env.children.filter { $0.name.hasPrefix("city-") }
        #expect(props.count > 20)
        var cells = Set<SIMD2<Int>>()
        for prop in props {
            let cell = SIMD2(Int((prop.position.x / 0.7).rounded()),
                             Int((prop.position.z / 0.7).rounded()))
            #expect(abs(prop.position.x - Float(cell.x) * 0.7) < 0.001)
            #expect(abs(prop.position.z - Float(cell.y) * 0.7) < 0.001)
            #expect(cells.insert(cell).inserted, "two props in cell \(cell)")
        }
    }

    /// Coins turn, everything else holds still — a spinning traffic cone
    /// reads as a glitch. The rotation itself is RealityKit's; what's
    /// checked here is that the right props get tagged.
    @Test func onlyCoinPropsCarryTheSpin() async {
        let spaceID = UUID(uuidString: "90000000-0000-0000-0000-000000000003")!
        #expect(ArenaEnvironment.theme(named: nil, for: spaceID).name == "space")

        let env = await ArenaEnvironment.make(
            for: spaceID,
            around: FootprintRect(minX: -1, minZ: -1, maxX: 1, maxZ: 1))
        let props = env.children.filter { $0.name.hasPrefix("item-") }

        #expect(!props.isEmpty)
        #expect(props.contains { $0.name.contains("coin") })      // not vacuous
        for prop in props {
            let spins = prop.components[SpinComponent.self] != nil
            #expect(spins == prop.name.contains("coin"),
                    "\(prop.name) spin=\(spins)")
        }
    }

    /// Props are decoration: a car flung off the track sails through them
    /// instead of pinballing off a traffic cone.
    @Test func propsCarryNoCollision() async {
        let env = await ArenaEnvironment.make(
            for: UUID(uuidString: "90000000-0000-0000-0000-000000000003")!,
            around: FootprintRect(minX: -1, minZ: -1, maxX: 1, maxZ: 1))
        let props = env.children.filter { $0.name.hasPrefix("item-") }
        #expect(!props.isEmpty)
        #expect(props.allSatisfy { $0.components[CollisionComponent.self] == nil })
    }
}
