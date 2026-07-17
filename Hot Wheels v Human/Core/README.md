# Core/ — platform-neutral game logic (no SwiftUI imports)

Four modules, all unit-testable headlessly. Build order: `Models` → (`Networking`, `TrackKit` in parallel) → `RaceCore`.

| Folder | What | Phase |
|---|---|---|
| `Models/` | Domain types + `GameMessage` protocol envelope | 1 |
| `Networking/` | `GameTransport` protocol, Multipeer + Loopback implementations | 3 (Loopback earlier) |
| `TrackKit/` | Piece catalog, blueprint validation, layout solving, 3D spawning | 1 |
| `RaceCore/` | Physics config, drive/rules ECS systems, tuning constants | 2 |

Hard rules
1. No `import SwiftUI` anywhere under `Core/`. RealityKit imports are allowed in `TrackKit`/`RaceCore` (entity spawning is core logic).
2. Everything `Codable` in `Models/` gets a round-trip unit test.
3. All magic numbers → `RaceCore/RaceTuning.swift`.
4. Types are `Sendable` where possible; transports and asset caches are actors.
