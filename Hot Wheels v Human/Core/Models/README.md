# Core/Models/ — domain types & wire protocol (Phase 1)

Files to create
- `PlayerInfo.swift` — `id: UUID`, `name`, `deviceRole`.
- `CarDesign.swift` — `chassis: ChassisClass`, `tires: TireType`, `paint: PaintSpec (colorHex, finish: metallic|glossy|matte)`, `id`, `name`. Plus `ChassisClass`/`TireType` enums exposing `mass`, `dragCoefficient`, `modelName`, friction/restitution (values read from `RaceTuning`).
- `DriverProfile.swift` — helmet/suit colors, skinTone, hair, name.
- `TrackBlueprint.swift` — `trackId`, `lanes`, ordered `[SegmentSpec]` where `SegmentSpec = { index, type: PieceType }`. **No rotation field** — orientation is derived by `TrackLayoutSolver` (v1 PRD had explicit rotations; deriving kills invalid-data bugs).
- `MatchConfig.swift` — mode (solo/onePlayer/twoPlayer/test), laps, lives (default 5), aiDifficulty.
- `RaceState.swift` — `RaceSnapshot` (per-car: progress, speed, boostMeter, livesLeft, lane; raceClock, phase), `RaceEvent` enum (countdownTick, carDestroyed, respawned, finished, blueprintRejected(reason)).
- `GameMessage.swift` — the enum from ARCHITECTURE.md §Key protocols; version field `protocolVersion: Int` in `hello` for forward compat.
- `SwiftDataRecords.swift` — `@Model` wrappers (`CarDesignRecord`, `TrackBlueprintRecord`, `DriverProfileRecord`) storing the Codable structs as JSON blobs (simplest, migration-proof). iPad-only usage.

Tests (`Hot Wheels v HumanTests/ModelTests.swift`): Codable round-trips for every message case; blueprint JSON matches PRD §4 sample; enum raw-value stability (wire compat).
