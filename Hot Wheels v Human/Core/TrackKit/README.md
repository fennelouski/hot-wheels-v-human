# Core/TrackKit/ — blueprint → validated layout → 3D track (Phase 1, built)

Files (as built — geometry facts in PieceCatalog.swift's header comment)
- `PieceType.swift` — enum: `startGate, finishGate, straight, curve90L, curve90R, curveLarge, hillUp, hillDown, bump, loop, rampJump`. Raw values are wire format.
- `PieceCatalog.swift` — `TrackPieceDefinition` table. Kenney pieces are **not** grid-uniform, so each definition carries measured real-valued offsets in a "traversal frame" (entry at origin, travel +Z, surface y = 0): `exitOffset`, `headingChange`, nominal `FootprintRect`, and a `CenterlineShape` (line/arc/verticalLoop) for spline generation. Gates = straight + gate-arch overlay model. `curve90L` and `hillDown` reuse the R/up models traversed in reverse.
- `BlueprintValidator.swift` — non-empty; ≤ 40 pieces; exactly one `startGate` at index 0; at most one `finishGate`, last (sprint) OR exit meets start (circuit); no negative elevation; footprint overlap per elevation level via axis-aligned world rects (headings are always 90° multiples). Kid-readable reasons. Uses the solver's placements so the two can never disagree.
- `TrackLayoutSolver.swift` — accumulates (position, yaw, level) per segment → `PlacedPiece[]` + `LaneSplines` (center/left/right, ~0.1 m spacing, ±0.09 m lanes, ±0.045 m through the narrow loop). Pure math, no RealityKit.
- `TrackSpawner.swift` — RealityKit: loads models via `AssetStore`, places them, `generateStaticMesh` collision per model part (convex hulls would seal the loop), tags gate overlays with `CheckpointComponent`. Cosmetic `supports*` under elevated pieces: pending first elevated track (Phase 2).
- `AssetStore.swift` — `@MainActor` class (not an actor: Entity is MainActor-bound), async `entity(named:)`, cache + clone-on-vend.
- `RandomTrackGenerator.swift` — NOT built yet; arrives with the "shuffle" button in Phase 5 (BUILD-ORDER).

Tests in `Hot Wheels v HumanTests/TrackKitTests.swift`: closed-circuit fixture, overlap/missing-gate/underground rejections, spline arc-length monotonicity + density, loop apex height, lane offset bounds.
