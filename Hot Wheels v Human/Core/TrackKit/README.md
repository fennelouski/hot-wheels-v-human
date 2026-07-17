# Core/TrackKit/ — blueprint → validated layout → 3D track (Phase 1)

Files to create
- `PieceType.swift` — enum: `startGate, finishGate, straight, curve90L, curve90R, curveLarge, hillUp, hillDown, bump, loop, rampJump`.
- `PieceCatalog.swift` — `TrackPieceDefinition` table (see ARCHITECTURE.md): USDZ `modelName` (from `Resources/Models3D/`, Kenney `track-wide-*` family, loop = `track-narrow-looping`), entry/exit `ConnectionPoint` (grid position + heading + elevation), footprint cells, `minEntrySpeed` for loop/ramp. **Measure entry/exit offsets once from the converted USDZ bounds and hardcode here** — models stay pristine.
- `BlueprintValidator.swift` — rules: non-empty; exactly one `startGate` at index 0; path continuity (each piece attaches to open exit); footprint overlap check per elevation level; max 40 pieces; ends with `finishGate` OR exit meets start (circuit). Returns `ValidationResult` with kid-readable reason.
- `TrackLayoutSolver.swift` — walks the segment list accumulating grid transform (position, heading, elevation) → `PlacedPiece[] { definition, worldTransform }` + generates **two lane splines** as dense waypoint arrays (`[SIMD3<Float>]`, ~0.1 m spacing, offset ±0.09 m from centerline; loop pieces produce the vertical circle points). Pure math, no RealityKit — heavily unit-tested.
- `TrackSpawner.swift` — RealityKit: for each `PlacedPiece`, load USDZ via `AssetStore`, set transform, add `PhysicsBodyComponent(mode: .static)` + `generateStaticMesh` collision, tag gates with `CheckpointComponent`. Adds cosmetic `supports*` models under elevated pieces. Returns `TrackEntity` root + `LaneSplines`.
- `AssetStore.swift` — actor; async `entity(named:)` with caching + clone-on-vend.
- `RandomTrackGenerator.swift` — "shuffle" button: random valid track (N pieces, guarantees ≥1 loop when N ≥ 8, always validates).

Tests: solver produces closed circuit for known blueprint; validator rejects overlap/self-intersection/missing-gate fixtures; spline arc-length monotonicity; random generator output always validates (fuzz ×500).
