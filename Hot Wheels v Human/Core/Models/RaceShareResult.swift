import Foundation
import ImageIO

/// Values frozen by the normal finish path. No Entity references or live state
/// survive into an exported result, so a rematch cannot rewrite the old race.
nonisolated struct RaceShareResult: Codable, Equatable, Sendable, Identifiable {
    struct Entry: Codable, Equatable, Sendable, Identifiable {
        let id: UUID
        let carName: String
        let finishTime: TimeInterval?
        let topSpeed: Float
        let crashes: Int
    }
    let id: UUID
    let trackID: UUID
    let trackName: String
    let raceClock: TimeInterval
    let entries: [Entry]
    static let appURL = URL(string: "https://apps.apple.com/app/id6818777508")!

    var rankedEntries: [Entry] {
        entries.enumerated().sorted {
            let a = $0.element.finishTime ?? .greatestFiniteMagnitude
            let b = $1.element.finishTime ?? .greatestFiniteMagnitude
            return a == b ? $0.offset < $1.offset : a < b
        }.map(\.element)
    }
    var winner: Entry? { rankedEntries.first { $0.finishTime != nil } }
}

/// An actual arena frame, carried once on the reliable local channel. This is
/// deliberately separate from the tiny ten-Hz race snapshot packets.
nonisolated struct RaceSharePayload: Codable, Equatable, Sendable {
    static let maximumImageBytes = 2_000_000
    let result: RaceShareResult
    let arenaImage: Data

    var isValid: Bool {
        guard !arenaImage.isEmpty, arenaImage.count <= Self.maximumImageBytes,
              !result.entries.isEmpty, result.entries.count <= 8,
              result.raceClock.isFinite, result.raceClock >= 0,
              result.trackName.count <= 512 else { return false }
        let jpeg = arenaImage.starts(with: [0xff, 0xd8, 0xff])
        let png = arenaImage.starts(with: [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])
        guard jpeg || png,
              let source = CGImageSourceCreateWithData(arenaImage as CFData, nil),
              CGImageSourceGetCount(source) == 1,
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? Int,
              let height = props[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0, width <= 4096, height <= 4096,
              width * height <= 4_000_000 else { return false }
        return result.entries.allSatisfy {
            $0.carName.count <= 512 && $0.topSpeed.isFinite && $0.topSpeed >= 0
                && $0.crashes >= 0 && ($0.finishTime.map { $0.isFinite && $0 >= 0 } ?? true)
        }
    }
}
