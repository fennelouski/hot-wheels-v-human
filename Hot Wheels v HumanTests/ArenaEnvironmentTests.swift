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
    /// 0x90 + N and the theme is that mod 4. Kids remember which track is
    /// the space one — this pins the mapping against a reshuffle.
    @Test func starterTrackThemesAreStable() {
        func theme(_ n: Int) -> String {
            let id = UUID(uuidString: String(format: "90000000-0000-0000-0000-%012d", n))!
            return ArenaEnvironment.theme(for: id).name
        }
        #expect(theme(1) == "day")        // Wiggle Worm
        #expect(theme(2) == "sunset")     // Mount Kaboom
        #expect(theme(3) == "space")      // Loopy Louie
        #expect(theme(4) == "candy")      // Jumpy Junction
        #expect(ArenaEnvironment.theme(for: nil).name == "day")   // lobby
    }

    /// Coins turn, everything else holds still — a spinning traffic cone
    /// reads as a glitch. The rotation itself is RealityKit's; what's
    /// checked here is that the right props get tagged.
    @Test func onlyCoinPropsCarryTheSpin() async {
        let spaceID = UUID(uuidString: "90000000-0000-0000-0000-000000000003")!
        #expect(ArenaEnvironment.theme(for: spaceID).name == "space")

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
