# Features/Customizer/ — car & driver design (Phase 4)

Files
- `CustomizerView.swift` — tabbed: Chassis / Tires / Paint / Driver. Center = live 3D turntable preview (`RealityView`, slow auto-rotate, drag to spin).
- `CustomizerModel.swift` — working `CarDesign` + `DriverProfile`; `save()` → SwiftData; `preview(entity:)` rebuilds via `CarFactory` (reuse race code — what you see is what races).
- `ChassisPicker.swift` / `TirePicker.swift` — horizontal card pickers; each card shows model thumbnail + stat bars (Speed/Weight/Grip, derived from RaceTuning so bars never lie).
- `PaintShopView.swift` — `ColorPicker` (or custom kid-proof 12-swatch wheel) + finish segmented control; applies live to preview materials.
- `DriverEditorView.swift` — color pickers for helmet/suit, skin tone + hair selectors, name field with random-name dice button.
- `CustomizerSplitView.swift` — 2P: `VStack { CustomizerView().rotationEffect(.degrees(180)); Divider; CustomizerView() }`, independent models, per-player done state; both `CarDesign`s land in `AppModel`.
- `GarageView.swift` — saved designs grid, select-for-race, delete (hold-to-wiggle).

Notes: material tinting = walk entity's `ModelComponent` materials, replace with `PhysicallyBasedMaterial` (baseColor = chosen, metallic 1.0/0.3/0.0 and roughness 0.2/0.4/0.8 for metallic/glossy/matte). Kenney models are flat-colored so global tint looks intentional. Keep every tap target ≥ 60 pt — kid fingers.
