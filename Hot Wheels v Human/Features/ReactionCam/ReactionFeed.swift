//
//  ReactionFeed.swift
//  Hot Wheels v Human
//
//  Bridges live race state → per-racer ReactionDirectors. Called every
//  frame from ArenaView's scene subscription; detects discrete events by
//  diffing racer stats (crash count up = crashed, meter emptied = boost,
//  finish time set = celebrate) so no extra event plumbing is needed.
//

import Foundation
import Observation
import RealityKit

@MainActor
@Observable
final class ReactionFeed {

    private(set) var directors: [UUID: ReactionDirector] = [:]

    private struct Prev {
        var yaw: Float = 0
        var crashes = 0
        var boostMeter: Float = 0
        var finished = false
    }
    private var prev: [UUID: Prev] = [:]

    func tick(session: RaceSession, dt: TimeInterval) {
        guard dt > 0 else { return }
        for racer in session.racers {
            let director = directors[racer.id] ?? {
                let d = ReactionDirector()
                directors[racer.id] = d
                return d
            }()
            var last = prev[racer.id] ?? Prev()

            if racer.crashes > last.crashes {
                director.fire(.crashed)
            } else if racer.finishTime != nil && !last.finished {
                director.fire(.celebrating)
            } else if last.boostMeter >= 0.9 && racer.boostMeter <= 0.1 {
                director.fire(.boosted)
            }

            var yaw: Float = last.yaw
            if let entity = racer.entity {
                let forward = entity.orientation.act([0, 0, 1])
                yaw = atan2(forward.x, forward.z)
            }
            var yawDelta = yaw - last.yaw
            if yawDelta > .pi { yawDelta -= 2 * .pi }
            if yawDelta < -.pi { yawDelta += 2 * .pi }

            director.update(dt: dt,
                            yawRate: yawDelta / Float(dt),
                            loopAhead: session.loopAhead(for: racer.id,
                                                         within: RaceTuning.loopBraceLookahead))

            last.yaw = yaw
            last.crashes = racer.crashes
            last.boostMeter = racer.boostMeter
            last.finished = racer.finishTime != nil
            prev[racer.id] = last
        }
    }
}
