# BUILD-ORDER — the sequence Claude Code should follow

Each phase has a **Definition of Done (DoD)** and lists what it unblocks. Do not start a phase before its dependencies are done. Prefer many small commits; keep the app building at every step. iPad Simulator is the primary dev loop (Solo Arena); verify on tvOS Simulator at the end of each phase that touches Arena code.

## Phase 0 — Project configuration (½ day)
Deps: none.
1. Follow `XCODE-SETUP.md`: add tvOS to `SUPPORTED_PLATFORMS` + device family 3, set `TVOS_DEPLOYMENT_TARGET 26.0`, add local-network Info.plist keys, verify entitlements.
2. Remove SwiftData `Item.swift` boilerplate; move `Hot_Wheels_v_HumanApp.swift` + `ContentView.swift` into `App/`; app shows a placeholder Home screen with big "iPad Workshop" / "TV Arena" role indicator per platform.
3. Convert 3 pilot models to USDZ (one straight, one loop, one car — see `Graphics/README.md`) into `Resources/Models3D/`; display the car in a `RealityView` on iPad + tvOS simulators.
**DoD:** app builds & runs on iPadOS 26 sim and tvOS 26 sim, spinning car visible on both. ← proves the entire stack.

## Phase 1 — Core models + TrackKit (1–2 days)
Deps: P0.
1. `Core/Models/`: `PlayerInfo`, `CarDesign`, `DriverProfile`, `TrackBlueprint`, `MatchConfig`, `GameMessage` (+ codec unit tests).
2. `Core/TrackKit/`: `PieceCatalog` (definitions incl. entry/exit transforms for the 9 v1 pieces), `BlueprintValidator` (path continuity, footprint overlap, elevation, exactly-one start), `TrackLayoutSolver` (blueprint → world transforms per piece + the two lane splines as `[SIMD3<Float>]` waypoints).
3. `TrackSpawner`: blueprint → RealityKit entity hierarchy w/ static collision. Hardcoded demo blueprint renders in Solo Arena.
**DoD:** unit tests green for validator/solver; demo track (straight–loop–curve–finish) visibly assembled in 3D on iPad sim.

## Phase 2 — RaceCore: make it fun (2–4 days) ★ highest-risk, do early
Deps: P1.
1. `CarFactory`: chassis class + tires → entity with physics body/materials from `RaceTuning`.
2. `DriveSystem`: constant drive force + spline steering (PD controller toward lane waypoint, banking on curves); car completes flat circuit reliably.
3. Loop tuning: slow car fails the loop and falls; fast car makes it. Tune in `RaceTuning.swift` until it *feels* like toy physics (this is the game).
4. `RaceRulesSystem`: checkpoints, off-track/stuck/flipped detection, debris explosion (Kenney `debris-*`), 5-chance respawn, finish detection.
5. **Test Mode** screen (iPad): pick 2 saved designs → side-by-side run → stats table. First shippable fun.
**DoD:** in Solo Arena, two different car builds race a loop track; the heavy one clears the loop, the light one gets flung; destruction→debris→respawn works; Test Mode reports times.

## Phase 3 — Networking + TV Arena (2–3 days)
Deps: P1 (can overlap P2).
1. `LoopbackTransport` first (P2 already uses it implicitly in solo), then `MultipeerTransport` (`hwvh-race`): host advertise on TV, browse/join on iPad, auto-reconnect.
2. Lobby flow: TV shows join code/status; iPad hello → design/blueprint sync (`.reliable`); ready-up; countdown.
3. `RaceCoordinator` state machine on TV; `RaceSnapshot` broadcast @10 Hz; Dashboard renders progress/speed/lives from snapshots.
4. Boost round-trip (unreliable + token dedupe) with < 150 ms perceived latency.
**DoD:** real iPad + real/simulated Apple TV: build track on iPad → race renders on TV → boost tap visibly fires. (Multipeer does not work between two Simulators reliably — test with at least one real device.)

## Phase 4 — Customizer + persistence (2–3 days)
Deps: P1; P3 for sync (UI can start anytime).
1. Chassis/tire pickers with live 3D preview (`RealityView` turntable), paint wheel + finish via material override.
2. Driver customizer (colors, name, face preview).
3. SwiftData persistence + garage list; designs sync to TV.
4. Split-screen 2P layout (mirrored top half), both designs delivered to arena.
**DoD:** two kids on one iPad each build a car in <2 min and race their actual designs on TV with their chosen paint.

## Phase 5 — TrackBuilder UI (2–3 days)
Deps: P1 (validator/solver already exist — UI is thin).
1. Grid canvas + palette; add-to-open-exit interaction with auto-rotation; delete-last; piece count; save/load; "shuffle" random valid track generator.
2. Blueprint → TV sync + TV-side build progress screen.
**DoD:** a kid can draw straight→loop→curve→finish without reading anything; invalid moves are impossible, not error-messaged.

## Phase 6 — Drivers, Reaction Cam, AI, audio & polish (3–5 days)
Deps: P2–P5.
1. Driver avatar conversion (Quaternius FBX → USDZ w/ skeleton), seated pose in cars, reaction states (face decal swap + lean/brace poses driven by physics events).
2. Reaction Cam PiP (hold Up button → PiP on TV). Fallback to sprite reactions if 2nd RealityView is slow on device.
3. AI opponent boost policies (easy/med/hard) + robotic car roster for 1P mode.
4. Audio per `Audio/README.md`; engine pitch = f(speed); music ducking on countdown/finish.
5. Results screen (times, crashes, best segment), rematch button, app icon (kid should draw it — scan → `Assets.xcassets`!).
**DoD:** full loop of PRD §9 success criteria passes on real hardware.

## Phase 7 — Hardening (ongoing)
Reconnect drills, background/foreground, memory on 40-piece tracks (entity pooling for debris), tvOS top-shelf image, TestFlight internal build. Rename check (PRD §1.1) before anything public.

Sim-verified 2026-07-18 (post C-series): background→foreground mid-race survives (same process, results intact); 40-piece `--stress-track` RSS flat at ~497 MB over 65 s (up from ~192 MB pre-characters — driver textures/props — but zero growth). Still needs hardware: Multipeer reconnect drills (`MULTIPEER-HANDTEST.md`), device memory footprint.

## Suggested first Claude Code prompt
> Read CLAUDE.md, Documents/PRD-v2-Complete.md, Documents/ARCHITECTURE.md, Documents/XCODE-SETUP.md. Execute Phase 0 of Documents/BUILD-ORDER.md. Stop after the DoD is demonstrably met and report what you did.

## C-series — profiles & character creation (built after P7)
Local "Who's playing?" profiles, multiple named characters per profile, the
full-screen character editor, the stripe-palette driver paint pipeline, and
the on-device camera lookalike. Spec + phase table:
`Documents/CHARACTER-SPEC.md`.
