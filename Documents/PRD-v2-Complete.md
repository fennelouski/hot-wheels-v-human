# Hot Wheels vs. Human — Product Requirement Document v2 (Complete)

> Supersedes: `Hot Wheels v Human —Product Requirement Document.md` (v1, kept for history).
> Status: Ready for implementation. Companion docs: `ARCHITECTURE.md`, `BUILD-ORDER.md`, `XCODE-SETUP.md`.

## 1. Executive Summary & Vision

**Hot Wheels vs. Human** is a local-network multiplayer racing and sandbox creation game for iPad + Apple TV. Players build toy-scale tracks and custom cars on the iPad, then race them in a physics-simulated 3D arena rendered on the Apple TV. The iPad becomes a live dashboard controller during races.

**Narrative:** Custom "Human" creations (player-driven inputs, live driver reaction cam) vs. the autonomous speed machines of the "Hot Wheels" AI.

### 1.1 Naming note (important before any public release)
"Hot Wheels" is a Mattel trademark. Totally fine for a personal/family project and internal code, but rename before TestFlight external testing or App Store release (ideas: *Loop Legends*, *Track Attack*, *Gravity Garage*, *Orange Track Showdown*). Code uses the neutral prefix `HWVH` so a rename is cosmetic.

### 1.2 Technology stack (verified July 2026)
| Layer | Choice | Why |
|---|---|---|
| Language / UI | Swift 6 + SwiftUI | Native, one codebase for iPad + TV |
| 3D engine | **RealityKit** (RealityView) | As of WWDC25/tvOS 26, RealityKit runs on tvOS — same API on iPadOS, tvOS, macOS. SceneKit is deprecated. The PRD v1 stack is now fully supported by Apple. |
| Physics | RealityKit rigid-body simulation (`PhysicsBodyComponent`, `PhysicsSimulationComponent`) | Built into RealityKit; deterministic enough for toy racing |
| Assets | USDZ (converted from CC0 GLB sources, already downloaded in `Graphics/`) | RealityKit's native format |
| Networking | Multipeer Connectivity (`MCSession`) | Zero-config local Wi-Fi/Bluetooth peer-to-peer; supported on both iPadOS and tvOS; `.reliable` + `.unreliable` delivery |
| Persistence | SwiftData (already in template) | Save cars, tracks, race records on iPad |
| Min OS | iPadOS 26 / tvOS 26 | Required for RealityKit on tvOS |

**Project structure decision:** the existing Xcode 26 project uses filesystem-synchronized folders — every file placed under `Hot Wheels v Human/` on disk automatically becomes part of the build. We extend the *single existing target* to also build for tvOS (`SUPPORTED_PLATFORMS += appletvos appletvsimulator`, `TARGETED_DEVICE_FAMILY += 3`) rather than adding a second target. Platform differences are handled with `#if os(tvOS)`. See `XCODE-SETUP.md`.

## 2. Game Modes & Core Loop

### 2.1 Modes
1. **1-Player (Human vs. AI):** Player builds track + car, races an AI-driven "Hot Wheels" opponent. AI difficulty = boost-timing heuristics (see §6.4).
2. **2-Player (Human vs. Human):** Split-screen customization on one iPad (screen splits horizontally; far player's half is rotated 180°). Both race on the TV; each half of the iPad is that player's dashboard.
3. **Test Mode (Benchmarking):** One player, two of their own car designs side-by-side, no lives, no boosts — pure physics A/B test with result stats (time per segment, top speed, loop success).

### 2.2 Loop
```
BUILD & CUSTOMIZE (iPad) → NETWORK SYNC (iPad→TV, JSON) → RACE (TV renders/simulates; iPad = dashboard)
```

### 2.3 Fallback when no Apple TV is present
The same app on iPad can host the arena full-screen (RealityKit is identical on both platforms). "Solo Arena" mode: build on iPad, race on the same iPad. This is also the primary development loop in the Simulator — build every feature iPad-first, then verify on tvOS. This dramatically speeds up Claude Code iteration.

## 3. Feature Specifications

### 3.1 Car & Driver Customizer (iPad)
**Chassis classes** (each maps to a physics parameter set and a set of USDZ models from the Kenney kits):

| Class | Mass | Drag | Base model candidates (Graphics/) |
|---|---|---|---|
| Heavy-Duty Muscle | 1.6 kg | high | `vehicle-monster-truck`, `truck`, `suv` |
| Balanced Formula | 1.0 kg | med | `race`, `vehicle-racer`, `sedan-sports` |
| Super-light Drift | 0.6 kg | low | `vehicle-speedster`, `race-future`, `vehicle-drag-racer` |

**Tires** (separate wheel models exist in both Kenney kits — `wheel-default`, `wheel-racing`, `wheel-dark`, `wheel-small/medium/large`):

| Tire | Friction (static/dynamic) | Restitution |
|---|---|---|
| Standard | 0.8 / 0.6 | 0.1 |
| Slick Racing | 0.6 / 0.45 (faster, slides in curves) | 0.05 |
| Grippy Off-road | 1.0 / 0.85 (slow, loop-safe) | 0.15 |

**Paint Shop:** color wheel + finish picker (metallic / glossy / matte) applied by overriding the USDZ's `PhysicallyBasedMaterial` (baseColor, metallic, roughness) at load time. No texture editing needed — the Kenney models are flat-colored, ideal for tinting.

**Driver customization:** helmet color, suit color, skin tone, hair, and name. Avatar base = `quaternius_animated_human` (rigged, CC0). Face reactions are done with a swappable "face decal" quad (texture swap: normal / wide-eyed / gritted / facepalm) rather than facial rigging — dramatically simpler and reads great at PiP size.

**Persistence:** every car/driver design saved via SwiftData (`CarDesign`, `DriverProfile` models).

### 3.2 Modular Track Builder (iPad)
2D top-down drag-and-snap board that outputs a `TrackBlueprint` (JSON). The builder is purely 2D/schematic on iPad (fast, simple); the TV converts blueprint → 3D.

**Piece inventory v1** (all exist as GLB in `Graphics/3DModels/Source/kenney_toy-car-kit`, wide + narrow variants):

| PieceType | Model | Grid footprint | Notes |
|---|---|---|---|
| `startGate` | `gate` | 1×1 | dual-lane start grid |
| `finishGate` | `gate-finish` | 1×1 | checkered banner |
| `straight` | `track-wide-straight` | 1×1 | base acceleration zone |
| `curve90L` / `curve90R` | `track-wide-corner-small` (mirrored) | 1×1 | 90° turn |
| `curveLarge` | `track-wide-corner-large` | 2×2 | sweeping turn |
| `hillUp` / `hillDown` | `track-wide-straight-hill-*` | 1×1 | elevation change |
| `bump` | `track-wide-straight-bump-up/down` | 1×1 | jump risk |
| `loop` | `track-narrow-looping` | 1×1 (tall) | requires min entry speed |
| `rampJump` | `track-wide-corner-*-ramp` / OGA `jump1/2` | 1×1 | gap jump, cars can collide mid-air |

**Snapping:** each piece definition carries `entry` and `exit` connection transforms (position + heading on a unit grid). The builder maintains a **path list** (ordered array); a new piece may only attach to the open exit, and its rotation is derived automatically. Closing the loop back to the start gate = valid circuit; a finish gate placement = valid sprint. Validation rules: max 40 pieces, track may not self-intersect at same elevation (grid-cell + level check), must contain exactly one start gate.

**Editing UX:** piece palette (bottom), grid canvas (center, pinch-zoom), tap-to-delete-last, "shuffle" random-track button (kid-friendly!), live piece count and estimated difficulty meter. Saved tracks in SwiftData (`TrackBlueprintRecord`).

### 3.3 Racing & Physics (TV Arena)
- **Authority:** the Apple TV is the *single source of physics truth*. iPads send inputs only; TV broadcasts race state snapshots at 10 Hz for dashboard UI.
- **Scale & units:** 1 RealityKit unit = 1 m. Cars ≈ 0.4 m long (10× toy scale — physics is far more stable than true 1:64 scale). Gravity default −9.81 m/s²; a "Toy Gravity" tuning constant multiplier lives in `RaceTuning.swift` since toy loops feel better around 0.7–0.85 g.
- **Track physics:** every spawned piece gets `PhysicsBodyComponent(mode: .static)` with `ShapeResource.generateStaticMesh` collision from its geometry. Cars are `.dynamic` with a box collision shape (not mesh — cheaper and more stable) + `PhysicsMaterialResource` from tire choice.
- **Propulsion model (v1, simple and tunable):** cars are self-propelled with a constant forward drive force along the track direction (slot-car model) — steering is automatic via waypoint spline following (cars can't leave lanes except by physics accidents: flying off on jumps/bumps/loops or excess speed in curves). This keeps the game "watch physics unfold + time your boost," matching the PRD's toy fantasy. Boost = `applyLinearImpulse` along current heading.
- **Loop rule of thumb:** loop radius r ≈ 0.5 m ⇒ minimum entry speed v = √(g·r) ≈ 2.2 m/s at 1 g. Tuning targets live in `RaceCore/RaceTuning.swift`.
- **Dual lanes:** two parallel waypoint splines offset ±laneWidth/2 from the piece centerline. Collisions possible on jumps and bumps where cars physically leave their spline guidance.
- **The 5-Chance system:** each player starts with 5 cars (garage UI on iPad shows 5 slots). Car destroyed when: off-track (fell below track plane − 1 m), stuck (speed < 0.05 m/s for 3 s), or flipped for 3 s. Destruction spawns Kenney debris models (`debris-*` GLBs — already in the car kit!) with impulses, plays crash SFX, decrements garage, respawns next car at last checkpoint gate after 2 s. Zero cars left = race lost.
- **Win conditions:** first to finish (sprint) or first to N laps (circuit); opponent out of cars = win.

### 3.4 In-race iPad Dashboard
- **Boost:** circular energy meter charges over time (full in ~8 s, tunable; pickups can add charge later). Tap when full → `boost` message (`.unreliable`, but retried ×3 with dedupe token since it's gameplay-critical) → TV applies impulse + tailpipe VFX + engine roar.
- **Reaction Cam ("Up" button):** press-and-hold sends `reactionCamOn/Off`. TV shows a circular PiP (bottom corner of that player's lane side) rendering the driver avatar close-up. Implementation: a second small `RealityView` with its own `PerspectiveCamera` aimed at an off-stage copy of the driver bust; animation state driven by physics events (steering lean, loop brace, boost push-back, crash facepalm) using the face-decal swap + skeletal poses. If two RealityViews prove heavy on Apple TV, fallback: pre-render reaction states as sprite sheet.
- **Dashboard also shows:** lap/segment progress bar, current speed, garage (lives) slots, opponent gap, and big "READY" state before the race.

### 3.5 Audio
| Event | File (to source per `Audio/README.md`) |
|---|---|
| Engine loop (pitch scales with speed) | `car_engine_loop.wav` |
| Boost | `speed_boost_fire.wav` |
| Track piece snap (builder) | `track_snap_connect.wav` |
| Crash + debris | `car_crash_metal.wav` |
| Countdown 3-2-1-GO | `race_countdown.wav` |
| Workshop music | `workshop_ambience.mp3` |
| Race music | `race_intensity.mp3` |

Playback via `AudioFileResource` attached to entities (spatial on TV) and `AVAudioPlayer` for UI/music on iPad.

## 4. Networking Protocol

Multipeer Connectivity, service type **`hwvh-race`** (≤15 chars, valid charset). TV = advertiser/host, iPads = browsers. Requires `NSLocalNetworkUsageDescription` + `NSBonjourServices` (`_hwvh-race._tcp`, `_hwvh-race._udp`) in Info.plist — races won't connect without these. See `XCODE-SETUP.md`.

All payloads are `Codable` envelopes:

```swift
enum GameMessage: Codable {
    // reliable
    case hello(PlayerInfo)
    case trackBlueprint(TrackBlueprint)
    case carDesign(CarDesign)         // per player
    case matchConfig(MatchConfig)     // mode, laps, lives
    case readyState(playerID: UUID, ready: Bool)
    case raceEvent(RaceEvent)         // countdown, carDestroyed, respawn, finished
    // unreliable, high-frequency
    case boost(playerID: UUID, token: UUID)
    case reactionCam(playerID: UUID, on: Bool)
    case raceSnapshot(RaceSnapshot)   // TV → iPads @10Hz: positions, speeds, meters, lives
}
```

`TrackBlueprint` (unchanged in spirit from v1):
```json
{ "trackId": "uuid", "lanes": 2,
  "segments": [
    { "index": 0, "type": "startGate" },
    { "index": 1, "type": "straight" },
    { "index": 2, "type": "loop" },
    { "index": 3, "type": "curve90R" },
    { "index": 4, "type": "finishGate" } ] }
```
Rotations are derived from the path (v1 stored explicit rotations; deriving them eliminates an entire class of invalid data).

Connection lifecycle: auto-reconnect with session resume; if an iPad drops mid-race the TV pauses after 5 s grace. Single-iPad "Solo Arena" bypasses networking entirely behind the same `GameTransport` protocol (a `LoopbackTransport` implementation) — this is what makes everything testable in Simulator/CI.

## 5. Assets (resolved — see `Graphics/README.md` for inventory + licenses)
- **Track pieces, gates, supports, items, toy cars:** Kenney *Toy Car Kit* (100 models, CC0) — literally a toy-track construction kit incl. `track-narrow-looping`.
- **More cars, karts, wheels, and crash debris:** Kenney *Car Kit* (45 models, CC0).
- **Extra loop/ramp geometry:** OpenGameArt *Modular Racetrack* by Fertile Soil Productions (CC0, OBJ).
- **Rigged driver:** Quaternius *Animated Human* (CC0; FBX/Blend/OBJ/DAE).
- **Pipeline:** GLB → USDZ via Reality Converter (or `usdzconvert`/Blender) on the Mac, output into `Hot Wheels v Human/Resources/Models3D/`. Track pieces get their entry/exit connection metadata in code (`TrackKit/PieceCatalog.swift`), not in the USDZ.

## 6. Detailed Behavior Specs

### 6.1 Race state machine (TV)
`lobby → collectingDesigns → buildingTrack → countdown(3s) → racing → paused | finished → results → lobby`

### 6.2 Checkpoints & progress
Each piece boundary is a checkpoint (piece index). Progress = (lap, pieceIndex, t-along-piece). Used for: respawn location, progress bar, "wrong-way"/stuck detection, finish detection.

### 6.3 Split-screen 2P customization
`CustomizerSplitView` = VStack of two independent `CustomizerView`s, top one `.rotationEffect(.degrees(180))`. Each half owns its player context. Builder is shared (one track) — after customization, Player 1 builds the track while Player 2's half shows a "hype" preview carousel of both cars.

### 6.4 AI opponent ("The Hot Wheels")
Same simulation as human cars (fair!). AI differences: pre-built car from a themed roster (`kart-*`, `race-future` — robotic liveries) and a boost policy: easy = random timing; medium = boosts on straights; hard = boosts optimally out of curves and never before loops it can't survive. AI never gets stat bonuses — difficulty is purely decision quality.

### 6.5 Error / edge cases
- iPad rotates or app backgrounds mid-race → dashboard rejoins with state from next snapshot.
- Track blueprint fails validation on TV (version mismatch) → TV replies `raceEvent(.blueprintRejected(reason))`, iPad shows fix-it message.
- Only 1 iPad + mode 2P → not allowed; 2P is single-iPad split-screen by design (v1). Two-iPad 2P is a v2 stretch goal — the protocol already supports it (messages carry `playerID`).
- Photosensitivity: no strobe VFX; boost glow is a smooth pulse.

## 7. Milestones (summary — full dependency-ordered plan in `BUILD-ORDER.md`)
- **M0** Project config: tvOS platform enabled, folders live, one USDZ loading in a RealityView on both platforms.
- **M1** TrackKit: blueprint model, validation, piece catalog, 3D spawner (works iPad-solo, no networking).
- **M2** RaceCore: physics tuning, spline follower, loop clearing, checkpoints, 5-chance system, Test Mode. **This is the fun-proof milestone.**
- **M3** Networking: Multipeer transport, lobby, blueprint sync, TV arena, dashboard w/ boost.
- **M4** Customizer: chassis/tires/paint, SwiftData persistence, split-screen 2P.
- **M5** Drivers & Reaction Cam, AI opponent, audio, VFX, results screen, polish.

## 8. Non-goals (v1)
Online play, more than 2 players, track sharing, in-app purchases, iPhone layout (iPad-only + TV), custom car geometry editing (chassis are preset models + paint), replays.

## 9. Success criteria
A 9-year-old can build a track with a loop in under 2 minutes, race dad, lose 3 cars to an over-ambitious loop, win with a perfectly timed boost, and immediately ask for a rematch.
