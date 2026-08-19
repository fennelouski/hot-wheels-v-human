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

    /// Every decoration the palette offers must load AND have a thumbnail
    /// — either missing leaves a dead button in the decoration box.
    @Test func decorationBoxIsFullyStocked() async {
        for (label, _, props) in DecorPaletteView.groups {
            for prop in props {
                let entity = await SceneryPlacer.entity(for: prop)
                #expect(entity != nil, "\(label): missing model \(prop)")
                #expect(Bundle.main.url(forResource: "thumb-\(prop)",
                                        withExtension: "png") != nil,
                        "\(label): missing thumbnail \(prop)")
            }
        }
    }

    /// The street autotiler: every neighbour pattern gets the right tile,
    /// and an orphan cell gets none — no roads to nowhere.
    @Test func streetTilesMatchConnectivity() {
        #expect(ArenaEnvironment.streetTile(north: true, south: true,
                                            east: true, west: true)?.0 == "street-cross")
        #expect(ArenaEnvironment.streetTile(north: false, south: true,
                                            east: true, west: true)?.0 == "street-tee")
        #expect(ArenaEnvironment.streetTile(north: true, south: true,
                                            east: false, west: false)?.0 == "street-straight")
        #expect(ArenaEnvironment.streetTile(north: false, south: true,
                                            east: true, west: false)?.0 == "street-bend")
        #expect(ArenaEnvironment.streetTile(north: true, south: false,
                                            east: false, west: false)?.0 == "street-end")
        #expect(ArenaEnvironment.streetTile(north: false, south: false,
                                            east: false, west: false) == nil)
    }

    /// City and Speedway streets carry traffic; the cars fade in from
    /// nothing (opacity 0 at spawn) so appearing never pops.
    @Test func cityStreetsCarryTraffic() async {
        for themeName in ["city", "speedway"] {
            let env = await ArenaEnvironment.make(
                for: UUID(), theme: themeName,
                around: FootprintRect(minX: -1, minZ: -1, maxX: 1, maxZ: 1))
            let cars = env.children.filter {
                $0.components[TrafficComponent.self] != nil }
            #expect(cars.count >= 2, "\(themeName)")
            #expect(cars.allSatisfy {
                $0.components[OpacityComponent.self]?.opacity == 0 })
        }
    }

    /// Cars respawn at road STARTS: a dead-end cell, driving toward its
    /// one neighbour — never parachuted into the middle of a block.
    @Test func trafficEntersAtRoadStarts() {
        // A straight road: (0,0)…(0,3). Starts are its two ends.
        let road: Set<SIMD2<Int32>> = [SIMD2(0, 0), SIMD2(0, 1),
                                       SIMD2(0, 2), SIMD2(0, 3)]
        var seed: UInt64 = 42
        for _ in 0..<10 {
            let start = TrafficSystem.roadStart(in: road, seed: &seed)
            #expect(start != nil)
            #expect(start!.cell == SIMD2(0, 0) || start!.cell == SIMD2(0, 3))
            #expect(road.contains(start!.cell &+ start!.direction))
        }
        // Isolated cells aren't roads — nobody spawns on them.
        #expect(TrafficSystem.roadStart(in: [SIMD2(9, 9)], seed: &seed) == nil)
    }

    /// A car placed on the grass gets a seek target: the nearest
    /// connected road cell; with no roads it stays a parked prop.
    @Test func placedCarsSeekTheNearestRoad() async {
        let road: Set<SIMD2<Int32>> = [SIMD2(0, 0), SIMD2(0, 1), SIMD2(0, 2)]
        let items = [SceneryItem(model: "taxi", x: 2, z: 0.7, yaw: 0)]
        let root = await SceneryPlacer.spawn(items, autoStreets: road)
        let car = root.children[0]
        let traffic = car.components[TrafficComponent.self]
        #expect(traffic?.seeking == true)
        #expect(traffic?.cell == SIMD2(0, 1))     // nearest cell to (2, 0.7)
        // No roads → parked, no traffic behaviour.
        let parked = await SceneryPlacer.spawn(items)
        #expect(parked.children[0].components[TrafficComponent.self] == nil)
    }

    /// No roads anywhere: a placed car wanders instead of parking.
    @Test func roadlessCarsWander() async {
        let items = [SceneryItem(model: "firetruck", x: 1, z: 1, yaw: 0)]
        let root = await SceneryPlacer.spawn(items)
        let car = root.children[0]
        #expect(car.components[WanderComponent.self] != nil)
        #expect(car.components[TrafficComponent.self] == nil)
    }

    /// A person placed near hand-laid pavement follows the sidewalk
    /// network (turning around at ends); far from any pavement they keep
    /// the little patrol. A lone stepping stone is not a sidewalk.
    @Test func peopleFollowSidewalks() async {
        let items = [SceneryItem(model: "street-square", x: 0.7, z: 0, yaw: 0),
                     SceneryItem(model: "street-square", x: 1.4, z: 0, yaw: 0),
                     SceneryItem(model: "person-a", x: 0.8, z: 0.3, yaw: 0),
                     SceneryItem(model: "person-b", x: 9, z: 9, yaw: 0),
                     SceneryItem(model: "city-path-short", x: 5, z: 5, yaw: 0)]
        let root = await SceneryPlacer.spawn(items)
        let nearPerson = root.children[2]
        #expect(nearPerson.components[PedestrianComponent.self]?.seeking == true)
        let farPerson = root.children[3]
        #expect(farPerson.components[PedestrianComponent.self] == nil)
        #expect(farPerson.components[WalkerComponent.self] != nil)
    }

    /// Hand-laid street tiles extend the traffic graph (0.7 m snap).
    @Test func handLaidTilesJoinTheStreetGraph() {
        let items = [SceneryItem(model: "street-straight", x: 1.4, z: 0, yaw: 0),
                     SceneryItem(model: "street-end", x: 2.1, z: 0, yaw: 0),
                     SceneryItem(model: "city-house-a", x: 0.7, z: 0.7, yaw: 0)]
        let cells = SceneryPlacer.handStreetCells(in: items)
        #expect(cells == [SIMD2(2, 0), SIMD2(3, 0)])
    }

    /// Placed sky-stuff floats and turns; a nebula never spins (it's a
    /// billboard — spinning would fight the facing).
    @Test func placedPlanetsFloatAndTurn() async {
        let items = [SceneryItem(model: "space-planet-rings", x: 1, z: 1, yaw: 0),
                     SceneryItem(model: "space-nebula-pink", x: 2, z: 2, yaw: 0)]
        let root = await SceneryPlacer.spawn(items)
        #expect(root.children.count == 2)
        let planet = root.children[0]
        #expect(planet.position.y > 0.5)
        #expect((planet.components[AmbientMotionComponent.self]?.spin ?? 0) > 0)
        let nebula = root.children[1]
        #expect(nebula.position.y > 1)
        #expect(nebula.components[AmbientMotionComponent.self]?.spin == 0)
    }

    /// Placed people walk; everything else placed stays put unless it's a
    /// bobber/swayer by nature.
    @Test func placedPeopleWalk() async {
        let items = [SceneryItem(model: "person-a", x: 1, z: 2, yaw: 0),
                     SceneryItem(model: "pirate-ship-small", x: 3, z: 0, yaw: 0),
                     SceneryItem(model: "city-house-a", x: 0, z: 0, yaw: 0)]
        let root = await SceneryPlacer.spawn(items)
        #expect(root.children.count == 3)
        #expect(root.children[0].components[WalkerComponent.self] != nil)
        #expect((root.children[1].components[AmbientMotionComponent.self]?
            .bobAmplitude ?? 0) > 0)
        #expect(root.children[2].components[AmbientMotionComponent.self] == nil)
        #expect(root.children[2].components[WalkerComponent.self] == nil)
    }

    /// Coins spin, spacecraft bob, cones and boxes hold still — a
    /// spinning traffic cone reads as a glitch. The motion itself is the
    /// system's; what's checked is that the right props get tagged.
    @Test func ambientMotionTagsTheRightProps() async {
        let spaceID = UUID(uuidString: "90000000-0000-0000-0000-000000000003")!
        #expect(ArenaEnvironment.theme(named: nil, for: spaceID).name == "space")

        let env = await ArenaEnvironment.make(
            for: spaceID,
            around: FootprintRect(minX: -1, minZ: -1, maxX: 1, maxZ: 1))
        let coins = env.children.filter { $0.name.contains("coin") }
        let speeders = env.children.filter { $0.name.contains("speeder") }
        let craters = env.children.filter { $0.name.contains("crater") }
        #expect(!coins.isEmpty && !speeders.isEmpty && !craters.isEmpty)
        #expect(coins.allSatisfy {
            ($0.components[AmbientMotionComponent.self]?.spin ?? 0) > 0 })
        #expect(speeders.allSatisfy {
            ($0.components[AmbientMotionComponent.self]?.bobAmplitude ?? 0) > 0 })
        #expect(craters.allSatisfy {
            $0.components[AmbientMotionComponent.self] == nil })
    }

    /// City worlds lay streets now: road tiles on every third grid line,
    /// buildings snapped to the grid between them.
    @Test func cityLaysStreetsAndBlocks() async {
        let env = await ArenaEnvironment.make(
            for: UUID(), theme: "city",
            around: FootprintRect(minX: -1, minZ: -1, maxX: 1, maxZ: 1))
        let tiles = env.children.filter { $0.name == "street-tile" }
        // Near the track only — the horizon ring reuses city-* models
        // way out at radius 31+, deliberately off-grid.
        let buildings = env.children.filter {
            $0.name.hasPrefix("city-") && simd_length($0.position) < 20
        }
        #expect(tiles.count > 30)
        #expect(buildings.count > 20)
        for building in buildings {
            // Distance to the nearest grid multiple — a plain remainder
            // check reads 0.699… for Float multiples like 3 × 0.7.
            let dx = abs(building.position.x - (building.position.x / 0.7).rounded() * 0.7)
            let dz = abs(building.position.z - (building.position.z / 0.7).rounded() * 0.7)
            #expect(dx < 0.01 && dz < 0.01, "\(building.name)")
        }
    }

    /// Empty world: theme look only — no props, no streets, no horizon.
    @Test func emptyWorldHasNoStuff() async {
        let env = await ArenaEnvironment.make(
            for: UUID(), theme: "city", empty: true,
            around: FootprintRect(minX: -1, minZ: -1, maxX: 1, maxZ: 1))
        #expect(!env.children.contains { $0.name == "street-tile" })
        #expect(!env.children.contains { $0.name.hasPrefix("city-") })
        // Sky + terrain + physics floor are still there.
        #expect(env.children.count >= 3)
    }

    /// Winter's train exists and is parked on its ellipse ready to move.
    @Test func winterHasATrain() async {
        let env = await ArenaEnvironment.make(
            for: UUID(), theme: "winter",
            around: FootprintRect(minX: -1, minZ: -1, maxX: 1, maxZ: 1))
        let cars = env.children.filter {
            $0.components[TrainCarComponent.self] != nil }
        #expect(cars.count == 3)
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
