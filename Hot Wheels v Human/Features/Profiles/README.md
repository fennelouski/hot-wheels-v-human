# Features/Profiles — profiles & character creation (the C-series)

The kid-favorite experience: local "Who's playing?" profiles, multiple named
characters per profile, the full-screen character editor, and the camera
"make it look like ME!" mode. iPad only — tvOS never routes here. Spec:
`Documents/CHARACTER-SPEC.md`.

## Files
- `ProfilePickerView.swift` — "Who's playing?" gate shown by `RootView` on
  cold launch (dev deep-link args skip it). Tiles from `@Query` of
  `KidProfileRecord` showing the last-used character's face; tap = sets
  `AppModel.selectedProfile` + loads the last-used character into
  `AppModel.selectedDriver`; long-press = delete profile + its characters.
  New profiles are seeded with a copy of a random starter character.
- `CharacterSelectView.swift` — "My Racers" home tile target: this
  profile's characters (`@Query` filtered by `ownerProfileID`) + starter
  characters (`DriverProfile.presets`). Tap = race as them (persists
  `lastUsedDriverID`); pencil = edit (a starter edits as a personal copy);
  hold = scrap. Mirrors GarageView on purpose.
- `CharacterEditorView.swift` + `CharacterEditorModel.swift` — the
  full-screen editor: 3D turntable preview, the live reaction-cam PiP,
  always-visible Undo, tabs Face / Hair / Clothes / Extras / Me!, and a
  paired "Test Drive!" / "Save it!" footer. The PiP is the real
  `ReactionCamView`, not a stand-in badge — it's the round window a kid
  actually stares at mid-race, so every hat and hair change gets judged in
  it while they're still editing, and "Test Drive!" (`.racePreview`) puts
  the *unsaved* racer in the queued-up car and drives off. `demoDrive()`
  fakes a cruise so the speed lines flow and cycles a showreel of
  reactions; it steers dead straight on purpose, because the arena's
  lean-into-turns swings the face clean out of a 180 pt circle. Face tab
  also picks the body type (Man/Woman/Boy/Girl — one rig, scaled per
  `BodyType.scale`); pickers are `ChipRow` chips, never segmented controls.
  `save(into:)` **upserts by id** (as cars now do too — see
  `ModelContext.saveDesign`) and stamps the character as selected +
  last-used. Dev deep link: `--character-editor`.
- `DriverPreviewView.swift` — live turntable painted by the same
  `DriverPainter` that races ("what you see is what races"). Idles with a
  gentle sway around the front, but drag orbits it and pinch zooms
  (`App/TurntableOrbit.swift`), and the sway stops for good on first grab —
  so the back of the hair is reachable without waiting for it to turn.
- Face paint (`FaceDrawPad`, `DriverProfile.faceDrawingPNG`) is **gone**,
  and so is the cartoon face it painted onto. Wherever a character used to
  be shown as a flat drawn face, they're now the actual 3D rig
  (`DriverPreviewView`) — one character, one look, everywhere.
- `LookalikeView.swift` — the camera flow (`#if os(iOS)` — NOT
  `canImport(UIKit)`, which is true on tvOS): front-camera
  `UIImagePickerController`, one picture, on-device analysis, colors
  applied as ONE undo entry, picture discarded. Funny, never punishing.
- `LookalikeAnalyzer.swift` — Vision face landmarks → cheek/pupil/hair-band
  patches → averaged colors → `DriverPalette.nearest` snap. Hair that reads
  closer to skin than any hair color suggests bald. Patch math is pure and
  unit-tested; the VN call is human-tested.

## Rules
- Communicate only through `AppModel` (never reach into other features).
- No accounts, no networking, no photo persistence — everything local.
- Kid-first UI: tap targets ≥ 60 pt, no walls of text, always-visible Undo,
  failures are funny not punishing.
