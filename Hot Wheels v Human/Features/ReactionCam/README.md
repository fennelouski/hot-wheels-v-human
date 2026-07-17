# Features/ReactionCam/ — driver PiP (Phase 6)

Concept: hold "Up" on the iPad → circular PiP appears on the TV showing that player's driver reacting to live physics.

Files
- `ReactionCamView.swift` — circular-masked mini `RealityView`: off-stage driver bust (Quaternius avatar, player's colors) + `PerspectiveCamera` + key light. Positioned bottom-left/right per player.
- `ReactionDirector.swift` — maps race events → reaction state machine: `idle → steering(l/r) → braced(loop) → boosted → crashed → celebrating`. Inputs: lateral accel (lean), upcoming loop within 0.5 s (brace), boost fired (push-back), destruction (facepalm), win (cheer). Min state hold 400 ms so it never flickers.
- `FaceDecals.swift` — face expression = texture swap on a face quad (normal / wide-eye / gritted / dizzy / grin). No facial rigging.
- `DriverPoser.swift` — skeletal poses (seated grip, lean L/R, brace, facepalm, arms-up) — authored as short USDZ animation clips in Blender on the Quaternius rig, crossfaded (0.15 s).

Fallback plan (decide by profiling in Phase 6): if a second RealityView hurts tvOS frame rate, render reactions as pre-captured sprite sequences (capture the 3D poses once per driver-color combo at build of race) shown in a plain SwiftUI overlay — identical UX, near-zero cost.
