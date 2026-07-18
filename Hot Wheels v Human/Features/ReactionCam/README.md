# Features/ReactionCam/ — driver PiP (Phase 6 — built)

Concept: hold the 🎥 button on the iPad → circular PiP appears on the TV showing that player's driver reacting to live physics. Dev/sim shortcut: launch arg `--show-cams` forces every PiP on.

Files (as built 2026-07-18)
- `ReactionCamView.swift` — circular-masked mini `RealityView`: driver bust (Quaternius rig, painted by `DriverPainter` from `design.driver` — the kid's character colors, hats and all, since C4/C5) + `PerspectiveCamera` + key light, player-colored ring, name capsule. Positioned bottom-left/right per player by ArenaView. Face bubble uses the character's skin tone + face paint (`driver.faceDrawingPNG`, falling back to the legacy `CarDesign.faceDrawingPNG`).
- `ReactionDirector.swift` — race events → reaction state machine: `idle → steerLeft/steerRight → braced → boosted / crashed / celebrating`. Continuous inputs: yaw rate (lean) + loop-within-0.5 s (brace); discrete events override instantly. Min state hold (RaceTuning.reactionMinHold) so it never flickers; celebrating is sticky. Unit-tested.
- `ReactionFeed.swift` — bridges live `RaceSession` state → one director per racer, every frame from ArenaView's scene subscription. Discrete events detected by diffing racer stats (crashes↑ = crashed, meter 1→0 = boosted, finishTime set = celebrating) — no extra event plumbing.
- `DriverPoser.swift` — `make(profile:)` builds the bust painted by `DriverPainter`, then plays the matching Quaternius clip (idle/Punch/Death/Jump → idle/boosted/crashed/celebrating), crossfaded 0.15 s. Clips are separate USDZs (`driver-*.usdz`) from `tools/convert_driver_rig.py`; skeletons match so any clip plays on the one bust.
- `FaceDecals.swift` — face expression per state. Built as an emoji badge over the PiP instead of the planned texture-swap quad — reads better at PiP size, zero texture authoring. Steering/braced states reuse the idle clip; the face carries them.

Deviations from the original plan
- No Blender-authored seated/lean/brace poses: the rig's stock clips + face badges cover every state. In-car "seated" pose = standing rig sunk hip-deep into the chassis (legs hidden — RaceTuning.driverSinkRatio).
- Sprite fallback not needed in Simulator; profile the second RealityView on real Apple TV hardware before shipping (fallback plan unchanged if it costs > 10% frame time).
