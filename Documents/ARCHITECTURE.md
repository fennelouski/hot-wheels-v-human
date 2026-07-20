# Architecture — Hot Wheels vs. Human

One Xcode target, three roles. The same binary runs as:
- **Workshop + Dashboard** (iPadOS)
- **Arena host** (tvOS)
- **Solo Arena** (iPadOS, arena + dashboard in one screen — the dev/test loop)

```
┌────────────────────────── iPad (client) ──────────────────────────┐
│ SwiftUI: Home │ Customizer │ TrackBuilder │ Dashboard             │
│ SwiftData: CarDesign, DriverProfile, TrackBlueprintRecord         │
│ GameTransport (Multipeer .browser)  ── or ── LoopbackTransport    │
└──────────────────────────────┬────────────────────────────────────┘
              GameMessage (Codable) · .reliable / .unreliable
┌──────────────────────────────┴────────────────────────────────────┐
│ Apple TV (host)                                                   │
│ RaceCoordinator (state machine, authoritative)                    │
│ TrackKit spawner → RealityKit scene → RaceCore physics systems    │
│ RealityView (arena camera) + PiP RealityView (reaction cam)       │
└───────────────────────────────────────────────────────────────────┘
```

## Module map (all inside `Hot Wheels v Human/` so the synced folder auto-builds them)

| Module | Folder | Depends on | Platform |
|---|---|---|---|
| App entry, routing | `App/` | all below | both |
| Domain models + messages | `Core/Models/` | — | both |
| Transport (Multipeer + loopback) | `Core/Networking/` | Models | both |
| Track blueprint, catalog, validation, 3D spawn | `Core/TrackKit/` | Models | both |
| Physics, spline follow, race rules, tuning | `Core/RaceCore/` | Models, TrackKit | both |
| Home / lobby UI | `Features/Home/` | Networking | both |
| Car & driver customizer | `Features/Customizer/` | Models | iPad |
| 2D track builder | `Features/TrackBuilder/` | TrackKit | iPad |
| In-race controller UI | `Features/Dashboard/` | Networking, Models | iPad |
| 3D race arena | `Features/Arena/` | TrackKit, RaceCore | TV + iPad(solo) |
| Driver PiP camera | `Features/ReactionCam/` | RaceCore | TV + iPad(solo) |

Rules:
1. `Core/*` never imports SwiftUI (except tiny `Color`-ish helpers — prefer none). Pure logic, unit-testable.
2. `Features/*` never talk to each other directly — they communicate through `AppModel` (observable app state) and `GameTransport`.
3. Platform splits use `#if os(tvOS)` sparingly and only inside `App/` and `Features/Arena|Home`. Everything else is platform-neutral.
4. TV is authoritative for physics; iPads render UI from `RaceSnapshot`s. Never simulate on iPad in networked mode.
5. Every gameplay constant lives in `Core/RaceCore/RaceTuning.swift` — one file to tweak feel.

## Key protocols

```swift
protocol GameTransport: AnyObject {
    var events: AsyncStream<TransportEvent> { get }   // connected, message, dropped
    func send(_ message: GameMessage, reliably: Bool)
    func start(role: TransportRole)                   // .host (TV/solo) or .player
    func stop()
}
```
`MultipeerTransport` (real) and `LoopbackTransport` (solo + unit tests) both implement it. All game code is transport-agnostic.

```swift
struct TrackPieceDefinition {           // Core/TrackKit/PieceCatalog.swift
    let type: PieceType
    let modelName: String               // USDZ in Resources/Models3D
    let modelYaw/modelOffset: …         // model placement in the traversal frame
    let exitOffset: SIMD3<Float>        // where the next piece's entry lands
    let headingChange: Float            // yaw delta, + = left
    let elevationDelta: Int
    let footprint: FootprintRect        // nominal ground rect (tab-free)
    let shape: CenterlineShape          // line / arc / verticalLoop → splines
    let minEntrySpeed: Float?           // loops/jumps
}
```
Connection metadata lives in code, not in the USDZ files — models stay untouched from Kenney.
Reality note: the Kenney pieces are **not** a uniform grid (straight = 0.8 m between
connectors, small-corner radius = 0.4 m), so pieces carry measured real-valued
offsets in a "traversal frame" (entry at origin, travel +Z, surface y = 0) instead
of the originally planned grid `ConnectionPoint`s. Headings stay multiples of 90°,
so validator overlap checks use axis-aligned world rects.

The **loop** is the piece that breaks the "footprint = what the piece occupies"
assumption, and it is worth knowing before touching layout code. Its two connect
points sit at the *same* spot (`exitOffset = [-0.2, 0, 0]`): it climbs, crosses
over, and sets the car down one bed width to the RIGHT, advancing nothing. Its arc
then bulges ±0.4 m fore and aft, so the straights it joins run **under** it. That
makes it an overpass, and `BlueprintValidator` skips its rect in the overlap check
for exactly that reason — everything else is still checked normally.

## RealityKit specifics
- `RealityView { content in ... } update: { ... }` on both platforms; camera = `PerspectiveCamera` entity (chase camera rig follows leader car; smooth via lerp each frame).
- ECS: custom components `CarComponent`, `LaneFollowComponent`, `CheckpointComponent`; custom `System`s: `DriveSystem` (propulsion + steering toward spline), `RaceRulesSystem` (checkpoints, destruction, respawn), `CameraSystem`.
- Physics: track = `.static` + `generateStaticMesh` collision; cars = `.dynamic` + box shape + tire `PhysicsMaterialResource`; debris = short-lived `.dynamic` entities with despawn timer.
- Subscribe to `CollisionEvents.Began` for crash detection/SFX.
- Load USDZ with `Entity(named:in:)` async at arena build time; cache in an `AssetStore` actor. Show progress on TV during `buildingTrack` state.

## Data flow example: the boost (HELD, not tapped)
1. iPad Dashboard: **touch DOWN** on the dial → `DashboardModel.beginBoost()` heartbeats `.boost(playerID:token:)` unreliably every 66 ms until touch up. The packet is a "finger is down" signal, not an event — the token is ignored.
2. TV `RaceCoordinator`: no dedupe (repeats are the hold signal). Each packet calls `RaceSession.requestBoost`, which refreshes `boostHoldGrace` and — the first time, if `boostMeter >= 1` — starts the burn.
3. `DriveSystem.stepBoost` runs the whole meter each frame: charges to 1 (armed) then to 2 at half rate (overcharge), or burns it down at `1 / boostDrainTime` while boosting, returning a thrust that ramps up the longer the button is held (`boostAccel[chassis]` — the garage stat). The burn ends when the grace lapses (finger up) or the bottle empties, but never before `boostMinDuration`, so a tap is still a real boost.
4. iPad receives snapshots → the dial needle falls as it burns, thumping haptically.

Packet loss is a non-event in both directions: a dropped heartbeat costs milliseconds of thrust, and a dropped *release* just times the burn out after `boostHoldGrace`.

## Testing strategy
- `Core/*` = plain XCTest (blueprint validation, snapping math, message codec round-trips, meter/lives logic) — runs headless, perfect for Claude Code.
- Physics feel = human-in-the-loop via **Test Mode** on iPad Simulator (solo arena); tuning values in one file.
- `LoopbackTransport` lets full race flows run in one process for integration tests.
