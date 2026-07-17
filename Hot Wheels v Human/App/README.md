# App/ — entry point, routing, app-wide state

**Phase 0.** Move `Hot_Wheels_v_HumanApp.swift` and `ContentView.swift` here (synced folder: a plain file move, Xcode picks it up).

Files to create
- `Hot_Wheels_v_HumanApp.swift` (moved): strips SwiftData `Item` boilerplate. tvOS gets no `modelContainer` (or guarded one).
- `AppModel.swift` (deferred to Phase 1 — every property it holds is a Phase 1/3 type): `@Observable final class AppModel` — current route, `GameTransport` instance, local `PlayerInfo`, selected designs/blueprint, race snapshot cache. Injected via `.environment`.
- `RootView.swift`: platform router.
  - iPadOS → `HomeView` (Workshop): navigate to Customizer / TrackBuilder / TestMode / Dashboard / SoloArena.
  - tvOS → `ArenaLobbyView` → `ArenaView` (auto-advertises as host on launch).
- `Platform.swift`: tiny helpers (`isTV`), the only file where `#if os(tvOS)` is expected to be dense.

Rules: no gameplay logic here. Navigation state lives in `AppModel`; features read/write it. Keep `App/` under ~300 lines total.
