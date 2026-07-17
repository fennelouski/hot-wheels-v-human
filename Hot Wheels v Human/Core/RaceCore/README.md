# Core/RaceCore/ — physics, race rules, tuning (Phase 2 — the fun lives here)

Files to create
- `RaceTuning.swift` — **exists since Phase 1** with the constants Models/TrackKit need (gravityScale, chassis/tire tables, lane offsets, waypoint spacing, loop min speed, elevation level height, max pieces, lives). Phase 2 adds: drive force per chassis, boost impulse (start 1.5 N·s), meter charge time (8 s), destruction thresholds (fall −1 m, stuck <0.05 m/s ×3 s, flipped ×3 s), respawn delay (2 s), snapshot rate (10 Hz). One flat enum, obsessively commented.
- `CarFactory.swift` — `CarDesign` → car `Entity`: USDZ chassis + 4 wheel models attached, box collision (`ShapeResource.generateBox` from visual bounds ×0.9), `PhysicsBodyComponent(massProperties:material:mode:.dynamic)`, paint applied by walking model materials → tinted `PhysicallyBasedMaterial`. Adds `CarComponent` (playerID, lane) + `LaneFollowComponent` (spline ref, progress index).
- `DriveSystem.swift` — RealityKit `System`. Per car per frame: find target waypoint ahead (lookahead ~0.3 m), apply drive force along spline tangent, PD-steer torque toward tangent, soft "magnet" force toward spline when |offset| < 0.15 m (keeps slot-car feel while letting big physics violations win — flying off IS the game). Applies queued boost impulses.
- `RaceRulesSystem.swift` — checkpoint crossing (piece boundaries), lap/finish detection, destruction checks per RaceTuning, debris spawn (`debris-*` models, random impulses, 3 s despawn), life decrement, respawn at last checkpoint after delay, win/lose determination. Emits `RaceEvent`s via delegate closure (RaceCoordinator forwards to transport).
- `RaceCoordinator.swift` — host-side state machine `lobby → collectingDesigns → buildingTrack → countdown → racing → paused/finished → results`. Owns transport events in, snapshots out @10 Hz, boost validation (server-side meter), AI opponent driver.
- `AIBoostPolicy.swift` — easy/medium/hard boost timing per PRD §6.4 (reads upcoming piece types from the spline/piece map).
- `PhysicsEvents.swift` — collision-event subscription → crash SFX triggers + reaction-cam event feed.

Tuning workflow (human + Claude Code pair task)
1. Solo Arena, demo loop track, `Balanced Formula` + `Standard` tires → must clear loop at full speed.
2. Same with `Super-light Drift` + `Slick` → should fling off the loop ~50% of runs.
3. Adjust `RaceTuning` only. Never scatter constants.

Tests: meter/lives/win-condition logic (pure funcs); checkpoint sequencing with a scripted position feed; AI policy decisions for fixture tracks. Physics feel is validated by humans in Test Mode, not asserts.
