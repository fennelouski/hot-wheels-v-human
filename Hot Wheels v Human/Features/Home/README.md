# Features/Home/ — entry screens

iPad (`HomeView`, Phase 0 stub → Phase 3 full)
- Big kid-friendly buttons: **Race on TV** (1P / 2P), **Test My Cars**, **Solo Race** (no TV), **Garage** (saved cars/tracks).
- Connection chip: searching / found "Living Room" / connected (drives from `TransportState`).
- Chooses `MatchConfig` (mode, laps, AI difficulty as emoji faces 😀😼🤖).

tvOS (`ArenaLobbyView`, Phase 3)
- Auto-starts advertising `hwvh-race` on appear. Shows: app logo, "Open the app on your iPad", connected player cards (name + car preview once designs sync), ready checkmarks, then hands off to `ArenaView` on `matchConfig` + all-ready.
- tvOS focus engine: lobby is display-only (no remote interaction needed for v1) — keep it that way, the iPad is the controller.
