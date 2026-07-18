# CHARACTER-SPEC — profiles & character creation (the C-series)

Character creation is the part of the game the kids love most, so it became
its own experience: local profiles, multiple named characters each, a
full-screen editor, and a camera "make it look like ME!" mode. Built after
P0–P7/G1–G4; this doc is its spec and ground truth.

## Decisions
- **Local profiles, no accounts.** "Who's playing?" gate at launch
  (Netflix-kids style). Profiles + characters are SwiftData rows on the
  iPad. Last-used profile id in UserDefaults (`lastProfileID`).
- **The driver rides inside CarDesign on the wire.** `CarDesign.driver:
  DriverProfile?` — `AppModel.stampedRaceDesign()` stamps the selected
  character into the outgoing design at race time. Additive optional field
  → old peers/records decode; no protocol bump, no new message cases.
- **Camera drives the stylized avatar, never a photo texture.** On-device
  Vision samples skin/hair/eye colors, snaps them to `DriverPalette`, and
  the photo is discarded — never written to disk, never in the save file.
  `NSCameraUsageDescription` says exactly that, kid-readable.
- **Characters upsert by id** (a kid's "me" edits in place) — unlike cars,
  which clone on save.

## The stripe-palette driver pipeline (was "deferred" in G4)
The Quaternius rig is ONE mesh + ONE material colored by a 32×32
stripe-palette texture. `DriverPainter.paletteImage` generates the 5
stripes from `DriverProfile` colors (bald = hair stripe painted skin-tone)
and sets it as baseColor with nearest-neighbor sampling, no mipmaps.

| 32×32 rows (top-down) | region (ranges in `DriverPalette.StripeRows`) |
|---|---|
| 0–5 | skin |
| 6–10 | eyes + eyebrows (shared stripe — eyebrow follows eye color, v1 limitation) |
| 11–16 | hair |
| 17–22 | shirt (`suitColorHex`) |
| 23–31 | pants |

Wardrobe (hats/glasses/hair volumes) = procedural `MeshResource` props in
`DriverDressUp`, attached by `DriverPainter.apply` and pinned to the posed
`Head` joint every frame by `HeadPinSystem` (fixed bind-pose offset is the
fallback). Because CarFactory, DriverPoser, and the editor preview all
paint through `DriverPainter.apply`, every surface renders the full look.

## Phases (all built 2026-07-18)
| # | Scope |
|---|---|
| C1 | DriverProfile fields (hair/eye/pants colors, hat, glasses, faceDrawingPNG), `CarDesign.driver`, DriverPalette, driver presets (`DA900000-…` UUIDs), KidProfile(+Record), `ownerProfileID`, `stampedRaceDesign()` |
| C2 | ProfilePickerView gate in RootView, create/delete profiles, home profile chip |
| C3 | CharacterSelectView, CharacterEditorView/Model (upsert save, undo), customizer driver tab → summary link, face paint moved to DriverProfile |
| C4 | DriverPainter stripe pipeline + DriverPreviewView turntable + CarFactory/DriverPoser hookups |
| C5 | DriverDressUp props + HeadPinSystem joint pinning |
| C6 | LookalikeView + LookalikeAnalyzer (Vision, `#if os(iOS)`), camera Info.plist key |
| C7 | Profile-tile faces, doc sweep (this file) |

## Testing
Pure logic unit-tested in `CharacterModelTests`: legacy-JSON decode compat,
wire round-trip with driver, palette snapping, stripe-row pixel assertions,
prop mapping, upsert semantics, lookalike patch/average/snap math.
Human-tested: the Vision call on a real face (needs a real iPad camera —
Simulator shows the no-camera fallback), prop placement feel, kid joy.

## Known ceilings (upgrade paths named in code)
- Eyes/eyebrows share a stripe; splitting needs a Blender UV-cell edit.
- Suit "styles" are color pairs — outfit meshes would need new assets.
- Hair length from the camera is not detected (low value, high fuss).
