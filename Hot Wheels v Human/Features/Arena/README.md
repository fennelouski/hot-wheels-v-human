# Features/Arena/ — the 3D race scene (Phases 1–2 solo, 3 on TV)

Files
- `ArenaView.swift` — the `RealityView`: builds scene from `AppModel` blueprint via `TrackSpawner`, spawns cars via `CarFactory`, registers `DriveSystem`/`RaceRulesSystem`/`CameraSystem`, environment (gradient sky, soft ground plane, directional light + shadows). Hosts overlay HUD.
- `ArenaHUDView.swift` — TV overlay: countdown numerals, per-player name+lives banners, lap counter, finish banner, results panel (times, crashes, best segment, REMATCH prompt "press READY on iPad").
- `CameraSystem.swift` — chase rig: follows midpoint of the two cars biased toward the leader, smooth lerp, pull-back proportional to car separation; special cams: loop (hold wide while a car is in loop), finish (slow dolly), crash (0.5 s shake). Solo Arena on iPad reuses everything.
- `SoloArenaView.swift` — iPad wrapper: Arena + embedded mini-Dashboard side panel via `LoopbackTransport` (this is Test Mode's home too — Test Mode = Solo Arena with `MatchConfig.mode == .test`, two local designs, no lives/boost).
- `VFX.swift` — boost tailpipe glow (emissive material pulse + particle if cheap), debris despawn fade, confetti burst on win (`ParticleEmitterComponent`).

Perf budget (Apple TV 4K): ≤ 40 track pieces + 2 cars + debris ≤ 150 draw-relevant entities; static track merged where possible; target steady 60 fps. Profile with RealityKit debug options before adding VFX. If PiP reaction cam (2nd RealityView) costs > 10% frame time → sprite fallback per ReactionCam/README.
