//
//  NetworkingTests.swift
//  Hot Wheels v HumanTests
//
//  Loopback full-flow, codec staleness dropping, boost dedupe.
//

import Foundation
import Testing
@testable import Hot_Wheels_v_Human

struct CodecTests {

    @Test func roundTripsThroughEnvelope() throws {
        let codec = MessageCodec()
        let message = GameMessage.readyState(playerID: UUID(), ready: true)
        let decoded = try codec.decode(codec.encode(message))
        #expect(decoded == message)
    }

    @Test func staleSnapshotsAreDropped() throws {
        let sender = MessageCodec()
        let receiver = MessageCodec()
        let snap = GameMessage.raceSnapshot(RaceSnapshot(raceClock: 1, phase: .racing, cars: []))
        let first = try sender.encode(snap)
        let second = try sender.encode(snap)
        #expect(try receiver.decode(second) != nil)   // newer arrives first
        #expect(try receiver.decode(first) == nil)    // older one is stale
    }

    @Test func boostTokensDedupe() {
        let deduper = TokenDeduper()
        let token = UUID()
        #expect(deduper.firstSighting(token))
        #expect(!deduper.firstSighting(token))
        #expect(!deduper.firstSighting(token))
        #expect(deduper.firstSighting(UUID()))
    }
}

@MainActor
struct LoopbackTests {

    @Test func fullPreRaceFlowReachesHost() async throws {
        let (host, player) = LoopbackTransport.pair()
        host.start(role: .host)
        player.start(role: .player)

        let info = PlayerInfo(id: UUID(), name: "Kid", deviceRole: .iPad)
        player.send(.hello(info, protocolVersion: gameProtocolVersion), reliably: true)
        player.send(.trackBlueprint(.demo), reliably: true)
        player.send(.readyState(playerID: info.id, ready: true), reliably: true)

        var received: [GameMessage] = []
        for await event in host.events {
            if case .message(let message) = event {
                received.append(message)
                if received.count == 3 { break }
            }
        }
        #expect(received[0] == .hello(info, protocolVersion: gameProtocolVersion))
        #expect(received[1] == .trackBlueprint(.demo))
        #expect(received[2] == .readyState(playerID: info.id, ready: true))
    }

    @Test func hostSnapshotReachesPlayer() async throws {
        let (host, player) = LoopbackTransport.pair()
        host.start(role: .host)
        player.start(role: .player)

        let snap = RaceSnapshot(raceClock: 2.5, phase: .racing, cars: [])
        host.send(.raceSnapshot(snap), reliably: false)

        for await event in player.events {
            if case .message(let message) = event {
                #expect(message == .raceSnapshot(snap))
                break
            }
        }
    }
}
