# Graphics/ — source art (NOT bundled in the app)

This folder holds original downloaded asset packs. Converted, app-ready USDZ files go to `Hot Wheels v Human/Resources/Models3D/` (that folder ships; this one doesn't).

## Inventory (all downloaded 2026-07-17, verified unzip-clean)

### 1. `3DModels/Source/kenney_toy-car-kit/` — THE core kit
- Source: https://kenney.nl/assets/toy-car-kit · License: **CC0** (License.txt included)
- 100 models in GLB (use these) + FBX + OBJ. Orange toy-track construction system — exactly the Hot Wheels fantasy.
- Highlights: `track-{narrow,wide,striped-wide,road-narrow,road-wide}-{straight, curve, corner-small/large(-ramp), looping, straight-hill-*, straight-bump-up/down, straight-skew-*}`, `gate` / `gate-finish`, `supports*` (track legs), toy vehicles `vehicle-{speedster,racer,racer-low,drag-racer,vintage-racer,monster-truck,suv,truck}`, wheels `wheel-{small,medium,large}`, items (`item-coin-*`, `item-banana`, `item-box`, `item-cone`), `smoke`, trees.
- **v1 mapping:** use the `track-wide-*` family for dual-lane pieces, `track-narrow-looping` for the loop, `gate`/`gate-finish`, `supports*` under elevated pieces (cosmetic).

### 2. `3DModels/Source/kenney_car-kit/` — cars, karts, wheels, debris
- Source: https://kenney.nl/assets/car-kit · License: **CC0**
- GLB format retained. Highlights: `race`, `race-future`, `sedan-sports`, `hatchback-sports`, `suv`, `truck`, `kart-*` (5 karts — great AI roster), separate wheels `wheel-{default,racing,dark}`, and **`debris-*` (18 pieces: doors, bumpers, tires, bolts) for the car-destruction VFX** — this is why this kit matters.

### 3. `3DModels/Source/oga_modular_racetrack/` — extra loop/ramp/jump geometry
- Source: https://opengameart.org/content/modular-racetrack-3d-models (Keith @ Fertile Soil Productions) · License: **CC0** · Format: OBJ
- `loop.obj`, `jump1/2.obj`, `ramp1-3.obj`, banked `angled.obj` + transitions. Use if a Kenney piece doesn't fit; style is plainer (gray asphalt), so prefer Kenney for the toy look.

### 4b. `3DModels/Source/kenney_mini-characters/` — the character roster (added 2026-07-20)
- Source: https://kenney.nl/assets/mini-characters · License: **CC0** (License.txt included) · Formats: GLB (use these) / FBX / OBJ
- **12 genuinely different people** — `character-{male,female}-{a…f}` — each its own mesh + baked outfit/hair/face on a shared `colormap` texture. This is what fixes "man, woman, boy and girl are the same model": they always were, because the Quaternius pack is ONE rig that we could only rescale.
- Rigged, and every character carries **32 named clips** including `idle`, `drive`, `sit`, `emote-yes/no`, `die`, plus wheelchair moves. `drive` poses the arms out on a wheel — the driver no longer has to be a standing rig sunk hip-deep to fake sitting.
- Accessories: `aid-glasses`, `aid-sunglasses` (real meshes, vs. the procedural boxes/cylinders in `DriverDressUp`), plus masks, canes, crutches, hearing aid and four wheelchairs — an inclusive roster that's free to offer.
- **v1 mapping:** converted as `character-<sex>-<v>-{idle,drive}.usdz` (24 files) + the two glasses. Head joint is named `head` (lowercase, flat path) — `HeadPinSystem` currently only matches Mixamo-style `…/Head`, so wardrobe pinning needs that widened before props ride these rigs.

### 4. `3DModels/Source/quaternius_animated_human/` — rigged driver avatar
- Source: https://opengameart.org/content/animated-human-low-poly (Quaternius) · License: **CC0** · Formats: FBX / Blend / OBJ / DAE + skin/clothes textures
- Rigged + animated (idle, run, jump, death…). Use the FBX or Blend for conversion. Custom driver poses (seated, steer-lean, brace, facepalm) get authored in Blender on top of this rig in Phase 6; face expressions are texture-decal swaps, not rig work.

## Conversion pipeline (GLB/FBX → USDZ)

**Scale factors (baked at conversion, measured 2026-07-17):** toy-car-kit = **0.2** (makes `track-wide-straight` exactly 0.4 m wide); **gates = 0.3** (`gate`/`gate-finish` posts must clear the 0.4 m wide track); car-kit = **0.07** (makes `race` match `vehicle-speedster`'s ~0.18 m length, keeps debris/wheels proportional); mini-characters = **10.73** (matches the Quaternius rig's ~8.5 standing height so `RaceTuning.driverSourceHeight` still holds and the driver is a drop-in). Run: `blender -b -P tools/convert_glb_to_usdz.py -- in.glb out.usdz <scale> [--anim] [--action <clip>]`.

**Animation (added 2026-07-20):** Blender's USD exporter drops animation unless asked, and it bakes the scene TIMELINE rather than glTF's named clips — so a 32-clip Kenney character exports as one long reel cycling every pose. `--action <name>` pins every armature to that one action and narrows the frame range to it, giving one USDZ per pose (`…-idle.usdz`, `…-drive.usdz`). `--anim` alone keeps all actions end-to-end; both are off by default so static track/car models stay lean. **Don't trust the printed `DIMENSIONS`** for a rigged model — it's Blender's bind-pose bounds with arms spread, and it read 5.54 for characters whose real standing height was 2.2. Measure the converted USDZ's world extent instead (scale × z-span, since the root bakes a −90° X).

**Orientation:** RealityKit ignores the USD `upAxis` metadata, so the converter exports with `convert_orientation=True` (bakes Blender Z-up → Y-up as a −90° X root rotation). Blender world (x, y, z) lands in RealityKit as (x, z, −y). Everything in `Resources/Models3D` was (re)converted this way 2026-07-18 — any new conversion must use the updated `tools/convert_glb_to_usdz.py` or the model will render lying on its side.

1. Open in **Reality Converter** (or Blender: import → export USD).
2. Check scale: Kenney GLBs are ~1 unit = 1 m at toy proportions; a track straight should come out ≈ **0.4 m wide** in RealityKit for our 0.4 m cars. Apply uniform scale at conversion time, not per-entity in code.
3. Name output identically to source (`track-wide-straight.usdz`) → drop in `Hot Wheels v Human/Resources/Models3D/`.
4. Quick Look the USDZ (space bar in Finder) before committing.
5. Phase 0 needs only 3 pilot conversions: `track-wide-straight`, `track-narrow-looping`, `vehicle-speedster`. Batch the rest in Phase 1 (write `tools/convert_glb_to_usdz.py` for Blender CLI).

## Licensing summary
Everything here is **CC0 / public domain** — no attribution required, commercial use OK. (We credit Kenney, Fertile Soil Productions, and Quaternius in the app's About screen anyway, because it's classy.) The only IP concern in this project is the *name* — see PRD §1.1.

## Still wanted (not blocking)
- 2D UI art: boost button, garage icons, logo — generate or hand-draw (kid art scan = best possible art direction).
- Skybox/environment: solid gradient or Kenney "backgrounds" pack; a kid's-bedroom environment is a fun stretch goal.
