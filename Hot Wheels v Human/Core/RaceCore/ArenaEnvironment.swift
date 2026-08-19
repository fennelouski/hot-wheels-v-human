//
//  ArenaEnvironment.swift
//  Hot Wheels v Human
//
//  The world around the track: a sky dome + a big play-mat ground,
//  themed per track (candy / sunny day / sunset / outer space) so each starter
//  track feels like its own place. Theme is picked from the trackId —
//  stable across launches, no data added to the wire format.
//
//  Everything is procedural (CoreGraphics → TextureResource): no new
//  assets, identical on iPad and TV. Sizes are visual-only constants —
//  the ground must outsize the biggest buildable track (75 straights
//  = 60 m) so cars never race off the edge of the world.
//

import CoreGraphics
import Foundation
import RealityKit

/// Idle life for decorations — coins spin, ships and spacecraft bob and
/// roll, flags and trees sway. One component, driven by sines off a
/// per-entity phase so nothing pulses in unison. (Grew out of the old
/// coin-only SpinComponent; spin is deliberately not an OrbitAnimation —
/// that orbits a centre, so at radius 0 nothing turns.)
struct AmbientMotionComponent: Component {
    var spin: Float = 0            // rad/s about +Y; exclusive with sway
    var bobAmplitude: Float = 0    // metres of vertical sine
    var bobRate: Float = 0         // rad/s
    var swayAngle: Float = 0       // roll wobble, radians
    var swayRate: Float = 0
    var phase: Float = 0
    var time: Float = 0
    var baseY: Float = 0
    var baseOrientation = simd_quatf(angle: 0, axis: [0, 1, 0])
}

struct AmbientMotionSystem: System {
    private static let query = EntityQuery(where: .has(AmbientMotionComponent.self))

    init(scene: Scene) {}

    func update(context: SceneUpdateContext) {
        let dt = Float(context.deltaTime)
        for entity in context.entities(matching: Self.query,
                                       updatingSystemWhen: .rendering) {
            guard var motion = entity.components[AmbientMotionComponent.self] else { continue }
            motion.time += dt
            let t = motion.time + motion.phase
            if motion.spin != 0 {
                entity.orientation *= simd_quatf(angle: motion.spin * dt,
                                                 axis: [0, 1, 0])
            } else if motion.swayAngle != 0 {
                let roll = sin(t * motion.swayRate) * motion.swayAngle
                entity.orientation = motion.baseOrientation
                    * simd_quatf(angle: roll, axis: [0, 0, 1])
            }
            if motion.bobAmplitude != 0 {
                entity.position.y = motion.baseY
                    + sin(t * motion.bobRate) * motion.bobAmplitude
            }
            entity.components.set(motion)
        }
    }
}

/// Which idle motion a prop model gets, if any. Shared by the theme
/// scatter, the horizon ring, and hand-placed scenery so a pirate ship
/// bobs no matter how it got there.
enum AmbientMotion {
    static func component(for model: String, vary: Float) -> AmbientMotionComponent? {
        var motion = AmbientMotionComponent(phase: vary * 6.28)
        if model.contains("coin") {
            motion.spin = 1.1 + vary * 0.7
        } else if model.hasPrefix("space-planet") || model == "space-moon" {
            // Placeable planets turn slowly and drift a little.
            motion.spin = 0.10 + vary * 0.08
            motion.bobAmplitude = 0.03
            motion.bobRate = 0.4 + vary * 0.3
        } else if model.hasPrefix("space-nebula") {
            // Billboarded — position-only motion, never fight the facing.
            motion.bobAmplitude = 0.05
            motion.bobRate = 0.3 + vary * 0.2
        } else if model.contains("ship") || model.contains("speeder")
                    || model.contains("ghost") || model.contains("astronaut")
                    || model == "space-racer" || model == "space-alien" {
            motion.bobAmplitude = 0.02 + vary * 0.02
            motion.bobRate = 0.7 + vary * 0.5
            motion.swayAngle = 0.04
            motion.swayRate = 0.5 + vary * 0.4
        } else if model.contains("flag") {
            motion.swayAngle = 0.1
            motion.swayRate = 2.0 + vary
        } else if model.contains("palm") || model.contains("tree")
                    || model.contains("pine") {
            motion.swayAngle = 0.025
            motion.swayRate = 1.2 + vary * 0.6
        } else {
            return nil
        }
        return motion
    }

    /// Stamp `entity` (already positioned + oriented) with its motion.
    static func apply(to entity: Entity, model: String, vary: Float) {
        guard var motion = component(for: model, vary: vary) else { return }
        motion.baseY = entity.position.y
        motion.baseOrientation = entity.orientation
        entity.components.set(motion)
    }
}

/// A placed person strolling their sidewalk: walk `halfLength` out along
/// the patrol axis, turn on a dime (it's a toy), walk back.
struct WalkerComponent: Component {
    var origin: SIMD3<Float>
    var yaw: Float
    var halfLength: Float = 0.45
    var speed: Float = 0.07
    var time: Float = 0
}

struct WalkerSystem: System {
    private static let query = EntityQuery(where: .has(WalkerComponent.self))

    init(scene: Scene) {}

    func update(context: SceneUpdateContext) {
        let dt = Float(context.deltaTime)
        for entity in context.entities(matching: Self.query,
                                       updatingSystemWhen: .rendering) {
            guard var walker = entity.components[WalkerComponent.self] else { continue }
            walker.time += dt
            let lap = 4 * walker.halfLength
            let along = (walker.time * walker.speed)
                .truncatingRemainder(dividingBy: lap)
            let outbound = along < 2 * walker.halfLength
            let s = outbound ? along - walker.halfLength
                             : 3 * walker.halfLength - along
            let dir = SIMD3<Float>(sin(walker.yaw), 0, cos(walker.yaw))
            entity.position = walker.origin + dir * s
            entity.orientation = simd_quatf(
                angle: outbound ? walker.yaw : walker.yaw + .pi, axis: [0, 1, 0])
            entity.components.set(walker)
        }
    }
}

/// A little car driving the city's street grid: keeps to the right lane,
/// pauses at intersections like a stop sign, brakes for anyone walking
/// nearby, and when a road just ends, fades out and reappears on some
/// other street (a toy city has no need for three-point turns).
struct TrafficComponent: Component {
    var cells: Set<SIMD2<Int32>>   // the street graph, in grid coords
    var cell: SIMD2<Int32>         // cell being driven FROM
    var direction: SIMD2<Int32>    // grid step toward the next cell
    var progress: Float = 0        // 0…1 across the current cell edge
    var speed: Float = 0.35        // m/s
    var pause: Float = 0           // stop-sign timer
    var opacity: Float = 0         // fades in on spawn / out at dead ends
    var fading: Bool = false
    /// Off-road start (a car placed on the grass): bee-line for `cell`,
    /// then join the network and stay on it.
    var seeking: Bool = false
    var worldPos: SIMD3<Float> = .zero
    /// Barrier-road cells (hand-placed `street-barrier-*` tiles): a road
    /// end with a barrier is a TURN-AROUND, not a fade-out — the car
    /// respects the roadblock and heads back the way it came.
    var barriers: Set<SIMD2<Int32>> = []
    var seed: UInt64
}

struct TrafficSystem: System {
    private static let cars = EntityQuery(where: .has(TrafficComponent.self))
    private static let walkers = EntityQuery(where: .has(WalkerComponent.self))
    private static let strollers = EntityQuery(where: .has(PedestrianComponent.self))
    private static let step: Float = 0.7

    init(scene: Scene) {}

    func update(context: SceneUpdateContext) {
        let dt = Float(context.deltaTime)
        var pedestrians: [SIMD3<Float>] = []
        for walker in context.entities(matching: Self.walkers,
                                       updatingSystemWhen: .rendering) {
            pedestrians.append(walker.position)
        }
        for stroller in context.entities(matching: Self.strollers,
                                         updatingSystemWhen: .rendering) {
            pedestrians.append(stroller.position)
        }
        for entity in context.entities(matching: Self.cars,
                                       updatingSystemWhen: .rendering) {
            guard var car = entity.components[TrafficComponent.self] else { continue }
            defer {
                entity.components.set(car)
                entity.components.set(OpacityComponent(opacity: car.opacity))
            }
            if car.seeking {
                // Placed on the grass: drive straight for the nearest
                // road cell, then merge into traffic.
                car.opacity = min(1, car.opacity + dt * 2)
                let target = SIMD3<Float>(Float(car.cell.x) * Self.step, -0.02,
                                          Float(car.cell.y) * Self.step)
                let delta = target - car.worldPos
                let distance = simd_length(delta)
                if distance < max(0.02, car.speed * dt) {
                    car.seeking = false
                    car.progress = 0
                    if let next = Self.exit(from: car.cell, cells: car.cells,
                                            avoid: nil, seed: &car.seed) {
                        car.direction = next
                    } else {
                        car.fading = true
                    }
                } else {
                    let heading = delta / distance
                    car.worldPos += heading * (car.speed * dt)
                    entity.position = car.worldPos
                    entity.orientation = simd_quatf(
                        angle: atan2(heading.x, heading.z), axis: [0, 1, 0])
                    continue
                }
            }
            let heading = SIMD3<Float>(Float(car.direction.x), 0, Float(car.direction.y))
            let lane = SIMD3<Float>(heading.z, 0, -heading.x) * -0.14  // right side
            let base = SIMD3<Float>(Float(car.cell.x) * Self.step, -0.02,
                                    Float(car.cell.y) * Self.step)
            entity.position = base + heading * (car.progress * Self.step) + lane
            entity.orientation = simd_quatf(angle: atan2(heading.x, heading.z),
                                            axis: [0, 1, 0])

            if car.fading {
                car.opacity = max(0, car.opacity - dt * 2)
                if car.opacity == 0 {
                    // The SAME car reappears at the start of another
                    // road (a dead-end tile) and drives in from there.
                    guard let start = Self.roadStart(in: car.cells,
                                                     seed: &car.seed) else { continue }
                    car.cell = start.cell
                    car.direction = start.direction
                    car.progress = 0
                    car.fading = false
                }
                continue
            }
            car.opacity = min(1, car.opacity + dt * 2)
            if car.pause > 0 {
                car.pause -= dt
                continue
            }
            // Brake for anyone strolling just ahead of the bumper.
            let lookahead = entity.position + heading * 0.22
            if pedestrians.contains(where: { simd_length($0 - lookahead) < 0.3 }) {
                continue
            }
            car.progress += car.speed * dt / Self.step
            if car.progress >= 1 {
                car.progress -= 1
                car.cell &+= car.direction
                let neighbours = Self.degree(of: car.cell, cells: car.cells)
                if neighbours >= 3 { car.pause = 0.6 }   // stop sign
                if let next = Self.exit(from: car.cell, cells: car.cells,
                                        avoid: car.direction &* -1, seed: &car.seed) {
                    car.direction = next
                } else if car.barriers.contains(car.cell) {
                    // A barrier road: turn around and drive back.
                    car.direction = car.direction &* -1
                } else {
                    car.fading = true                    // road ends here
                }
            }
        }
    }

    fileprivate static let compass: [SIMD2<Int32>] = [
        SIMD2(0, 1), SIMD2(0, -1), SIMD2(1, 0), SIMD2(-1, 0),
    ]

    fileprivate static func degree(of cell: SIMD2<Int32>,
                                   cells: Set<SIMD2<Int32>>) -> Int {
        compass.filter { cells.contains(cell &+ $0) }.count
    }

    /// Where a car enters the network: a road START (dead-end cell,
    /// degree 1) facing its one neighbour, so cars appear at the
    /// beginning of a road and drive in. Falls back to any connected
    /// cell when the network is all loops; nil if there's no road at
    /// all worth driving (isolated cells don't count).
    static func roadStart(in cells: Set<SIMD2<Int32>>,
                          seed: inout UInt64) -> (cell: SIMD2<Int32>,
                                                  direction: SIMD2<Int32>)? {
        let connected = cells.filter { degree(of: $0, cells: cells) >= 1 }
        guard !connected.isEmpty else { return nil }
        let ends = connected.filter { degree(of: $0, cells: cells) == 1 }
        let pool = Array(ends.isEmpty ? connected : ends)
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        let cell = pool[Int(seed >> 33) % pool.count]
        guard let direction = exit(from: cell, cells: cells,
                                   avoid: nil, seed: &seed) else { return nil }
        return (cell, direction)
    }

    /// The road cell nearest a world position — where an off-road car
    /// should drive to join traffic. Nil when there are no roads.
    static func nearestCell(to position: SIMD3<Float>,
                            in cells: Set<SIMD2<Int32>>) -> SIMD2<Int32>? {
        let connected = cells.filter { degree(of: $0, cells: cells) >= 1 }
        return connected.min { a, b in
            let pa = SIMD2<Float>(Float(a.x), Float(a.y)) * step
            let pb = SIMD2<Float>(Float(b.x), Float(b.y)) * step
            let p = SIMD2<Float>(position.x, position.z)
            return simd_length_squared(pa - p) < simd_length_squared(pb - p)
        }
    }

    /// Pick where to go from `cell`, never doubling back (`avoid`).
    /// Prefers carrying straight on so traffic reads as going somewhere.
    fileprivate static func exit(from cell: SIMD2<Int32>, cells: Set<SIMD2<Int32>>,
                                 avoid: SIMD2<Int32>?, seed: inout UInt64) -> SIMD2<Int32>? {
        let options = compass.filter { $0 != avoid && cells.contains(cell &+ $0) }
        guard !options.isEmpty else { return nil }
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        if let ahead = avoid.map({ $0 &* -1 }), options.contains(ahead),
           (seed >> 33) % 10 < 6 {
            return ahead
        }
        return options[Int(seed >> 33) % options.count]
    }
}

/// A placed car with no road anywhere: it wanders — lazy curves near
/// where the kid set it down, leashed so it never drives off to the
/// mountains. The moment a track has roads, cars prefer those
/// (SceneryPlacer picks the component at spawn).
struct WanderComponent: Component {
    var origin: SIMD3<Float>
    var heading: Float
    var speed: Float = 0.22
    var leash: Float = 2.2
    var phase: Float = 0
    var time: Float = 0
}

struct WanderSystem: System {
    private static let query = EntityQuery(where: .has(WanderComponent.self))

    init(scene: Scene) {}

    func update(context: SceneUpdateContext) {
        let dt = Float(context.deltaTime)
        for entity in context.entities(matching: Self.query,
                                       updatingSystemWhen: .rendering) {
            guard var car = entity.components[WanderComponent.self] else { continue }
            car.time += dt
            let home = car.origin - entity.position
            let distance = simd_length(SIMD2(home.x, home.z))
            if distance > car.leash {
                // Past the leash: bend toward home.
                let homeYaw = atan2(home.x, home.z)
                var delta = homeYaw - car.heading
                while delta > .pi { delta -= 2 * .pi }
                while delta < -.pi { delta += 2 * .pi }
                car.heading += max(-1.2 * dt, min(1.2 * dt, delta))
            } else {
                // Meandering: a slow sine on the wheel.
                car.heading += sin(car.time * 0.6 + car.phase) * 0.8 * dt
            }
            let direction = SIMD3<Float>(sin(car.heading), 0, cos(car.heading))
            entity.position += direction * (car.speed * dt)
            entity.position.y = -0.02
            entity.orientation = simd_quatf(angle: car.heading, axis: [0, 1, 0])
            entity.components.set(car)
        }
    }
}

/// A placed person near a sidewalk (path stones or pavement squares):
/// same graph logic as the cars — walk the network, random turns at
/// junctions — but at the end of a sidewalk they just TURN AROUND and
/// walk back (people don't fade out; that would be alarming).
struct PedestrianComponent: Component {
    var cells: Set<SIMD2<Int32>>   // pavement graph, 0.35 m cells
    var cell: SIMD2<Int32>
    var direction: SIMD2<Int32>
    var progress: Float = 0
    var speed: Float = 0.07
    /// Metres beside the walked line on ROAD cells — everyone keeps to
    /// the road's sidewalk edge; hand-laid pavement is walked dead
    /// centre (the offset fades in and out between the two, `roadside`).
    var sideOffset: Float = 0
    /// Building cells (0.7 m street grid) beside the sidewalks. Each cell
    /// stepped past a building carries a 1-in-100 shopper's impulse.
    var buildings: Set<SIMD2<Int32>> = []
    /// The subset of `cells` that are road centrelines (where the side
    /// offset applies). Hand-laid pavement cells aren't in it.
    var roadside: Set<SIMD2<Int32>> = []
    var seeking: Bool = false
    var worldPos: SIMD3<Float> = .zero
    var seed: UInt64
    // Mid-visit state: walking to the door, browsing inside (invisible),
    // walking back out to `visitReturn` to resume the stroll.
    var visitDoor: SIMD3<Float>? = nil
    var visitReturn: SIMD3<Float> = .zero
    var inside: Float = 0
    var leaving: Bool = false
}

struct PedestrianSystem: System {
    private static let query = EntityQuery(where: .has(PedestrianComponent.self))
    static let step: Float = 0.35

    init(scene: Scene) {}

    func update(context: SceneUpdateContext) {
        let dt = Float(context.deltaTime)
        for entity in context.entities(matching: Self.query,
                                       updatingSystemWhen: .rendering) {
            guard var person = entity.components[PedestrianComponent.self] else { continue }
            defer { entity.components.set(person) }
            if person.visitDoor != nil {
                Self.visit(&person, entity: entity, dt: dt)
                continue
            }
            if person.seeking {
                let target = SIMD3<Float>(Float(person.cell.x) * Self.step, 0,
                                          Float(person.cell.y) * Self.step)
                let delta = target - person.worldPos
                let distance = simd_length(delta)
                if distance < max(0.01, person.speed * dt) {
                    person.seeking = false
                    person.progress = 0
                    if let next = TrafficSystem.exit(from: person.cell,
                                                     cells: person.cells,
                                                     avoid: nil, seed: &person.seed) {
                        person.direction = next
                    }
                } else {
                    let heading = delta / distance
                    person.worldPos += heading * (person.speed * dt)
                    entity.position = person.worldPos
                    entity.orientation = simd_quatf(
                        angle: atan2(heading.x, heading.z), axis: [0, 1, 0])
                    continue
                }
            }
            person.progress += person.speed * dt / Self.step
            if person.progress >= 1 {
                person.progress -= 1
                person.cell &+= person.direction
                // A shopper's impulse: 1 step in 100, if a building sits
                // right there beside the sidewalk, pop in for a browse.
                if !person.buildings.isEmpty {
                    person.seed = person.seed &* 6364136223846793005
                        &+ 1442695040888963407
                    let effective = person.roadside.contains(person.cell)
                        ? person.sideOffset : 0
                    if (person.seed >> 33) % 100 == 0,
                       let door = Self.doorBeside(
                           cell: person.cell, direction: person.direction,
                           sideOffset: effective,
                           buildings: person.buildings) {
                        person.visitDoor = door
                        person.visitReturn = Self.pavementPoint(
                            cell: person.cell, direction: person.direction,
                            progress: 0, sideOffset: effective)
                        person.leaving = false
                        continue
                    }
                }
                if let next = TrafficSystem.exit(from: person.cell,
                                                 cells: person.cells,
                                                 avoid: person.direction &* -1,
                                                 seed: &person.seed) {
                    person.direction = next
                } else {
                    // End of the sidewalk: turn around, walk back — and
                    // flip the side offset so they stay on the SAME edge
                    // instead of teleporting across the road.
                    person.direction = person.direction &* -1
                    person.sideOffset = -person.sideOffset
                }
            }
            let heading = SIMD3<Float>(Float(person.direction.x), 0,
                                       Float(person.direction.y))
            // The side offset only applies on road cells; crossing between
            // a road edge and hand-laid pavement it fades in over the
            // step instead of side-stepping.
            let hereOffset: Float = person.roadside.contains(person.cell)
                ? person.sideOffset : 0
            let nextOffset: Float =
                person.roadside.contains(person.cell &+ person.direction)
                ? person.sideOffset : 0
            entity.position = Self.pavementPoint(
                cell: person.cell, direction: person.direction,
                progress: person.progress,
                sideOffset: hereOffset + (nextOffset - hereOffset) * person.progress)
            entity.orientation = simd_quatf(angle: atan2(heading.x, heading.z),
                                            axis: [0, 1, 0])
        }
    }

    /// World position on the walked line: cell centre, plus progress along
    /// the heading, plus the sidewalk offset beside it.
    static func pavementPoint(cell: SIMD2<Int32>, direction: SIMD2<Int32>,
                              progress: Float, sideOffset: Float) -> SIMD3<Float> {
        let heading = SIMD3<Float>(Float(direction.x), 0, Float(direction.y))
        let side = SIMD3<Float>(heading.z, 0, -heading.x) * sideOffset
        return SIMD3<Float>(Float(cell.x) * step, 0, Float(cell.y) * step)
            + heading * (progress * step) + side
    }

    /// The building doorway beside a sidewalk step, if that block cell
    /// actually holds a building — nil over parks and open cells, so
    /// nobody fades out into thin air. On a road edge only the walked
    /// side counts; centre-walked pavement (offset 0) checks both sides.
    static func doorBeside(cell: SIMD2<Int32>, direction: SIMD2<Int32>,
                           sideOffset: Float,
                           buildings: Set<SIMD2<Int32>>) -> SIMD3<Float>? {
        let here = pavementPoint(cell: cell, direction: direction,
                                 progress: 0, sideOffset: sideOffset)
        let heading = SIMD3<Float>(Float(direction.x), 0, Float(direction.y))
        let signs: [Float] = sideOffset == 0 ? [1, -1]
                                             : [sideOffset > 0 ? 1 : -1]
        for sign in signs {
            let outward = SIMD3<Float>(heading.z, 0, -heading.x) * sign
            let candidate = here + outward * 0.5
            let building = SIMD2<Int32>(Int32((candidate.x / 0.7).rounded()),
                                        Int32((candidate.z / 0.7).rounded()))
            if buildings.contains(building) {
                return SIMD3<Float>(Float(building.x) * 0.7, 0,
                                    Float(building.y) * 0.7)
            }
        }
        return nil
    }

    /// Run one visit: walk to the door fading out, browse invisibly for a
    /// beat, walk back out fading in, resume the stroll.
    private static func visit(_ person: inout PedestrianComponent,
                              entity: Entity, dt: Float) {
        guard let door = person.visitDoor else { return }
        if person.inside > 0 {
            person.inside -= dt
            entity.components.set(OpacityComponent(opacity: 0))
            return
        }
        let target = person.leaving ? person.visitReturn : door
        let delta = target - entity.position
        let distance = simd_length(delta)
        if distance < max(0.01, person.speed * dt) {
            if person.leaving {
                person.visitDoor = nil        // back on the sidewalk
                entity.position = target
                entity.components.set(OpacityComponent(opacity: 1))
            } else {
                person.inside = 2.5           // browsing
                person.leaving = true
            }
            return
        }
        let heading = delta / distance
        entity.position += heading * (person.speed * dt)
        entity.orientation = simd_quatf(angle: atan2(heading.x, heading.z),
                                        axis: [0, 1, 0])
        // Fade with distance to the door — vanishing at the threshold
        // reads as stepping inside.
        let doorDistance = simd_length(door - entity.position)
        entity.components.set(OpacityComponent(
            opacity: min(1, doorDistance / 0.3)))
    }
}

/// X-ray ground: while any car is UNDER the terrain (an underground track
/// section, a tunnel through a hill) the ground fades to ~30% so the kid
/// never loses sight of their car. Fades back the moment everyone
/// surfaces. The builder forces the fade while a dug track is being built
/// (`forced`) — no cars there to trigger it.
struct GroundFadeComponent: Component {
    var forced: Float? = nil
    var opacity: Float = 1
}

struct GroundFadeSystem: System {
    private static let grounds = EntityQuery(where: .has(GroundFadeComponent.self))
    private static let cars = EntityQuery(where: .has(CarComponent.self))
    /// Visual-only numbers (same rule as the ground/sky constants).
    static let fadedOpacity: Float = 0.3
    private static let fadeRate: Float = 3

    init(scene: Scene) {}

    func update(context: SceneUpdateContext) {
        let dt = Float(context.deltaTime)
        var buried = false
        for car in context.entities(matching: Self.cars,
                                    updatingSystemWhen: .rendering) {
            if car.position(relativeTo: nil).y < -0.05 {
                buried = true
                break
            }
        }
        for ground in context.entities(matching: Self.grounds,
                                       updatingSystemWhen: .rendering) {
            guard var fade = ground.components[GroundFadeComponent.self] else { continue }
            let target = fade.forced ?? (buried ? Self.fadedOpacity : 1)
            fade.opacity += (target - fade.opacity) * min(1, Self.fadeRate * dt)
            ground.components.set(fade)
            ground.components.set(OpacityComponent(opacity: fade.opacity))
        }
    }
}

/// The Winter world's toy train, chugging an ellipse around the track.
struct TrainCarComponent: Component {
    var center: SIMD2<Float>
    var radius: SIMD2<Float>
    var angularSpeed: Float
    var angle: Float
}

struct TrainSystem: System {
    private static let query = EntityQuery(where: .has(TrainCarComponent.self))

    init(scene: Scene) {}

    func update(context: SceneUpdateContext) {
        let dt = Float(context.deltaTime)
        for entity in context.entities(matching: Self.query,
                                       updatingSystemWhen: .rendering) {
            guard var car = entity.components[TrainCarComponent.self] else { continue }
            car.angle += car.angularSpeed * dt
            entity.position = [car.center.x + car.radius.x * cos(car.angle), 0,
                               car.center.y + car.radius.y * sin(car.angle)]
            let tangentX = -car.radius.x * sin(car.angle)
            let tangentZ = car.radius.y * cos(car.angle)
            entity.orientation = simd_quatf(angle: atan2(tangentX, tangentZ),
                                            axis: [0, 1, 0])
            entity.components.set(car)
        }
    }
}

enum ArenaEnvironment {

    struct Theme {
        let name: String
        /// Kid-facing label + SF Symbol for the builder's world picker.
        let displayName: String
        let symbol: String
        let skyTop: CGColor
        let skyHorizon: CGColor
        let groundLight: CGColor
        let groundDark: CGColor
        let stars: Bool
        let clouds: Bool
        /// Trackside decoration models (Resources/Models3D), scattered
        /// around the track. Repeats weight the draw.
        let props: [String]
        /// City-style placement: props snap to a grid and face the track
        /// instead of landing anywhere at any angle — random yaw makes a
        /// building read as knocked over, not built.
        var structured: Bool = false
        var propCount: Int = 26
        /// Keep-out gap around the track bed. Props place by their CENTER,
        /// so themes with big props (ships, cliffs, grandstands) need more
        /// room or a hull overhangs the racing line.
        var clearance: Float = 0.35
        /// Oversized silhouettes ringed out at the horizon (skylines,
        /// mesas, galleons). Empty = no ring.
        var horizon: [String] = []
        var horizonScale: Float = 3
        /// Streets-and-blocks layout instead of loose scatter: a road
        /// grid with buildings filling the blocks, facing their street.
        var cityBlocks: Bool = false
        /// A toy train circles the track (Winter's signature move).
        var train: Bool = false
        /// Car models driving the street grid (cityBlocks worlds only).
        var traffic: [String] = []
        var trafficSpeed: Float = 0.35
    }

    /// Indexed by trackId byte-sum for tracks with no chosen world —
    /// order matters, don't shuffle (kids remember which track is the
    /// space one). ONLY the first `hashedThemeCount` are auto-dealt;
    /// worlds after that are pick-them-yourself (appending one must not
    /// re-theme every existing track).
    static var hashedThemeCount: Int { RaceTuning.hashedThemeNames.count }
    static let themes: [Theme] = [
        Theme(name: "candy", displayName: "Candy", symbol: "birthday.cake.fill",
              skyTop: rgb(0.95, 0.35, 0.62), skyHorizon: rgb(1.0, 0.82, 0.88),
              groundLight: rgb(0.55, 0.80, 0.72), groundDark: rgb(0.45, 0.71, 0.62),
              stars: false, clouds: true,
              props: ["item-banana", "item-box", "item-coin-gold", "item-cone",
                      "food-cupcake", "food-donut", "food-popsicle",
                      "winter-cane-red", "winter-cane-green"],
              horizon: ["food-donut", "food-popsicle", "food-icecream"],
              horizonScale: 4),
        Theme(name: "day", displayName: "Sunny Day", symbol: "sun.max.fill",
              skyTop: rgb(0.25, 0.55, 0.95), skyHorizon: rgb(0.80, 0.93, 1.0),
              groundLight: rgb(0.35, 0.62, 0.32), groundDark: rgb(0.27, 0.52, 0.26),
              stars: false, clouds: true,
              props: ["item-cone", "item-cone", "item-box", "item-banana"],
              horizon: ["park-tree-default", "park-tree-oak"],
              horizonScale: 3.5),
        Theme(name: "sunset", displayName: "Sunset", symbol: "sunset.fill",
              skyTop: rgb(0.35, 0.16, 0.45), skyHorizon: rgb(1.0, 0.62, 0.30),
              groundLight: rgb(0.72, 0.58, 0.38), groundDark: rgb(0.62, 0.48, 0.30),
              stars: false, clouds: true,
              props: ["item-cone", "item-cone", "item-box"],
              horizon: ["park-tree-oak", "canyon-mesa"],
              horizonScale: 3),
        Theme(name: "space", displayName: "Space", symbol: "moon.stars.fill",
              skyTop: rgb(0.02, 0.02, 0.10), skyHorizon: rgb(0.16, 0.07, 0.32),
              groundLight: rgb(0.42, 0.38, 0.50), groundDark: rgb(0.34, 0.30, 0.42),
              stars: true, clouds: false,
              props: ["item-coin-gold", "item-coin-gold",
                      "space-speeder-a", "space-speeder-b", "space-racer",
                      "space-meteor", "space-meteor-detailed",
                      "space-crater", "space-crater-large",
                      "space-crystals-a", "space-crystals-b", "space-dish",
                      "space-alien", "space-astronaut-a", "space-astronaut-b"],
              propCount: 36,
              horizon: ["space-meteor", "space-meteor-detailed", "space-speeder-c", "space-crystals-a"],
              horizonScale: 3),

        // Pickable worlds (Kenney city/nature kits, converted at 0.3).
        Theme(name: "city", displayName: "Big City", symbol: "building.2.fill",
              skyTop: rgb(0.30, 0.55, 0.90), skyHorizon: rgb(0.84, 0.91, 0.98),
              groundLight: rgb(0.47, 0.47, 0.50), groundDark: rgb(0.40, 0.40, 0.43),
              stars: false, clouds: true,
              props: ["city-shop-a", "city-shop-b", "city-shop-c", "city-shop-d",
                      "city-shop-e", "city-shop-f", "city-shop-g", "city-shop-h",
                      "city-shop-i", "city-shop-j", "city-shop-k", "city-shop-l",
                      "city-shop-m", "city-shop-n",
                      "city-skyscraper-a", "city-skyscraper-b", "city-skyscraper-c",
                      "city-skyscraper-d", "city-skyscraper-e",
                      "city-streetlight", "city-streetlight", "city-planter"],
              structured: true, propCount: 44,
              horizon: ["city-skyscraper-a", "city-skyscraper-b", "city-skyscraper-c", "city-skyscraper-d", "city-skyscraper-e"],
              horizonScale: 3.5, cityBlocks: true,
              traffic: ["taxi", "police", "sedan-sports", "suv", "ambulance",
                        "delivery", "garbage-truck", "sedan", "suv-luxury"]),
        Theme(name: "town", displayName: "Hometown", symbol: "house.fill",
              skyTop: rgb(0.32, 0.60, 0.95), skyHorizon: rgb(0.84, 0.94, 1.0),
              groundLight: rgb(0.42, 0.66, 0.34), groundDark: rgb(0.34, 0.56, 0.28),
              stars: false, clouds: true,
              props: ["city-house-a", "city-house-b", "city-house-c", "city-house-d",
                      "city-house-e", "city-house-f", "city-house-g", "city-house-h",
                      "city-house-i", "city-house-j", "city-house-k", "city-house-l",
                      "city-house-m", "city-house-n", "city-house-o", "city-house-p",
                      "city-house-q", "city-house-r", "city-house-s", "city-house-t",
                      "city-house-u",
                      "city-tree-large", "city-tree-small", "city-fence"],
              structured: true, propCount: 40,
              horizon: ["city-house-b", "city-house-n", "city-tree-large"],
              horizonScale: 3, cityBlocks: true,
              traffic: ["sedan-sports", "suv", "truck", "taxi", "van", "sedan",
                        "firetruck", "tractor"]),
        Theme(name: "park", displayName: "Park", symbol: "tree.fill",
              skyTop: rgb(0.28, 0.58, 0.90), skyHorizon: rgb(0.82, 0.94, 0.96),
              groundLight: rgb(0.30, 0.58, 0.28), groundDark: rgb(0.24, 0.49, 0.23),
              stars: false, clouds: true,
              // Trees dealt double — the flowers and mushrooms are lovely
              // up close and invisible from the chase cam, so an even draw
              // reads as an empty lawn.
              props: ["park-tree-default", "park-tree-default", "park-tree-oak",
                      "park-tree-oak", "park-tree-palm", "park-tree-detailed",
                      "park-tree-detailed", "city-tree-large",
                      "park-mushroom-red", "park-flower-red",
                      "park-flower-yellow", "park-stump"],
              propCount: 48,
              horizon: ["park-tree-default", "park-tree-detailed", "park-tree-oak"],
              horizonScale: 3.5),
        Theme(name: "speedway", displayName: "Speedway", symbol: "flag.checkered",
              skyTop: rgb(0.28, 0.55, 0.92), skyHorizon: rgb(0.82, 0.90, 0.97),
              groundLight: rgb(0.44, 0.56, 0.38), groundDark: rgb(0.38, 0.49, 0.33),
              stars: false, clouds: true,
              props: ["race-grandstand", "race-grandstand-covered",
                      "race-billboard", "race-banner-tower-red",
                      "race-banner-tower-green", "race-flag-checkers",
                      "race-pylon", "race-pylon", "race-lightpost",
                      "race-pits-garage", "race-pits-office",
                      "race-car-red", "race-car-green"],
              structured: true, propCount: 32, clearance: 0.8,
              horizon: ["race-grandstand-covered", "race-billboard", "race-banner-tower-red"],
              horizonScale: 3, cityBlocks: true,
              traffic: ["race-car-red", "race-car-green", "race"],
              trafficSpeed: 0.9),
        Theme(name: "castle", displayName: "Castle", symbol: "crown.fill",
              skyTop: rgb(0.34, 0.52, 0.88), skyHorizon: rgb(0.85, 0.90, 0.95),
              groundLight: rgb(0.38, 0.60, 0.32), groundDark: rgb(0.31, 0.51, 0.27),
              stars: false, clouds: true,
              props: ["castle-tower", "castle-tower", "castle-catapult",
                      "castle-trebuchet", "castle-ballista", "castle-siege-tower",
                      "castle-flag", "castle-flag-wide", "castle-rocks",
                      "castle-tree", "castle-cart", "castle-cart-high",
                      "castle-fountain", "castle-hedge", "castle-lantern"],
              structured: true, propCount: 32, clearance: 0.7,
              horizon: ["castle-tower", "castle-siege-tower", "castle-tree"],
              horizonScale: 3.5),
        Theme(name: "winter", displayName: "Winter", symbol: "snowflake",
              skyTop: rgb(0.55, 0.72, 0.92), skyHorizon: rgb(0.90, 0.95, 1.0),
              groundLight: rgb(0.93, 0.95, 0.98), groundDark: rgb(0.84, 0.88, 0.94),
              stars: false, clouds: true,
              props: ["winter-tree-decorated", "winter-tree-decorated-snow",
                      "winter-tree-a", "winter-tree-b", "winter-tree-c",
                      "winter-snowman", "winter-snowman-hat", "winter-reindeer",
                      "winter-present-a", "winter-present-b", "winter-present-c",
                      "winter-present-d", "winter-cane-red", "winter-cane-green",
                      "winter-nutcracker", "winter-gingerbread-man",
                      "winter-gingerbread-woman", "winter-sled",
                      "winter-snow-pile", "winter-lantern"],
              propCount: 44, clearance: 0.5,
              horizon: ["winter-tree-a", "winter-tree-b", "winter-tree-decorated-snow"],
              horizonScale: 3.5, train: true),
        Theme(name: "pirate", displayName: "Pirate Cove", symbol: "sailboat.fill",
              skyTop: rgb(0.16, 0.55, 0.75), skyHorizon: rgb(0.80, 0.93, 0.94),
              groundLight: rgb(0.89, 0.80, 0.58), groundDark: rgb(0.82, 0.72, 0.50),
              stars: false, clouds: true,
              props: ["pirate-ship-large", "pirate-ship-medium", "pirate-ship-small",
                      "pirate-ship-ghost", "pirate-ship-wreck",
                      "pirate-tower-large", "pirate-tower-small",
                      "pirate-palm-a", "pirate-palm-a", "pirate-palm-b",
                      "pirate-palm-c", "pirate-chest", "pirate-barrel",
                      "pirate-cannon", "pirate-crate", "pirate-rocks-a",
                      "pirate-rocks-b", "pirate-flag"],
              propCount: 30, clearance: 1.0,
              horizon: ["pirate-ship-large", "pirate-ship-medium", "pirate-tower-large"],
              horizonScale: 2.5),
        Theme(name: "spooky", displayName: "Spooky", symbol: "moon.haze.fill",
              skyTop: rgb(0.07, 0.04, 0.14), skyHorizon: rgb(0.30, 0.14, 0.36),
              groundLight: rgb(0.24, 0.29, 0.24), groundDark: rgb(0.19, 0.24, 0.19),
              stars: true, clouds: false,
              props: ["spooky-crypt", "spooky-crypt-a", "spooky-grave-round",
                      "spooky-grave-wide", "spooky-grave-cross",
                      "spooky-grave-bevel", "spooky-grave-fancy",
                      "spooky-cross-wood", "spooky-coffin", "spooky-pumpkin",
                      "spooky-pumpkin-tall", "spooky-pine", "spooky-pine-fall",
                      "spooky-lantern", "spooky-lightpost", "spooky-ghost",
                      "spooky-skeleton", "spooky-vampire", "spooky-zombie",
                      "spooky-rocks"],
              propCount: 42,
              horizon: ["spooky-pine", "spooky-pine-fall", "spooky-crypt"],
              horizonScale: 3.5),
        Theme(name: "golf", displayName: "Putt-Putt", symbol: "figure.golf",
              skyTop: rgb(0.30, 0.60, 0.92), skyHorizon: rgb(0.84, 0.94, 0.96),
              groundLight: rgb(0.36, 0.70, 0.36), groundDark: rgb(0.30, 0.61, 0.30),
              stars: false, clouds: true,
              props: ["golf-windmill", "golf-windmill", "golf-castle",
                      "golf-gate", "golf-diamond", "golf-triangle",
                      "golf-flag-red", "golf-flag-blue",
                      "golf-ball-red", "golf-ball-blue"],
              propCount: 26,
              horizon: ["golf-windmill", "golf-castle"],
              horizonScale: 3),
        Theme(name: "snacks", displayName: "Snack Land", symbol: "fork.knife",
              skyTop: rgb(0.98, 0.62, 0.35), skyHorizon: rgb(1.0, 0.88, 0.72),
              groundLight: rgb(0.94, 0.86, 0.74), groundDark: rgb(0.88, 0.78, 0.64),
              stars: false, clouds: true,
              props: ["food-burger", "food-hotdog", "food-icecream", "food-cone",
                      "food-donut", "food-donut-chocolate", "food-cupcake",
                      "food-cake", "food-pizza", "food-fries", "food-popsicle",
                      "food-sundae", "food-waffle", "food-soda", "food-muffin",
                      "food-pancakes"],
              propCount: 40, clearance: 0.5,
              horizon: ["food-burger", "food-sundae", "food-soda"],
              horizonScale: 3.5),
        Theme(name: "construction", displayName: "Construction",
              symbol: "hammer.fill",
              skyTop: rgb(0.30, 0.56, 0.90), skyHorizon: rgb(0.85, 0.90, 0.94),
              groundLight: rgb(0.64, 0.52, 0.38), groundDark: rgb(0.56, 0.45, 0.32),
              stars: false, clouds: true,
              props: ["build-barrier", "build-barrier", "build-cone", "build-cone",
                      "build-fence", "build-light", "build-dumpster", "build-pole",
                      "build-lightpost", "build-sign-stop", "build-pillar",
                      "item-box", "item-box"],
              propCount: 40,
              horizon: ["build-pole", "build-lightpost", "city-skyscraper-a"],
              horizonScale: 3),
        Theme(name: "camp", displayName: "Campground", symbol: "tent.fill",
              skyTop: rgb(0.24, 0.50, 0.84), skyHorizon: rgb(0.80, 0.90, 0.92),
              groundLight: rgb(0.28, 0.52, 0.26), groundDark: rgb(0.22, 0.44, 0.21),
              stars: false, clouds: true,
              props: ["camp-tent-open", "camp-tent-closed", "camp-tent-small",
                      "camp-fire", "camp-fire-stones", "camp-canoe", "camp-bridge",
                      "camp-bush", "camp-rock", "park-tree-default",
                      "park-tree-default", "park-tree-detailed",
                      "park-tree-detailed", "park-stump"],
              propCount: 40,
              horizon: ["park-tree-default", "park-tree-detailed", "camp-rock"],
              horizonScale: 3.5),
        Theme(name: "canyon", displayName: "Canyon", symbol: "mountain.2.fill",
              skyTop: rgb(0.45, 0.42, 0.72), skyHorizon: rgb(1.0, 0.72, 0.45),
              groundLight: rgb(0.80, 0.53, 0.36), groundDark: rgb(0.72, 0.46, 0.30),
              stars: false, clouds: true,
              props: ["canyon-cliff-large", "canyon-cliff", "canyon-mesa",
                      "canyon-cactus-short", "canyon-cactus-short",
                      "canyon-cactus-tall", "canyon-cactus-tall",
                      "canyon-rock-a", "canyon-rock-b", "canyon-rock-c",
                      "park-stump"],
              propCount: 34, clearance: 1.1,
              horizon: ["canyon-cliff-large", "canyon-mesa", "canyon-cactus-tall"],
              horizonScale: 3),
    ]

    static func theme(named name: String?, for trackID: UUID?) -> Theme {
        // A bogus picked name falls back to the hash, same as no pick.
        let valid = themes.contains { $0.name == name } ? name : nil
        let resolved = RaceTuning.resolvedThemeName(valid, for: trackID)
        return themes.first { $0.name == resolved } ?? themes[1]
    }

    /// Entity name for change detection — ArenaView rebuilds when the
    /// track, its chosen world, or its placed decorations change.
    static func name(for trackID: UUID?, theme: String?,
                     scenery: [SceneryItem] = [], empty: Bool = false) -> String {
        "env-\(theme ?? "auto")\(empty ? "-empty" : "")-\(scenery.hashValue)-\(trackID?.uuidString ?? "lobby")"
    }

    private static let halfPiF = Float.pi / 2
    private static let groundSize: Float = 90
    private static let skyRadius: Float = 70
    /// Texture repeats across the ground: 4 m per repeat, 2×2 checks each
    /// → 2 m play-mat squares.
    private static let groundTiles: Float = 22.5

    /// Seeded LCG — same track, same world, every launch.
    private struct Dice {
        var seed: UInt64
        mutating func next01() -> Float {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            // >> 32 keeps 32 bits — >> 33 gave [0, 0.5) and left half
            // the dome starless.
            return Float(seed >> 32) / Float(UInt32.max)
        }
    }

    /// Sky dome + terrain (with the arena's static collision floor)
    /// + decorative props scattered clear of `footprint` (the track)
    /// + a ring of oversized silhouettes out at the horizon.
    /// `themeName` is the blueprint's picked world; nil falls back to the
    /// trackId hash. Groundless worlds (space) skip terrain entirely —
    /// the track floats; only the invisible physics floor remains.
    /// `empty` keeps the theme's sky, colors, and terrain but none of the
    /// auto-placed stuff (scatter, blocks, horizon, train) — a blank
    /// world for kids who want to design everything themselves.
    /// `tunnels` are the ground rects of track pieces that dip BELOW the
    /// ground — the terrain mounds a hill over each, so an underground run
    /// reads as driving through a hill rather than through a floor.
    @MainActor
    static func make(for trackID: UUID?, theme themeName: String? = nil,
                     scenery: [SceneryItem] = [], empty: Bool = false,
                     tunnels: [FootprintRect] = [],
                     around footprint: FootprintRect?) async -> Entity {
        let theme = theme(named: themeName, for: trackID)
        let groundless = RaceTuning.groundlessThemes.contains(theme.name)
        // Terrain stays FLAT here: the track, its prop ring, and the
        // kid's placements all sit at y = 0. Hills start beyond — except
        // the mounds over underground sections.
        let flatZone = flatRect(around: footprint)
        let mounds = tunnels.map { rect in
            TunnelMound(
                center: SIMD2((rect.minX + rect.maxX) / 2,
                              (rect.minZ + rect.maxZ) / 2),
                radius: max(rect.maxX - rect.minX, rect.maxZ - rect.minZ) / 2 + 0.8)
        }
        let root = Entity()
        root.name = name(for: trackID, theme: themeName, scenery: scenery)

        // Invisible physics floor + tap target for the builder's decorate
        // mode. Always present — even a floating space track needs a floor
        // so a flung car's wreck has somewhere to land.
        let floor = Entity()
        floor.position.y = -0.03
        floor.components.set(CollisionComponent(
            shapes: [.generateBox(width: groundSize, height: 0.01, depth: groundSize)]))
        floor.components.set(PhysicsBodyComponent(mode: .static))
        floor.components.set(InputTargetComponent())
        root.addChild(floor)

        if !groundless {
            let ground = ModelEntity(
                mesh: terrainMesh(flat: flatZone, mounds: mounds),
                materials: [await groundMaterial(theme)])
            ground.name = "terrain"
            ground.position.y = -0.03
            GroundFadeComponent.registerComponent()
            GroundFadeSystem.registerSystem()
            ground.components.set(GroundFadeComponent())
            root.addChild(ground)
        }

        var skyMaterial = UnlitMaterial()
        if let image = skyImage(theme),
           let texture = try? await TextureResource(
               image: image, options: .init(semantic: .color)) {
            skyMaterial.color = .init(texture: .init(texture))
        }
        let sky = ModelEntity(mesh: .generateSphere(radius: skyRadius),
                              materials: [skyMaterial])
        // Negative x-scale flips the winding so the inside faces render.
        sky.scale = [-1, 1, 1]
        root.addChild(sky)

        AmbientMotionComponent.registerComponent()
        AmbientMotionSystem.registerSystem()
        var autoBuildings = Set<SIMD2<Int32>>()
        if !empty {
            if theme.cityBlocks, let footprint {
                autoBuildings = await layCityBlocks(
                    theme: theme, trackID: trackID, around: footprint,
                    handPavement: SceneryPlacer.pavementCells(in: scenery),
                    handBuildings: SceneryPlacer.handBuildingCells(in: scenery),
                    into: root)
            } else {
                await scatterProps(theme: theme, trackID: trackID,
                                   around: footprint, into: root)
            }
            await addHorizon(theme: theme, trackID: trackID, flat: flatZone,
                             groundless: groundless, into: root)
            if theme.train, let footprint {
                await addTrain(around: footprint, into: root)
            }
        }
        if !scenery.isEmpty {
            // Placed vehicles drive the same street grid the world laid
            // (plus any roads the kid placed by hand); placed people walk
            // the same joined sidewalk network and know the same doors.
            let autoStreets: Set<SIMD2<Int32>> =
                (theme.cityBlocks && !empty && footprint != nil)
                    ? autoStreetCells(around: footprint!, clearance: theme.clearance)
                    : []
            root.addChild(await SceneryPlacer.spawn(
                scenery, autoStreets: autoStreets, autoBuildings: autoBuildings))
        }
        return root
    }

    /// Loco + tender + wagon on an ellipse just outside the prop ring,
    /// inside the flat zone so the rails-less train never climbs a hill.
    @MainActor
    private static func addTrain(around footprint: FootprintRect,
                                 into root: Entity) async {
        TrainCarComponent.registerComponent()
        TrainSystem.registerSystem()
        let center = SIMD2<Float>((footprint.minX + footprint.maxX) / 2,
                                  (footprint.minZ + footprint.maxZ) / 2)
        let radius = SIMD2<Float>((footprint.maxX - footprint.minX) / 2 + 5.2,
                                  (footprint.maxZ - footprint.minZ) / 2 + 5.2)
        let meanRadius = (radius.x + radius.y) / 2
        let speed = 0.5 / meanRadius          // ~0.5 m/s along the loop
        let gap = 0.24 / meanRadius           // one car length apart
        for (index, model) in ["winter-train-loco", "winter-train-tender",
                               "winter-train-wagon"].enumerated() {
            guard let car = try? await AssetStore.shared.entity(named: model) else { continue }
            car.components.set(TrainCarComponent(
                center: center, radius: radius, angularSpeed: speed,
                angle: -Float(index) * gap))
            root.addChild(car)
        }
    }

    /// Streets and blocks for the city worlds: road tiles every third
    /// grid line (crossroads where they meet), buildings filling the
    /// blocks between, each facing its street. Replaces loose scatter,
    /// which read as buildings dropped from the sky.
    /// `handPavement` / `handBuildings` are the kid's own sidewalks and
    /// buildings — the strollers' network joins them to the city's, and
    /// returns the auto building cells so placed people learn the same
    /// doors (`SceneryPlacer.spawn`).
    @MainActor @discardableResult
    private static func layCityBlocks(theme: Theme, trackID: UUID?,
                                      around footprint: FootprintRect,
                                      handPavement: Set<SIMD2<Int32>> = [],
                                      handBuildings: Set<SIMD2<Int32>> = [],
                                      into root: Entity) async -> Set<SIMD2<Int32>> {
        let step: Float = 0.7
        let margin: Float = 5.0
        let trackSeed = trackID.map { id in
            withUnsafeBytes(of: id.uuid) { $0.reduce(0) { $0 &* 31 &+ Int($1) } }
        } ?? 0
        var dice = Dice(seed: 0xC17B10C5 &+ UInt64(truncatingIfNeeded: trackSeed))
        var seen = Set<String>()
        var prototypes: [Entity] = []
        for name in theme.props where seen.insert(name).inserted {
            if let entity = try? await AssetStore.shared.entity(named: name) {
                entity.name = name
                prototypes.append(entity)
            }
        }
        guard !prototypes.isEmpty else { return [] }
        var tileProtos: [String: Entity] = [:]
        for name in ["street-straight", "street-cross", "street-bend",
                     "street-tee", "street-end"] {
            tileProtos[name] = try? await AssetStore.shared.entity(named: name)
        }
        guard tileProtos["street-straight"] != nil else { return [] }

        let iRange = Int(((footprint.minX - margin) / step).rounded(.down))
            ... Int(((footprint.maxX + margin) / step).rounded(.up))
        let jRange = Int(((footprint.minZ - margin) / step).rounded(.down))
            ... Int(((footprint.maxZ + margin) / step).rounded(.up))
        func insideTrack(_ i: Int, _ j: Int) -> Bool {
            let x = Float(i) * step
            let z = Float(j) * step
            return x > footprint.minX - theme.clearance
                && x < footprint.maxX + theme.clearance
                && z > footprint.minZ - theme.clearance
                && z < footprint.maxZ + theme.clearance
        }
        let streets = autoStreetCells(around: footprint, clearance: theme.clearance)

        var entityCount = 0
        var buildingCells = Set<SIMD2<Int32>>()
        for i in iRange {
            for j in jRange {
                guard entityCount < 600 else { return buildingCells }   // runaway-track cap
                let x = Float(i) * step
                let z = Float(j) * step
                guard !insideTrack(i, j) else { continue }
                if streets.contains(SIMD2(Int32(i), Int32(j))) {
                    let cell = SIMD2(Int32(i), Int32(j))
                    guard let pick = streetTile(
                        north: streets.contains(cell &+ SIMD2(0, 1)),
                        south: streets.contains(cell &- SIMD2(0, 1)),
                        east: streets.contains(cell &+ SIMD2(1, 0)),
                        west: streets.contains(cell &- SIMD2(1, 0))),
                        let proto = tileProtos[pick.model] else { continue }
                    let tile = proto.clone(recursive: true)
                    tile.name = "street-tile"
                    // Streets hug the ground plane (its top is at −0.03)
                    // instead of floating at prop height.
                    tile.position = [x, -0.025, z]
                    tile.orientation = simd_quatf(angle: pick.yaw, axis: [0, 1, 0])
                    root.addChild(tile)
                    entityCount += 1
                } else {
                    // Blocks breathe: some cells stay open like tiny parks.
                    guard dice.next01() > 0.3 else { continue }
                    let building = prototypes[
                        Int(dice.next01() * 0.999 * Float(prototypes.count))]
                        .clone(recursive: true)
                    building.position = [x, 0, z]
                    // Face the nearer street: interior cells sit 1 cell
                    // from a row street and 1 from a column street — pick
                    // one per die so a block's houses don't all match.
                    let yaw: Float
                    if dice.next01() < 0.5 {
                        yaw = ((i % 3) + 3) % 3 == 1 ? -halfPiF : halfPiF
                    } else {
                        yaw = ((j % 3) + 3) % 3 == 1 ? .pi : 0
                    }
                    building.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0])
                    AmbientMotion.apply(to: building, model: building.name,
                                        vary: dice.next01())
                    root.addChild(building)
                    buildingCells.insert(SIMD2(Int32(i), Int32(j)))
                    entityCount += 1
                }
            }
        }

        // Traffic: little cars driving the streets they were laid on,
        // entering the network at road STARTS (dead-end tiles) so every
        // car appears at the beginning of some road and drives in.
        if !theme.traffic.isEmpty, streets.count > 8 {
            TrafficComponent.registerComponent()
            TrafficSystem.registerSystem()
            let carCount = min(8, max(2, streets.count / 20))
            for index in 0..<carCount {
                let model = theme.traffic[index % theme.traffic.count]
                guard let car = try? await AssetStore.shared.entity(named: model) else { continue }
                var seed = dice.seed &+ UInt64(index) &* 977
                guard let start = TrafficSystem.roadStart(in: streets,
                                                          seed: &seed) else { break }
                car.components.set(TrafficComponent(
                    cells: streets, cell: start.cell, direction: start.direction,
                    speed: theme.trafficSpeed, seed: seed))
                car.components.set(OpacityComponent(opacity: 0))
                root.addChild(car)
            }
        }

        // Sidewalk strollers: little people walking the streets' edges,
        // each with a shopper's 1-in-100 impulse to pop into a building
        // they pass (PedestrianSystem.visit).
        if streets.count > 8 {
            PedestrianComponent.registerComponent()
            PedestrianSystem.registerSystem()
            // One joined network: the city's road-edge sidewalks plus any
            // pavement the kid laid, so a hand path off a street is just
            // another place to stroll to.
            let roadside = sidewalkCells(from: streets)
            let pavement = roadside.union(handPavement)
            let doors = buildingCells.union(handBuildings)
            let people = ["person-a", "person-b", "person-c", "person-d"]
            let strollerCount = min(6, max(2, streets.count / 25))
            for index in 0..<strollerCount {
                guard let person = try? await AssetStore.shared.entity(
                    named: people[index % people.count]) else { continue }
                var seed = dice.seed &+ UInt64(index) &* 733
                guard let start = TrafficSystem.roadStart(in: pavement,
                                                          seed: &seed) else { break }
                person.components.set(PedestrianComponent(
                    cells: pavement, cell: start.cell,
                    direction: start.direction,
                    sideOffset: index % 2 == 0 ? -0.26 : 0.26,
                    buildings: doors, roadside: roadside, seed: seed))
                if let animation = person.availableAnimations.first {
                    person.playAnimation(animation.repeat())
                }
                root.addChild(person)
            }
        }
        return buildingCells
    }

    /// The street grid re-sampled at pedestrian resolution (0.35 m — half
    /// a street cell): each road cell doubled, plus the midpoints between
    /// adjacent road cells so the sidewalk graph connects. Strollers walk
    /// it with a side offset, which puts them on the pavement edge baked
    /// into the road tiles.
    static func sidewalkCells(from streets: Set<SIMD2<Int32>>) -> Set<SIMD2<Int32>> {
        var cells = Set<SIMD2<Int32>>()
        for cell in streets {
            cells.insert(cell &* 2)
            for step in TrafficSystem.compass where streets.contains(cell &+ step) {
                cells.insert(cell &* 2 &+ step)
            }
        }
        return cells
    }

    /// The auto-laid street network for a cityBlocks world, in 0.7 m grid
    /// cells: every third grid line, minus where the track punches
    /// through. Deterministic — the builder recomputes it to give
    /// hand-placed cars the same map the arena drives on.
    static func autoStreetCells(around footprint: FootprintRect,
                                clearance: Float) -> Set<SIMD2<Int32>> {
        let step: Float = 0.7
        let margin: Float = 5.0
        func gridLine(_ n: Int) -> Bool { ((n % 3) + 3) % 3 == 0 }
        var streets = Set<SIMD2<Int32>>()
        let iRange = Int(((footprint.minX - margin) / step).rounded(.down))
            ... Int(((footprint.maxX + margin) / step).rounded(.up))
        let jRange = Int(((footprint.minZ - margin) / step).rounded(.down))
            ... Int(((footprint.maxZ + margin) / step).rounded(.up))
        for i in iRange {
            for j in jRange where gridLine(i) || gridLine(j) {
                let x = Float(i) * step
                let z = Float(j) * step
                let insideTrack = x > footprint.minX - clearance
                    && x < footprint.maxX + clearance
                    && z > footprint.minZ - clearance
                    && z < footprint.maxZ + clearance
                if !insideTrack {
                    streets.insert(SIMD2(Int32(i), Int32(j)))
                }
            }
        }
        return streets
    }

    /// Which street tile a cell needs, from which neighbours are street.
    /// Yaw conventions measured off the converted Kenney tiles: straight
    /// runs along z at yaw 0; the bend joins south and east; the tee's
    /// closed side faces north; the end's open side faces south.
    static func streetTile(north: Bool, south: Bool, east: Bool, west: Bool)
        -> (model: String, yaw: Float)? {
        switch (north, south, east, west) {
        case (true, true, true, true):
            return ("street-cross", 0)
        case (false, true, true, true): return ("street-tee", 0)
        case (true, false, true, true): return ("street-tee", .pi)
        case (true, true, false, true): return ("street-tee", halfPiF)
        case (true, true, true, false): return ("street-tee", -halfPiF)
        case (true, true, false, false): return ("street-straight", 0)
        case (false, false, true, true): return ("street-straight", halfPiF)
        case (false, true, true, false): return ("street-bend", 0)
        case (false, true, false, true): return ("street-bend", halfPiF)
        case (true, false, false, true): return ("street-bend", .pi)
        case (true, false, true, false): return ("street-bend", -halfPiF)
        case (false, true, false, false): return ("street-end", 0)
        case (true, false, false, false): return ("street-end", .pi)
        case (false, false, true, false): return ("street-end", -halfPiF)
        case (false, false, false, true): return ("street-end", halfPiF)
        case (false, false, false, false):
            return nil   // orphan cell — no road to nowhere
        }
    }

    // MARK: Terrain

    /// The rectangle that must stay level: the track plus the ring where
    /// theme props scatter and kids place decorations.
    private static func flatRect(around footprint: FootprintRect?) -> FootprintRect {
        let f = footprint ?? FootprintRect(minX: -2, minZ: -2, maxX: 2, maxZ: 2)
        return FootprintRect(minX: f.minX - 6, minZ: f.minZ - 6,
                             maxX: f.maxX + 6, maxZ: f.maxZ + 6)
    }

    /// A hill mounded over an underground track section — the dirt the
    /// car drives through.
    struct TunnelMound: Equatable {
        var center: SIMD2<Float>
        var radius: Float
        /// How high the dome crests, metres. Tall enough to read as a
        /// hill over a one-level dig (bed at −0.2).
        static let height: Float = 0.5
    }

    /// Ground height at (x, z): 0 inside the flat zone, gentle rolling
    /// hills fading in beyond it, a mountain rim near the world's edge so
    /// the horizon has a shape instead of a table edge — plus a smooth
    /// dome over every tunnel (cosine falloff; overlapping domes merge as
    /// a ridge via max, not a sum of lumps).
    static func terrainHeight(x: Float, z: Float, flat: FootprintRect,
                              mounds: [TunnelMound] = []) -> Float {
        var mound: Float = 0
        for m in mounds {
            let d = simd_length(SIMD2(x, z) - m.center)
            if d < m.radius {
                mound = max(mound, TunnelMound.height
                    * (0.5 + 0.5 * cos(.pi * d / m.radius)))
            }
        }
        let dx = max(0, max(flat.minX - x, x - flat.maxX))
        let dz = max(0, max(flat.minZ - z, z - flat.maxZ))
        let distance = sqrt(dx * dx + dz * dz)
        guard distance > 0 else { return mound }
        let fade = min(1, distance / 8)
        let rolling = 0.35 * sin(x * 0.31) * cos(z * 0.27)
            + 0.14 * sin(x * 0.83 + z * 0.51)
        let edge = max(abs(x), abs(z))
        let rim = simd_smoothstep(groundSize / 2 - 13, groundSize / 2 - 2, edge) * 2.4
        return max(0, rolling * fade) + rim + mound
    }

    /// Low-poly heightfield over the whole ground square, checker UVs
    /// matching the old flat plane. Normals come from MeshDescriptor.
    /// 120 segments ≈ 0.75 m spacing — fine enough that a tunnel mound
    /// (radius ≥ 1.2) renders as a dome, not an aliased spike.
    private static func terrainMesh(flat: FootprintRect,
                                    mounds: [TunnelMound] = []) -> MeshResource {
        let n = 120
        var positions: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []
        positions.reserveCapacity((n + 1) * (n + 1))
        for iz in 0...n {
            for ix in 0...n {
                let x = -groundSize / 2 + Float(ix) / Float(n) * groundSize
                let z = -groundSize / 2 + Float(iz) / Float(n) * groundSize
                positions.append([x, terrainHeight(x: x, z: z, flat: flat,
                                                   mounds: mounds), z])
                uvs.append([Float(ix) / Float(n) * groundTiles,
                            Float(iz) / Float(n) * groundTiles])
            }
        }
        var indices: [UInt32] = []
        indices.reserveCapacity(n * n * 6)
        for iz in 0..<n {
            for ix in 0..<n {
                let a = UInt32(iz * (n + 1) + ix)
                let b = a + 1
                let c = a + UInt32(n + 1)
                let d = c + 1
                indices += [a, c, b, b, c, d]
            }
        }
        var descriptor = MeshDescriptor(name: "terrain")
        descriptor.positions = .init(positions)
        descriptor.textureCoordinates = .init(uvs)
        descriptor.primitives = .triangles(indices)
        // Fallback plane: generate(from:) only throws on malformed data,
        // which a grid never is.
        return (try? MeshResource.generate(from: [descriptor]))
            ?? .generatePlane(width: groundSize, depth: groundSize)
    }

    // MARK: Horizon silhouettes

    /// A ring of oversized props out past the playfield — skylines,
    /// mesas, galleons — so the distance feels alive from the chase cam.
    /// Groundless worlds float theirs at varied heights instead.
    @MainActor
    private static func addHorizon(theme: Theme, trackID: UUID?,
                                   flat: FootprintRect, groundless: Bool,
                                   into root: Entity) async {
        guard !theme.horizon.isEmpty else { return }
        let trackSeed = trackID.map { id in
            withUnsafeBytes(of: id.uuid) { $0.reduce(0) { $0 &* 31 &+ Int($1) } }
        } ?? 0
        var dice = Dice(seed: 0x40B1_2043 &+ UInt64(truncatingIfNeeded: trackSeed))
        var prototypes: [Entity] = []
        for name in theme.horizon {
            if let entity = try? await AssetStore.shared.entity(named: name) {
                entity.name = name
                prototypes.append(entity)
            }
        }
        guard !prototypes.isEmpty else { return }
        let count = 14
        for i in 0..<count {
            let angle = (Float(i) + dice.next01() * 0.7) / Float(count) * 2 * .pi
            let radius = 31 + dice.next01() * 9
            let x = cos(angle) * radius
            let z = sin(angle) * radius
            let prop = prototypes[Int(dice.next01() * 0.999 * Float(prototypes.count))]
                .clone(recursive: true)
            let y = groundless ? -2 + dice.next01() * 8
                               : terrainHeight(x: x, z: z, flat: flat)
            prop.position = [x, y, z]
            prop.scale *= theme.horizonScale * (0.8 + dice.next01() * 0.5)
            prop.orientation = simd_quatf(angle: atan2(-x, -z), axis: [0, 1, 0])
            // Distant galleons bob, distant trees sway — scaled up, the
            // idle motion is what sells them as part of the world.
            AmbientMotion.apply(to: prop, model: prop.name, vary: dice.next01())
            root.addChild(prop)
        }
    }

    /// Toy clutter around the track: sampled in a ring just outside the
    /// track's footprint, rejected if inside it. Decoration only — no
    /// collision, so a flung car sails through instead of pinballing.
    @MainActor
    private static func scatterProps(theme: Theme, trackID: UUID?,
                                     around footprint: FootprintRect?,
                                     into root: Entity) async {
        guard let footprint, !theme.props.isEmpty else { return }
        let trackSeed = trackID.map { id in
            withUnsafeBytes(of: id.uuid) { $0.reduce(0) { $0 &* 31 &+ Int($1) } }
        } ?? 0
        var dice = Dice(seed: 0xD1CE &+ UInt64(truncatingIfNeeded: trackSeed))

        // Prototype each model once; clone per placement.
        var prototypes: [Entity] = []
        for name in theme.props {
            if let entity = try? await AssetStore.shared.entity(named: name) {
                entity.name = name      // clones inherit it — spots the coins
                prototypes.append(entity)
            }
        }
        guard !prototypes.isEmpty else { return }

        // Structured worlds (city blocks) need more elbow room than loose
        // toy clutter, and buildings can't share a spot the way cones can.
        let ringMargin: Float = theme.structured ? 5.0 : 3.5
        let clearance = max(theme.clearance, theme.structured ? 0.6 : 0.35)
        let gridStep: Float = 0.7       // ≥ widest building footprint
        let halfGround = groundSize / 2 - 1
        var takenCells = Set<SIMD2<Int>>()
        let centerX = (footprint.minX + footprint.maxX) / 2
        let centerZ = (footprint.minZ + footprint.maxZ) / 2
        var placed = 0
        var attempts = 0
        while placed < theme.propCount, attempts < theme.propCount * 4 {
            attempts += 1
            var x = footprint.minX - ringMargin
                + dice.next01() * (footprint.maxX - footprint.minX + 2 * ringMargin)
            var z = footprint.minZ - ringMargin
                + dice.next01() * (footprint.maxZ - footprint.minZ + 2 * ringMargin)
            if theme.structured {
                // Snap to city blocks; one building per cell.
                let cell = SIMD2(Int((x / gridStep).rounded()),
                                 Int((z / gridStep).rounded()))
                guard takenCells.insert(cell).inserted else { continue }
                x = Float(cell.x) * gridStep
                z = Float(cell.y) * gridStep
            }
            let insideTrack = x > footprint.minX - clearance
                && x < footprint.maxX + clearance
                && z > footprint.minZ - clearance
                && z < footprint.maxZ + clearance
            guard !insideTrack, abs(x) < halfGround, abs(z) < halfGround else { continue }
            placed += 1
            let prop = prototypes[Int(dice.next01() * 0.999 * Float(prototypes.count))]
                .clone(recursive: true)
            prop.position = [x, 0, z]
            // Buildings face the track, squared to the street grid; loose
            // clutter lands at any angle.
            let yaw: Float
            if theme.structured {
                let toward: Float = atan2(centerX - x, centerZ - z)
                yaw = (toward / halfPiF).rounded() * halfPiF
            } else {
                yaw = dice.next01() * 2 * .pi
            }
            prop.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0])
            // Coins turn, ships bob, trees sway; cones and boxes stay put
            // (a spinning traffic cone reads as a glitch).
            AmbientMotion.apply(to: prop, model: prop.name, vary: dice.next01())
            root.addChild(prop)
        }
    }

    // MARK: Materials

    @MainActor
    private static func groundMaterial(_ theme: Theme) async -> any RealityKit.Material {
        var material = PhysicallyBasedMaterial()
        material.roughness = 1.0     // play mat, not a showroom floor
        material.metallic = 0.0
        if let image = checkerImage(theme),
           let texture = try? await TextureResource(
               image: image, options: .init(semantic: .color)) {
            material.baseColor = .init(texture: .init(texture))
            material.textureCoordinateTransform = .init(
                scale: [groundTiles, groundTiles])
        }
        return material
    }

    // MARK: Procedural images

    /// Vertical gradient, horizon color at the equator; stars stamped on
    /// the space theme with a seeded LCG so every launch has the same sky.
    private static func skyImage(_ theme: Theme) -> CGImage? {
        // Wide: u wraps the full 360° dome, so 64 px would stretch a 1 px
        // star into a metres-wide invisible smear.
        let w = 1024, h = 512
        return draw(width: w, height: h) { ctx in
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                // CG y-up: image bottom (y 0) is the dome's lower half —
                // horizon color there, deep sky at the top.
                colors: [theme.skyHorizon, theme.skyHorizon, theme.skyTop] as CFArray,
                locations: [0.0, 0.45, 0.9]) else { return }
            ctx.drawLinearGradient(gradient,
                                   start: CGPoint(x: 0, y: 0),
                                   end: CGPoint(x: 0, y: CGFloat(h)),
                                   options: [])
            if theme.clouds { drawClouds(ctx, w: w, h: h) }
            guard theme.stars else { return }
            var dice = Dice(seed: 0x5EED)
            ctx.setFillColor(rgb(1, 1, 0.92))
            // Whole dome, dense and chunky: the chase cam grazes the sky,
            // so one frame only samples a thin v-band of this texture —
            // sparse or small stars simply never land in view.
            for _ in 0..<1400 {
                let x = CGFloat(dice.next01()) * CGFloat(w)
                let y = CGFloat(dice.next01()) * CGFloat(h)
                let r = 2.0 + CGFloat(dice.next01()) * 2.5
                ctx.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
            }
        }
    }

    /// Puffy clouds, drawn as clusters of overlapping circles in the band
    /// above the horizon. Two lessons carried over from the stars: shapes
    /// must be TENS of pixels across (the chase cam samples a thin v-band
    /// of a texture that wraps the full 360°, so small = never seen), and
    /// u wraps — a cloud near the edge is redrawn a full texture-width to
    /// each side so the seam doesn't slice it in half.
    private static func drawClouds(_ ctx: CGContext, w: Int, h: Int) {
        var dice = Dice(seed: 0xC10D)
        ctx.setFillColor(rgb(1, 1, 1))
        for _ in 0..<22 {
            let cx = CGFloat(dice.next01()) * CGFloat(w)
            // Just above the horizon (0.5 = the dome's equator). The chase
            // cam is pitched DOWN at the cars and only ever samples roughly
            // 0.50–0.62 of the dome, so clouds parked high simply never
            // appear; squaring biases the draw into that band while still
            // dealing a few higher ones for when the camera tilts up.
            let lift = CGFloat(dice.next01())
            let cy = CGFloat(h) * (0.50 + lift * lift * 0.20)
            // Sized to fit INSIDE that band — the first pass used 26–56 and
            // whole clouds overflowed it, reading as a white wash.
            let scale = 16 + CGFloat(dice.next01()) * 14
            // Puffs are precomputed so every wrapped copy is identical.
            let puffs = (0..<6).map { _ in
                (dx: CGFloat(dice.next01()) * 2.6 - 1.3,
                 dy: CGFloat(dice.next01()) * 0.5 - 0.25,
                 r: 0.55 + CGFloat(dice.next01()) * 0.55)
            }
            // One transparency layer per cloud: at plain alpha the puffs
            // would double-darken where they overlap and read as bubbles.
            ctx.setAlpha(0.55 + CGFloat(dice.next01()) * 0.30)
            ctx.beginTransparencyLayer(auxiliaryInfo: nil)
            for wrap in [-CGFloat(w), 0, CGFloat(w)] {
                for puff in puffs {
                    let d = puff.r * scale * 2
                    ctx.fillEllipse(in: CGRect(x: cx + wrap + puff.dx * scale - d / 2,
                                               y: cy + puff.dy * scale - d / 2,
                                               width: d, height: d))
                }
            }
            ctx.endTransparencyLayer()
        }
        ctx.setAlpha(1)
    }

    /// 2×2 low-contrast checker — reads as a giant play mat when tiled.
    private static func checkerImage(_ theme: Theme) -> CGImage? {
        let size = 64
        return draw(width: size, height: size) { ctx in
            let half = CGFloat(size) / 2
            ctx.setFillColor(theme.groundLight)
            ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
            ctx.setFillColor(theme.groundDark)
            ctx.fill(CGRect(x: 0, y: 0, width: half, height: half))
            ctx.fill(CGRect(x: half, y: half, width: half, height: half))
        }
    }

    private static func draw(width: Int, height: Int,
                             _ body: (CGContext) -> Void) -> CGImage? {
        guard let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        body(ctx)
        return ctx.makeImage()
    }

    private static func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGColor {
        CGColor(red: r, green: g, blue: b, alpha: 1)
    }
}
