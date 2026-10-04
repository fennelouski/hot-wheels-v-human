import Foundation
import ImageIO
import UIKit
import Testing
@testable import Hot_Wheels_v_Human

@MainActor @Suite(.serialized)
struct GameLoopTests {
    @Test func absentPreferencesAreOnAndSavedChoicesSurviveAnotherStore() throws {
        let suite = "HWvH.Unit.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = GamePreferences(defaults: defaults)
        #expect(first.animationsEnabled && first.hapticsEnabled)
        #expect(!first.reduceMotion(systemPreference: false))
        #expect(first.reduceMotion(systemPreference: true))
        first.animationsEnabled = false
        // Turning motion off must not implicitly turn haptics off.
        #expect(first.hapticsEnabled)
        first.hapticsEnabled = false
        let cold = GamePreferences(defaults: defaults)
        #expect(!cold.animationsEnabled && !cold.hapticsEnabled)
        #expect(cold.reduceMotion(systemPreference: false))
        cold.animationsEnabled = true
        #expect(cold.reduceMotion(systemPreference: true))
        #expect(!cold.hapticsEnabled)
    }

    @Test func finishSnapshotIsImmutableAndRanksFinishersBeforeOutCars() {
        let a = UUID(), b = UUID(), run = UUID(), track = UUID()
        var racers = [
            RaceSession.Racer(id: a, design: CarDesign.demoPair[0], entity: nil,
                              livesLeft: 3, topSpeed: 2.4, finishTime: 4.2),
            RaceSession.Racer(id: b, design: CarDesign.demoPair[1], entity: nil,
                              livesLeft: 0, topSpeed: 2.1, crashes: 3, isOut: true)
        ]
        let saved = RaceSession.freezeResult(id: run, trackID: track, name: "Wiggle Worm", clock: 5, racers: racers)
        racers[0].finishTime = 99
        racers[0].topSpeed = 0
        racers.removeAll()
        #expect(saved.id == run && saved.trackID == track)
        #expect(saved.winner?.id == a)
        #expect(saved.rankedEntries.last?.id == b)
        #expect(saved.entries[0].finishTime == 4.2 && saved.entries[0].topSpeed == 2.4)
        #expect(saved.entries[1].finishTime == nil && saved.entries[1].crashes == 3)
    }

    @Test func realImageAndResultRoundTripAndBadPayloadIsRejected() throws {
        let payload = fixture()
        #expect(payload.isValid)
        let sender = MessageCodec(), receiver = MessageCodec()
        #expect(try receiver.decode(sender.encode(.raceShare(payload))) == .raceShare(payload))
        #expect(try receiver.decode(sender.encode(.requestRaceShare)) == .requestRaceShare)
        let oversized = RaceSharePayload(result: payload.result, arenaImage: Data(repeating: 0, count: RaceSharePayload.maximumImageBytes + 1))
        #expect(!oversized.isValid)
        #expect(throws: MessageCodec.PayloadError.self) { try sender.encode(.raceShare(oversized)) }
        let corrupt = RaceSharePayload(result: payload.result, arenaImage: Data([0xff, 0xd8, 0xff, 0x00]))
        #expect(!corrupt.isValid)
        let oversizedEnvelope = try JSONEncoder().encode(MessageEnvelope(seq: 9, message: .raceShare(oversized)))
        #expect(throws: MessageCodec.PayloadError.self) { try receiver.decode(oversizedEnvelope) }
        // Existing opaque drawing data keeps its old wire contract. The new
        // share-image limit must not become a blanket car/photo message limit.
        var drawnCar = CarDesign.demoPair[0]
        drawnCar.drawingPNG = Data(repeating: 0x73, count: 2_400_000)
        let carMessage = GameMessage.carDesign(drawnCar, ownerID: nil)
        #expect(try receiver.decode(sender.encode(carMessage)) == carMessage)
    }

    @Test func standaloneTVHandoffTransfersFrozenBytesToDashboardAndStops() async throws {
        let pair = LoopbackTransport.pair()
        let payload = fixture()
        let handoff = RaceShareHandoff(transport: pair.host)
        let dashboard = DashboardModel(transport: pair.player, playerName: "Local test racer")
        defer { dashboard.stop(); handoff.stop() }
        handoff.start(payload: payload)
        dashboard.start()
        dashboard.requestRaceShare()
        for _ in 0..<1000 where dashboard.sharedRace == nil { await Task.yield() }
        #expect(dashboard.sharedRace == payload)
        #expect(dashboard.myCar == nil, "A share receipt does not invent a racer or telemetry")
        let immutableImage = try #require(dashboard.sharedRace?.arenaImage)
        #expect(immutableImage == payload.arenaImage)
        handoff.stop()
        #expect(pair.host.state == .idle)
        dashboard.stop()
        #expect(dashboard.sharedRace == nil)
    }

    @Test func nativeExportIsADecodableImageWithTheRealFrameAndResult() throws {
        try #require(HWTestSession.isActive, "An export test must never use production file storage")
        let payload = fixture()
        let image = try #require(RaceShareRenderer.image(payload))
        #expect(image.size.width == 1200)
        #expect(image.size.height > 600)
        let file = try RaceShareRenderer.file(payload)
        defer { try? FileManager.default.removeItem(at: file) }
        #expect(file.path.hasPrefix(HWTestSession.directory.path))
        let bytes = try Data(contentsOf: file)
        let source = try #require(CGImageSourceCreateWithData(bytes as CFData, nil))
        let decoded = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(decoded.width == 1200)
        #expect(RaceShareResult.appURL.absoluteString == "https://apps.apple.com/app/id6818777508")
        // The green fixture frame is real source pixels: inspect its center in
        // the exported card, rather than testing a renderer implementation string.
        var pixels = [UInt8](repeating: 0, count: decoded.width * decoded.height * 4)
        let context = try #require(CGContext(data: &pixels, width: decoded.width, height: decoded.height,
            bitsPerComponent: 8, bytesPerRow: decoded.width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(decoded, in: CGRect(x: 0, y: 0, width: decoded.width, height: decoded.height))
        let green = stride(from: 0, to: pixels.count, by: 4).filter {
            pixels[$0] < 80 && pixels[$0 + 1] > 200 && pixels[$0 + 2] < 80
        }.count
        #expect(green > decoded.width * decoded.height / 10, "The incoming frame must occupy the exported artifact")
    }

    private func fixture() -> RaceSharePayload {
        let arena = UIGraphicsImageRenderer(size: CGSize(width: 160, height: 90)).image { context in
            UIColor.green.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 160, height: 90))
        }
        let result = RaceShareResult(id: UUID(), trackID: UUID(), trackName: "Sample track", raceClock: 4.5,
            entries: [.init(id: UUID(), carName: "Copper Comet", finishTime: 4.5, topSpeed: 2.8, crashes: 0)])
        return RaceSharePayload(result: result, arenaImage: arena.pngData()!)
    }
}
