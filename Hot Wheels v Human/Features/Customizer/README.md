# Features/Customizer/ — car design (Phase 4; driver editing moved to Features/Profiles in C3)

Files
- `CustomizerView.swift` — tabbed: Chassis / Tires / Paint / Livery / Stickers / Draw / Driver. Center = live 3D turntable preview (`RealityView`, slow auto-rotate, drag to spin). The Driver tab is now a read-only summary of the selected character (`AppModel.raceDriver`) + an "Edit My Racer" link into `CharacterEditorView`.
- `CustomizerModel.swift` — working `CarDesign`; `save()` → SwiftData (new UUID per save — kids iterate by cloning); rebuilds via `CarFactory` (reuse race code — what you see is what races).
- `ChassisPicker.swift` / `TirePicker.swift` — horizontal card pickers; each card shows model thumbnail + stat bars (Speed/Weight/Grip, derived from RaceTuning so bars never lie).
- `PaintShopView.swift` — kid-proof 12-swatch grid + part chips (Body/Wheels, `CarPaintSlot`) + finish segmented control (incl. sparkle); applies live to preview materials. Tapping the car on the turntable also selects the part (G1).
- `LiveryShopView.swift` — livery pattern chips (rendered by `OverlayComposer` — previews never lie) + color + size slider (G2).
- `StickerShopView.swift` — sticker sheet (SF Symbols + custom skull) + color; tap car to stamp via camera-ray raycast, drag/pinch/rotate edits the newest sticker (G3).
- `DrawingPadView.swift` — PencilKit canvas over a car silhouette; every stroke re-renders the overlay's bottom layer, PNG capped at 200 KB, strokes persisted so saved designs stay editable (G4). iPad only.
- `CustomizerSplitView.swift` — 2P: `VStack { CustomizerView().rotationEffect(.degrees(180)); Divider; CustomizerView() }`, independent models, per-player done state; both `CarDesign`s land in `AppModel`.
- `GarageView.swift` — saved designs grid, select-for-race, delete (hold-to-wiggle).

Notes: material tinting = walk entity's `ModelComponent` materials, replace with `PhysicallyBasedMaterial` (baseColor = chosen, per-part override via `CarDesign.partColors`; sparkle = metallic + generated normal-noise texture). Kenney models are flat-colored so global tint looks intentional. Undo: `CustomizerModel.undoStack` snapshots every design change (kid-first: always-visible Undo, no confirmations). Keep every tap target ≥ 60 pt — kid fingers.
