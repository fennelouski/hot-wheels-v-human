# Features/TrackBuilder/ — 2D drag-and-snap editor (Phase 5; thin UI over TrackKit)

Files
- `TrackBuilderView.swift` — layout: piece palette (bottom scroll), grid canvas (Canvas or SpriteKit-free custom drawing — top-down schematic, each piece a rounded icon with heading arrow), toolbar. Toolbar = icon-only undo/clear/shuffle + **"See it in 3D!"** + "Save it!". Icon-only is load-bearing, not styling: spelled out, five labelled buttons overflow an iPad in portrait and every one wraps into an unreadable stack (`Label` still hands the words to VoiceOver). "See it in 3D!" races the blueprint *currently on the canvas* via `.racePreview` — no save required, because peeking mid-build is the point; "Save it!" is what persists the track and makes it race next.
- `TrackBuilderModel.swift` — owns working `TrackBlueprint`; the ONLY mutation API is `append(pieceType)` / `removeLast()` — the open-exit constraint makes invalid tracks unrepresentable. Live-validates via `BlueprintValidator`; publishes solver preview (2D projected path) for drawing.
- `PiecePaletteView.swift` — cards per `PieceType` (icon + name); cards gray out when appending them would fail validation (e.g. overlap) — try-validate on the fly.
- `TrackCanvasView.swift` — draws solved path: colored segments per piece type, loop badge, start/finish flags, elevation shading; pinch zoom + pan; subtle snap animation + `track_snap_connect.wav` on append.
- `BlueprintSyncButton.swift` — READY: final validate → `transport.send(.trackBlueprint(bp), reliably: true)` → waits for TV ack (`raceEvent`) → advances flow.

UX guardrails (kid-first): no free placement/rotation — pieces always attach to the open exit with auto-derived orientation (this is why the builder is simple AND why the data model has no rotation field). Difficulty meter = count of loop/bump/ramp pieces as `flame.fill` SF Symbols (never emoji — CLAUDE.md). Empty state shows a ghost "start gate goes here" hint.
