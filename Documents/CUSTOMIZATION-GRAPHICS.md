# Customization Graphics — full creative freedom (post-v1 flagship)

Kids will spend more time customizing than racing. This doc specs how deep car/driver
customization works on top of the existing stack. Read after ARCHITECTURE.md.

## Why the obvious approach fails
Kenney models use palette-atlas UVs (tiny islands, one shared texture). Painting stripes
or decals into those UVs produces garbage. Do NOT try to texture the base meshes.

## The paint shell (core technique — everything builds on it)
At car load, `CarFactory` additionally builds a **shell**: a copy of the chassis mesh,
inflated ~1–2 mm along vertex normals, with **planar side-projection UVs computed in code**
(u = normalized z, v = normalized y, mirrored on both sides; front/rear get stretched edge
texels — acceptable on toy proportions). The shell renders one RGBA **overlay texture**
(1024², generated with CGContext) with alpha blending over the tinted base model.

One overlay texture = livery + stickers + drawing composited in layers. Regenerate on any
edit (cheap, off-main), cache as `TextureResource`.

## Feature layers (build in this order)

### A. Per-part colors (quick win, no shell needed)
Reality check (G1): the Kenney chassis models are ONE shared material but distinct
*meshes* per part — wheels (`wheel_*`) and body (`body`/`vehicle_racer`/…); there are no
spoiler/bumper/window meshes. So slots are **body + wheels**, mapped by mesh name
(`CarPaintSlot`). Tap a part on the turntable (gesture → entity name) → swatches paint
that slot. Finish stays car-wide on `PaintSpec` (+ new: sparkle = metallic with
high-frequency normal noise; rainbow hue-shift was skipped per the escape hatch below —
ship sparkle only).

### B. Livery presets
6–10 patterns drawn procedurally in CGContext (racing stripes, flames, polka dots,
lightning bolt, checkerboard, star field, zigzag). Each = path drawing in one tint color
at chosen opacity. Kid picks pattern + color + slider for size. All patterns must look
good with ANY body color underneath — test on dark + light.

### C. Sticker stamping
Sticker sheet: numbers 0–9, stars, eyes, mouths, lightning, flame, heart, skull-but-cute,
paw, rainbow — rendered from SF Symbols or custom CGContext paths into the overlay
(no asset downloads; never emoji — see CLAUDE.md).
Interaction: tap sticker → tap car → raycast hit position → project to shell UV → stamp.
Drag to move, pinch to scale, two-finger rotate. Big handles, ≥60 pt targets.

### D. Freehand drawing (the flagship)
PencilKit canvas, car side-silhouette as stencil background, kid draws with finger/Pencil.
`PKDrawing` → image → bottom layer of the overlay. Mirror to both sides by default
("same on both sides" toggle). Driver gets the same: draw on face/shirt via the existing
`FaceDecals` pipeline.

## Data model
```swift
struct StickerPlacement: Codable { var symbol: String; var uv: SIMD2<Float>; var scale: Float; var rotation: Float; var colorHex: String }
// CarDesign additions (all optional -> old designs keep decoding):
var partColors: [String: String]? // material-slot name -> hex
var livery: LiverySpec?           // pattern id + colorHex + scale
var stickers: [StickerPlacement]? 
var drawingPNG: Data?             // cap 200 KB (PNG, 1024 wide); nil = none
```
Wire sync: already covered — designs travel as Codable blobs over `.reliable`. Enforce the
200 KB cap at save time (downscale until it fits). SwiftData: same records, new fields.

## Kid-first rules (non-negotiable)
- Undo button always visible; unlimited undo within a session.
- No delete confirmations — undo instead.
- Every tap does something visible/audible (`paint_spray`, `customize_confirm_pop`,
  `confirm_sparkle` are already in Resources/Audio).
- No failure states: can't place a sticker "wrong", can't run out of anything.
- Live 3D preview updates < 100 ms after any edit (composite off-main, swap texture).

## Phasing
| Step | Scope | Size |
|---|---|---|
| G1 | Per-part colors + sparkle finish | ~1 day |
| G2 | Paint shell + livery presets | 1–2 days |
| G3 | Stickers | ~1 day |
| G4 | PencilKit drawing (car + driver face/shirt) | 1–2 days |

Each step ships independently — G1 alone is already a big visible upgrade. Unit-test the
UV projection math and the overlay compositor (pure functions); the feel is human-tested.
