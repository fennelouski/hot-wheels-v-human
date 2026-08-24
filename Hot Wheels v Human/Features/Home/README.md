# Features/Home/ — entry screens

iPad (`HomeView`, Phase 0 stub → Phase 3 full)
- Big kid-friendly buttons: **Race on TV** (1P / 2P, shown only when a TV is advertising), **Solo Race** (no TV), **Garage** (saved cars/tracks). The tiles are a flowing list, not a fixed grid — a tile that isn't available closes the gap behind it rather than leaving a hole mid-board.
- The physics A/B bench (PRD §2.1 "Test Mode") has **no tile**: it is a tuning tool, not a kid feature, and it is reached with `--test-mode`. See RootView.
- Tiles are **picture cards**: a render of the actual toy above the label (`tools/render_tile_art.py` → `Resources/Thumbs/tile-*.png`), 320 × 140. "Race on TV" and "Garage" keep SF Symbols — no pack ships a TV, and the pit garage art carries "TANKCO." branding.
- Connection chip: searching / found "Living Room" / connected (drives from `TransportState`).
- Chooses `MatchConfig` (mode, laps, AI difficulty as emoji faces 😀😼🤖).

tvOS (`ArenaLobbyView`, Phase 3)
- Auto-starts advertising `hwvh-race` on appear. Shows: app logo, "Open the app on your iPad", connected player cards (name + car preview once designs sync), ready checkmarks, then hands off to `ArenaView` on `matchConfig` + all-ready.
- `ArenaView` is mounted unconditionally underneath the lobby overlay (not gated on `phase != .lobby`) — it's what calls `RaceCoordinator.attach(root:)`, and `startRaceIfReady()` can never leave `.lobby` without a root already attached. Gating it behind phase was a deadlock: the phase could never change because the thing that changes it was waiting on this view to appear first.
- tvOS focus engine: the iPad is still the primary controller (READY lives there), but the lobby also has one real, focusable control — a **START RACE** button, shown once ≥1 player has joined, that force-readies everyone and calls `RaceCoordinator.hostStartRace()`. Covers "couch is one iPad short" and solo-on-TV play.
- Background is `App/LobbyBackground.swift` (`.ignoresSafeArea()` — edge to edge, including TV overscan), driven by an `energy` value computed from `coordinator.players`/readiness so the room visibly "fills up" as racers join and ready. Shared with Dashboard's `ConnectionLadder`, which computes its own `energy` from its one connection instead.
