# Features/Dashboard/ — in-race iPad controller (Phase 3; reaction-cam button Phase 6)

Files
- `DashboardView.swift` — full-screen "cockpit": center-bottom **BoostButton**, top progress strip, left garage (5 car slots, destroyed = wreck icon + shake), right speedometer, corner **Up** (reaction cam) hold-button. 2P mode = `DashboardSplitView` mirroring the customizer split.
- `DashboardModel.swift` — consumes `RaceSnapshot` stream (drop stale by seq no.); exposes meter %, lives, progress, speed, phase; sends `.boost` (with retry+token) and `.reactionCam(on:)`. `submit` sends the ranked track draft (`.trackBlueprint(rank:ownerID:)` per pick).
- `RaceSetupView.swift` — Race-on-TV pre-flight: pick your car (saved + starters) and draft up to `RaceTuning.raceSeriesLength` tracks in favorite order (tap order = rank); seeds from the Track Builder's "race this next". `RaceOnTVView` shows it before becoming the dashboard.
- `BoostButtonView` (in `DashboardView.swift`) — the NOS bottle gauge: a 270° dial reading 0–200% with ticks, needle, and a red overcharge zone above 100%. Armed at 100% (pulse + one rising-edge haptic). **Press and HOLD to burn** — the boost starts on touch DOWN, the needle falls while held, the dial jitters (`TimelineView`) and thumps a haptic every 110 ms. THE tactile centerpiece.
- `GarageStripView.swift` — 5 slots with the player's actual car thumbnail; destruction event = slot explodes into mini debris emoji shower.
- `CountdownOverlay.swift` — mirrors TV countdown so eyes can stay anywhere.

Notes: everything renders from snapshots — the dashboard never simulates. Keep layout landscape-only. Haptics on: meter full, boost fire, car destroyed, win/lose. If snapshot gap > 2 s show "reconnecting…" veil (transport auto-rejoins).
