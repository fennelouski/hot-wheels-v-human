# CLAUDE.md — Hot Wheels vs. Human

iPad + Apple TV toy-racing game: build tracks & cars on iPad, race with real physics on the TV, iPad becomes the boost/reaction-cam controller. Designed by a kid, engineered for agentic development. Family project — keep the codebase friendly and the game kid-first.

## Read these before writing code
1. `Documents/PRD-v2-Complete.md` — what we're building (v1 PRD is historical).
2. `Documents/ARCHITECTURE.md` — module map, protocols, rules.
3. `Documents/BUILD-ORDER.md` — **the phase plan. Always work the earliest incomplete phase; meet its DoD before moving on.**
4. `Documents/XCODE-SETUP.md` — Phase 0 project config + CLI build/test commands.
5. Every folder has a `README.md` specifying exactly what to build there. Follow them; update them when reality diverges (docs are part of the deliverable).

## Facts you'd otherwise have to rediscover
- Xcode 26 project, `objectVersion 77`, **filesystem-synchronized folders**: files created under `Hot Wheels v Human/` are automatically in the app target — no pbxproj edits to add files. Tests folders are likewise synced.
- One multiplatform target (iPadOS 26 + tvOS 26 after Phase 0). RealityKit works on tvOS since tvOS 26 (WWDC25); SceneKit is deprecated — never use it.
- Platform behavior: iPad = workshop/controller; TV = physics-authoritative arena; iPad Solo Arena (LoopbackTransport) = primary dev/test loop. Multipeer needs a real device; don't fight Simulator-to-Simulator.
- 3D assets: CC0 packs already downloaded in `Graphics/3DModels/Source/` (Kenney Toy Car Kit = track system incl. loop; Kenney Car Kit = cars/wheels/debris; Quaternius rigged human; OGA racetrack extras). Convert GLB→USDZ into `Hot Wheels v Human/Resources/Models3D/` per `Graphics/README.md`.
- Multipeer service `hwvh-race`; Info.plist needs `NSLocalNetworkUsageDescription` + `NSBonjourServices` or discovery silently fails.
- The Quaternius driver rig is ONE mesh + ONE material colored by a 32×32 stripe-palette texture (rows top-down: 0–5 skin, 6–10 eyes+eyebrows, 11–16 hair, 17–22 shirt, 23–31 pants — constants in `DriverPalette.StripeRows`). Painting the whole character = generating 5 stripes (`DriverPainter`); no UV work needed. Bones are Mixamo-named (`Hips…Neck/Head`) — `HeadPinSystem` pins dress-up props to the posed Head joint.
- The character rides the wire inside the design: `CarDesign.driver: DriverProfile?`, stamped by `AppModel.stampedRaceDesign()` at race time. Additive optional → old peers decode; never add a new message case for driver data.
- iPad-only code (camera, PencilKit flows) must gate with `#if os(iOS)` — `#if canImport(UIKit)` is TRUE on tvOS and will break the TV build.

## Conventions
- Swift 6 strict concurrency; `@Observable` view models; no third-party dependencies (zero SPM packages in v1).
- All gameplay constants in `Core/RaceCore/RaceTuning.swift`. No magic numbers elsewhere.
- `Core/*` never imports SwiftUI; features communicate only via `AppModel` + `GameTransport`.
- Unit-test all pure logic (`Core/Models`, validator, solver, codec, race rules); physics *feel* is human-tested in Test Mode.
- Build must stay green on BOTH destinations (commands in XCODE-SETUP.md §7). Run tests before declaring any phase done.
- Commit style: small, imperative subjects, reference phase (e.g. `P2: spline follower clears loop`).
- UI: kid-first — tap targets ≥ 60 pt, no walls of text, no strobing VFX, failures are funny not punishing.
- **Never use emoji as iconography or art** — SF Symbols or custom-drawn assets only. Emoji reads as stock, ships differently per OS, and breaks the custom look. (This includes face decals, map glyphs, and button labels.)

## Guardrails
- Don't rename the app/bundle IDs (trademark rename is a deliberate later decision — PRD §1.1).
- Don't add networking beyond Multipeer local play; no accounts, no analytics, no ads. It's for kids.
- Don't modify files under `Graphics/3DModels/Source/` — they're pristine upstream assets.
- If a doc conflicts with observed reality (API changes, asset issues), fix the doc in the same commit as the code.
