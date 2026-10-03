# Features/Customizer/ — car design (Phase 4; driver editing moved to Features/Profiles in C3)

Files
- `CustomizerView.swift` — iPad remains tabbed: Body / Chassis / Tires / Paint / Livery / Stickers / Draw / Driver. **Body is first and the default tab** — a kid pictures the shape before anything else, and picking it here (writes `modelOverride`) beats hunting the Garage's Body Shop. Center = live 3D turntable preview (`RealityView`, slow auto-rotate; drag orbits and pinch zooms via `App/TurntableOrbit.swift`, and the auto-rotate stops for good on first grab). **The Stickers tab owns drag/pinch/rotate** — placing stickers needs all three — so on that tab only, the gestures edit the newest sticker instead of the camera. Anywhere else they steer the camera. The Driver tab is now a read-only summary of the selected character (`AppModel.raceDriver`) + an "Edit My Racer" link into `CharacterEditorView`. Footer pairs "Test Drive!" with "Save it!": Test Drive (`.racePreview`) races the car on the turntable — unsaved paint, stickers and all — around whichever track is queued next, so building a track and then testing a car on it is one loop instead of two round trips through home.
- `CustomizerModel.swift` — working `CarDesign`; `save()` → `ModelContext.saveDesign` (upsert by design id: a car opened from the garage saves back over itself, a new build inserts). Deliberate cloning is the garage's "Make a Copy" — it used to be a side effect of tapping Save twice, which nobody could guess. Rebuilds via `CarFactory` (reuse race code — what you see is what races).
- `ChassisPicker.swift` — horizontal card pickers; each card shows model thumbnail + stat bars (Speed/Weight/Grip, derived from RaceTuning so bars never lie). Also hosts `BodyPicker` (horizontal body-shape cards → `modelOverride`, shared card styling).
- `TirePicker.swift` — horizontal tire card picker.
- `PaintShopView.swift` — kid-proof 12-swatch grid + part chips (Body/Wheels, `CarPaintSlot`) + finish `ChipRow` (incl. sparkle). The finish picker is slot-aware: Body writes `paint.finish`, Wheels write `wheelFinish` (nil = matte rubber, the old default) — so wheels can be chrome/gloss/sparkle too, not locked matte. Applies live to preview materials. Tapping the car on the turntable also selects the part (G1). No segmented controls anywhere — `App/ChipRow.swift` replaced them (contrast + 60 pt targets).
- `LiveryShopView.swift` — livery pattern chips (rendered by `OverlayComposer` — previews never lie) + color + size slider (G2).
- `StickerShopView.swift` — sticker sheet (SF Symbols + custom skull) + color; tap car to stamp via camera-ray raycast, drag/pinch/rotate edits the newest sticker (G3).
- `DrawingPadView.swift` — iPad PencilKit canvas over a car silhouette; every stroke re-renders the overlay's bottom layer, PNG capped at 200 KB, strokes persisted so saved designs stay editable (G4). Imported raster
  drawings (including those made on TV) remain underneath new iPad strokes
  rather than being overwritten. Clearing the canvas clears both layers.
  Raster-backed drawings reopen as a merged image; PencilKit strokes stay
  individually editable for the current session.
- `CustomizerSplitView.swift` — on Apple TV, two players use sequential
  upright editors through `TVTwoPlayerCustomizerView`, keeping independent
  car drafts and racer selections before the local two-player race. iPad 2P: `VStack { CustomizerView().rotationEffect(.degrees(180)); Divider; CustomizerView() }`, independent models, per-player done state; both `CarDesign`s land in `AppModel`.
- `GarageView.swift` — **the car hub.** Three grids: My Cars (SwiftData), Starter Cars (`CarDesign.presets`), and the Body Shop (`CarDesign.bodyShop` — the 15 bundled car USDZs that aren't a chassis default, reachable at last via `modelOverride`; tapping one opens the customizer already wearing that body). Cards carry a 96 pt `CarSwatchView`; tapping one pushes `CarDetailView` rather than silently selecting, because a kid can't pick a car they've never seen.
- `CarDetailView` (in `GarageView.swift`) — one car, big: a full `CarTurntableView` preview (drag to orbit, pinch to zoom), inline rename, RaceTuning-derived stat bars, then RACE THIS ONE / Edit It / Test Drive / Make a Copy / Scrap It. The iPad layout is deliberately **not** a `ScrollView` — a vertical scroll and the turntable's drag would fight over the same finger; the turntable gives up height instead, and `GarageUITests` asserts every action stays `isHittable` so "the buttons fell off the bottom" fails in CI. Editing a starter edits a personal copy so presets stay pristine (same rule as `CharacterSelectView`). `CustomizerView(design:)` is what makes editing possible at all — it used to always start from a blank design, so saved cars were write-once.

Notes: the turntable and `CarFactory` both load `CarDesign.modelName` (`modelOverride ?? chassis.modelName`). The turntable used to read `chassis.modelName` directly, so any car with a body override previewed as a different car than the one that raced — if you add a third place that loads a car model, read `modelName`. Material tinting = walk entity's `ModelComponent` materials, replace with `PhysicallyBasedMaterial` (baseColor = chosen, per-part override via `CarDesign.partColors`; sparkle = metallic + generated normal-noise texture). Kenney models are flat-colored so global tint looks intentional. Undo: `CustomizerModel.undoStack` snapshots every design change (kid-first: always-visible Undo, no confirmations). Keep every tap target ≥ 60 pt — kid fingers.


## Apple TV workshop

- `TVCustomizerView.swift` — a persistent car preview/name/Undo/Test Drive/Save
  pane and a separately scrolling tool pane. All eight tabs are reachable
  with native remote focus. The same `CustomizerModel`, `CarFactory` and
  SwiftData upsert path are used on both platforms; no new car schema or
  separate TV identity store is introduced.
- `TVPreviewOrbitControls` — explicit left/right/above/below/zoom/reset buttons
  use the shared bounded `TurntableOrbit`. `CarTurntableView` and
  `DriverPreviewView` accept an optional remote orbit; nil preserves iPad
  drag/pinch behavior. The TV never needs a spatial tap, pinch or rotation.
- `TVPaintTools.swift` — body and wheel paint/finish; every existing livery
  with its real composited preview, color and 0.5–2× size; stickers with
  add/select/position/size/rotation/color/remove; and a real remote drawing
  pad. Pen up/down, directional buttons, color/width, eraser and clear write
  the same ≤200 KB PNG layer used by the race. Existing drawings are retained
  when editing; TV raster edits invalidate stale PencilKit stroke data.
- TV drawing uses selectable direction tools rather than finger strokes.
  The result is a real car drawing, with the editor's shared Undo restoring
  prior images. Imported PencilKit drawings can be extended/erased on TV.
- `TVTwoPlayerCustomizerView.swift` — one remote, two upright benches. Each
  chosen racer is captured with that player's draft; switching back keeps
  both drafts. Race Together enters the existing local two-player arena.
- `GarageView.swift` — TV car and body cards participate in remote focus.
  Car detail keeps an orbitable preview beside scrolling Race / Edit or
  Remix / Test Drive / Copy / Scrap actions and native TV rename entry.

All TV buttons use one focus/selection surface, with checkmarks or labels
where selection would otherwise depend only on color. iPad remains the
source of camera/Pencil input; no camera capability is implied on Apple TV.
Native builds, focus traversal, save/relaunch and race checks belong to the
root integration pass; no simulator/build was run by this feature work.

Explicit editor saves report success only after SwiftData saves successfully.
Failures keep the working draft open with a retry message and restore only
this operation's record changes; there is no global context rollback.
Profile creation stays open on failure; profile/racer removal updates app
selection only after a successful save. Racer appearance and its owning
profile's last-used selection are committed together.

Garage rename/copy use the same success-gated upsert as the editor. Failed
renames keep the typed draft; failed copy/scrap stay on the original car.
Scrapping clears the race selection only after the local removal commits.

`CarDrawingSession.swift` owns the iPad raster base and PencilKit strokes
together in the parent editor. Tab changes cannot discard the imported
base or re-import an already merged PNG; Undo restores that pair from the
selected drawing snapshot, and Clear resets both. The iPad-only
`CarDrawingSessionTests` uses actual PencilKit strokes and PNG pixels to
cover two tab reentries, adding a later stroke, Undo and Clear.
