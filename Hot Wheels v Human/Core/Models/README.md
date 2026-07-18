# Core/Models/ — domain types & wire protocol (Phase 1)

Files to create
- `PlayerInfo.swift` — `id: UUID`, `name`, `deviceRole`.
- `CarDesign.swift` — `chassis: ChassisClass`, `tires: TireType`, `paint: PaintSpec (colorHex, finish: metallic|glossy|matte)`, `id`, `name`. Plus `ChassisClass`/`TireType` enums exposing `mass`, `dragCoefficient`, `modelName`, friction/restitution (values read from `RaceTuning`).
- `DriverProfile.swift` — helmet/suit colors, skinTone, hair, name.
- `TrackBlueprint.swift` — `trackId`, `lanes`, ordered `[SegmentSpec]` where `SegmentSpec = { index, type: PieceType }`. **No rotation field** — orientation is derived by `TrackLayoutSolver` (v1 PRD had explicit rotations; deriving kills invalid-data bugs).
- `MatchConfig.swift` — mode (solo/onePlayer/twoPlayer/test), laps, lives (default 5), aiDifficulty.
- `RaceState.swift` — `RaceSnapshot` (per-car: progress, speed, boostMeter, livesLeft, lane; raceClock, phase), `RaceEvent` enum (countdownTick, carDestroyed, respawned, finished, blueprintRejected(reason)).
- `GameMessage.swift` — the enum from ARCHITECTURE.md §Key protocols; version field `protocolVersion: Int` in `hello` for forward compat.
- `SwiftDataRecords.swift` — `@Model` wrappers (`CarDesignRecord`, `TrackBlueprintRecord`, `DriverProfileRecord`, `KidProfileRecord`) storing the Codable structs as JSON blobs (simplest, migration-proof). iPad-only usage. `DriverProfileRecord.ownerProfileID` links characters to their kid profile (nil = pre-profile orphan, never shown); `KidProfileRecord.lastUsedDriverID` remembers who's racing.

C-series additions (character creation — `Documents/CHARACTER-SPEC.md`)
- `DriverProfile` grew hair/eye/pants colors, hat, glasses, and faceDrawingPNG — all optional so old JSON decodes. `CarDesign.driver: DriverProfile?` carries the character over the wire inside the design (stamped by `AppModel.stampedRaceDesign()`).
- `DriverPalette.swift` — every editor swatch, the rig's 32×32 stripe-row ranges, and `nearest(hex:in:)` snapping (shared by the editor and the camera lookalike).
- `KidProfile.swift` — the local "Who's playing?" profile {id, name, colorHex}.
- `StarterPresets.swift` — the ready-on-first-launch lineup: 7 preset tracks (serpentine sprints, 20/27/35/42/50/60/75 pieces, loop or jump in every track from #3 on), 10 preset cars, 5 preset characters. Fixed UUIDs (`90000000-…` tracks, `CA90…` cars, `DA90…` characters) keep selection identity stable. Lengths + thrill rule asserted in `StarterPresetTests`.

Tests (`Hot Wheels v HumanTests/ModelTests.swift`): Codable round-trips for every message case; blueprint JSON matches PRD §4 sample; enum raw-value stability (wire compat).
