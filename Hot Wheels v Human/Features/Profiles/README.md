# Features/Profiles — profiles & character creation (the C-series)

The kid-favorite experience: local "Who's playing?" profiles, multiple named
characters per profile, the full-screen character editor, and the camera
"make it look like ME!" mode. iPad and Apple TV share local profiles and
character data; Apple TV has its own remote-native workshop. Spec:
`Documents/CHARACTER-SPEC.md`.

## Files
- `ProfilePickerView.swift` — Apple TV uses stable grid positions, visible
  profile creation/removal, and remote color buttons. The iPad keeps its
  incumbent animated layout.  "Who's playing?" gate shown by `RootView` on
  cold launch (dev deep-link args skip it). Tiles from `@Query` of
  `KidProfileRecord` showing the last-used character's face; tap = sets
  `AppModel.selectedProfile` + loads the last-used character into
  `AppModel.selectedDriver`; long-press = delete profile + its characters.
  New profiles are seeded with a copy of a random starter character.
- `CharacterSelectView.swift` — Apple TV cards open `TVCharacterDetailView`
  with explicit Race / Edit or Remix / Test Drive / Copy / Scrap actions;
  no gesture or overlapping pencil target is required.  "My Racers" home tile target: this
  profile's characters (`@Query` filtered by `ownerProfileID`) + starter
  characters (`DriverProfile.presets`). Tap = race as them (persists
  `lastUsedDriverID`); pencil = edit (a starter edits as a personal copy);
  hold = scrap. Mirrors GarageView on purpose.
- `CharacterEditorView.swift` + `CharacterEditorModel.swift` — iPad keeps
  the incumbent layout; on Apple TV it routes to `TVCharacterEditorView`.
  The full-screen editor has: 3D turntable preview, the live reaction-cam PiP,
  always-visible Undo, tabs Face / Hair / Clothes / Extras, and a
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
- `TVCharacterEditorView.swift` — fixed preview pane with remote orbit,
  tilt, zoom and reset; independent scrollable Face / Hair / Clothes /
  Extras controls. All body types, roster variants, available eye/skin/hair
  colors, hair meshes, shirt/pants colors, hats and glasses remain editable.
  The same `CharacterEditorModel` supplies undo and save; Test Drive uses
  the unsaved racer. Native TV text entry names the racer.
- `TVCharacterDetailView.swift` — shows the full real 3D racer and all local
  actions; starter editing/copying gets a new id, personal editing updates
  the original id. Returning from editing reloads the saved data.
- `DriverPreviewView.swift` — live turntable painted by the same
  `DriverPainter` that races ("what you see is what races"). Idles with a
  gentle sway around the front, but drag orbits it and pinch zooms
  (`App/TurntableOrbit.swift`), and the sway stops for good on first grab —
  so the back of the hair is reachable without waiting for it to turn.
  Apple TV accepts an optional remote-owned `TurntableOrbit`; nil retains
  the iPad camera unchanged. TV grid avatars use the painted face badge
  because ARView snapshotting is unavailable there; the detail/editor
  preview is the full RealityKit model.
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

## Apple TV limits and verification

The on-device camera is an optional iPad capability, not a TV placeholder.
The camera entry point is still deliberately parked on both platforms
because its current flow is unfinished; the manual editor is complete.
Remote workshop controls use the app's shared `TVWorkshopButtonStyle` and
focus sections. Root integration owns native builds, UI checks and release
evidence; these implementation notes do not claim those checks passed.

Explicit editor saves report success only after SwiftData saves successfully.
Failures keep the working draft open with a retry message and restore only
this operation's record changes; there is no global context rollback.
Profile creation stays open on failure; profile/racer removal updates app
selection only after a successful save. Racer appearance and its owning
profile's last-used selection are committed together.

Selecting a racer commits the profile's last-used pointer before updating
the active race selection. Failure retains the previous selection and
shows a retry message; the TV detail stays open.

The 2026-10-04 candidate makes profile selection optional for immediate Play. The first viewport includes Play and Settings; existing profile creation/removal and personal workshops remain. Apple TV defaults focus to Play. On iPad, larger accessibility text uses a static scrolling profile grid instead of the orbit. The animation preference and OS Reduce Motion stop profile drift and character-preview sway without disabling manual orbit controls.
