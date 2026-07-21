# App/ — entry point, routing, app-wide state

**Phase 0.** Move `Hot_Wheels_v_HumanApp.swift` and `ContentView.swift` here (synced folder: a plain file move, Xcode picks it up).

Files to create
- `Hot_Wheels_v_HumanApp.swift` (moved): strips SwiftData `Item` boilerplate. tvOS gets no `modelContainer` (or guarded one).
- `AppModel.swift` (deferred to Phase 1 — every property it holds is a Phase 1/3 type): `@Observable final class AppModel` — current route, `GameTransport` instance, local `PlayerInfo`, selected designs/blueprint, race snapshot cache. Injected via `.environment`.
- `RootView.swift`: platform router.
  - iPadOS → `HomeView` (Workshop): navigate to Customizer / TrackBuilder / TestMode / Dashboard / SoloArena.
  - tvOS → `ArenaLobbyView` → `ArenaView` (auto-advertises as host on launch).
- `Platform.swift`: tiny helpers (`isTV`), the only file where `#if os(tvOS)` is expected to be dense.
- `ChipRow.swift` (added post-G4): big high-contrast capsule-chip picker shared by Customizer + Profiles — the app-wide replacement for segmented controls (which rendered white-on-light-gray on the dark screens and sat under the 60 pt tap-target rule).
- `LobbyBackground.swift`: slow drifting gradient shared by the TV lobby (`Features/Home/ArenaLobbyView`) and the iPad's pre-race screen (`Features/Dashboard`'s `ConnectionLadder`) — takes an `energy` (0...1) each caller computes from its own view of the connection state; always used with `.ignoresSafeArea()` so it reaches every edge, TV overscan included.

`AppModel.stampedRaceDesign(car:driver:)` takes optional overrides that both default to the saved selection. Workshops pass the piece they're editing so a "try it" button races what's on screen right now, saved or not — see Features/Arena/README.md for the shared preview kit.

Rules: no gameplay logic here. Navigation state lives in `AppModel`; features read/write it. Keep `App/` under ~300 lines total.
