# Features/Dashboard/ — in-race iPad controller (Phase 3; reaction-cam button Phase 6)

Files
- `DashboardView.swift` — full-screen "cockpit": center-bottom **BoostButton**, top progress strip, left garage (5 car slots, destroyed = wreck icon + shake), right speedometer, corner **Up** (reaction cam) hold-button. 2P mode = `DashboardSplitView` mirroring the customizer split.
- `DashboardModel.swift` — consumes `RaceSnapshot` stream (drop stale by seq no.); exposes meter %, lives, progress, speed, phase; sends `.boost` (with retry+token) and `.reactionCam(on:)`. `submit` sends the ranked track draft (`.trackBlueprint(rank:ownerID:)` per pick).
- `RaceSetupView.swift` — Race-on-TV pre-flight: pick your car (saved + starters) and draft up to `RaceTuning.raceSeriesLength` tracks in favorite order (tap order = rank); seeds from the Track Builder's "race this next". `RaceOnTVView` shows it before becoming the dashboard.
- `BoostButtonView.swift` — circular meter ring fills as it charges; at 100%: pulse + haptic (`.impact(.heavy)`); on tap: burst animation, disabled until next charge. THE tactile centerpiece — make it juicy (Canvas + TimelineView).
- `GarageStripView.swift` — 5 slots with the player's actual car thumbnail; destruction event = slot explodes into mini debris emoji shower.
- `CountdownOverlay.swift` — mirrors TV countdown so eyes can stay anywhere.

Notes: everything renders from snapshots — the dashboard never simulates. Keep layout landscape-only. Haptics on: meter full, boost fire, car destroyed, win/lose. If snapshot gap > 2 s show "reconnecting…" veil (transport auto-rejoins).
