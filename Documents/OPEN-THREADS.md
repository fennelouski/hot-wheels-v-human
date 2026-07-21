# Open threads — known gaps and unfinished work

Written 2026-07-20 against `1f2b6a1`. **Updated the same day**: items 1, 2, 4
and 9 are done — see "Closed" at the bottom for what actually turned out to
be true, which was not always what this file predicted. Ordered by how much
a player would notice.

Paste the prompt at the bottom into a fresh session to pick this up.

---

## ~~1. The jump doesn't actually jump (rail mode)~~ — DONE

`rampJump` is a straight launch piece now, but its spline is flat:
`shape: .line(length: 0.8, rise: 0)` (`PieceCatalog.swift`). Rail mode —
the default — launches ballistically only when the **spline bed falls away
faster than gravity** (`DriveSystem.railStep`, `bedY = position.y` vs
`RaceTuning.launchThreshold`). A flat spline never triggers it, so in the
mode players actually race, the jump is a flat straight.

**Fix:** give the jump a cresting centreline. `CenterlineShape` has no
crest case — `.line` is linear, `.arc` is horizontal, `.verticalLoop` is
the loop. Add something like `.crest(length:height:)` in `PieceCatalog`
and generate it in `TrackLayoutSolver.localCenterline`. Keep entry and
exit at y = 0 so the piece stays swappable with `.straight`/`.bump` — that
swappability is what let the jump drop into all 7 locked presets without
re-laying a single track.

## ~~2. A hill seam still traps cars~~ — DONE (and the diagnosis was off)

Cars wedge at the `hillUp` bed-slab seam. `RaceRulesSystem` rescues them
(lifts to the start of the next piece, no life charged), so races complete
— Mount Kaboom needed 4 rescues, others 2. The defect is untouched and now
**invisible**, which is how it rots.

Every rescue logs coordinates and piece index via `RaceSession.drillLog`
→ `Documents/drill-log.txt` (pull with `simctl get_app_container … data`).
Reproduce: `--preset-track 1`, grep `rescued`.

**Fix:** the seam between a flat bed slab and a pitched hill slab in
`TrackSpawner.bedCollision`. A lip at the junction catches the low-profile
car box.

## 3. Reaction cam is a different person from the driver

`DriverPoser` still loads the legacy Quaternius `driver-idle` bust, because
its four pose clips (`driver-idle/-boost/-crash/-cheer`) have no roster
equivalent. So the PiP face and the character in the car are different
people.

**Fix:** Kenney ships `emote-yes`, `emote-no`, `die` and `idle` per
character. Convert them per-pose with the existing tool
(`--action <clip>`, see `Graphics/README.md`) and map them onto
`ReactionState`. Then drop `bakedAppearance: false` at `DriverPoser.swift:29`
— it exists solely to keep painting the blank Quaternius mesh.

## ~~4. Eight of the twelve characters are unreachable~~ — DONE

`DriverProfile.characterVariant` ("a".."f") is wired through
`modelName(pose:)` and covered by tests, but **no view sets it** — the
editor only exposes the four body types, so each shows one fixed variant.

**Fix:** a variant picker in `CharacterEditorView` (the `Body` row is the
natural home). All 24 USDZs are bundled and `everyRosterModelIsBundled`
already guards them.

## ~~5. Hair fights the roster~~ — DONE

Hair is real geometry now, cut out of the roster itself. See "Closed" below.

## 6. `crashes` no longer earns its place

With flinging fixed and stuck reclassified as a rescue, the results panel
reads `crashes 0` almost every race (7-track drill: 14/14 finished, 0
crashes). It's honest — it now counts only falls and flips — but it may be
dead space on the results screen.

## ~~7. Dev tooling shipping in the app~~ — DONE (6fe1481)

Gated behind `#if DEBUG`, print included. One guard at the sink, not
eight at the call sites.

## 8. Loop: "camera helps but something's still off"

The loop's geometry measures correct (a true 0.8 m ring in the Y-Z plane
matching its spline) and the chase camera now swings to a 3/4 side angle so
it reads as a circle rather than an edge-on wall. Feedback after that fix
was that something remains wrong, and it was never isolated.

Prime suspects, both inherent to the current piece: the exit jogs 0.2 m
sideways (`lateralShift`, so entry and exit tracks don't collide), and the
ring overhangs its neighbours (occupies z −0.31…+0.49 while advancing only
0.18). Needs eyes on it before code.

## ~~9. Downhill start~~ — DONE

Requested and never done: cars should launch **down a slope** instead of
from a flat line. Blocked at the time by a parallel session; nothing stands
in the way now.

Needs the solver to allow a track to **begin above ground**:
`TrackLayoutSolver.solve` hardcodes `level = 0` / `position = .zero`, and
`BlueprintValidator` rejects `entryLevel < 0`, so a descending first piece
reads as underground. Cleanest is normalising levels so the minimum is 0
(which also makes "underground" impossible by construction), then spawning
cars on the descent in `RaceSession`.

## 10. More assets available if wanted

- **Kenney Blocky Characters** (CC0, 18 more characters, also ships
  `sit`/`drive`) — downloaded and inspected this session, not included.
  Body parts are separate meshes (`torso`, `leg-*`, `head`), so they'd
  support per-part tinting, unlike Mini's single colormap.
- **Quaternius Universal Base Characters** (CC0) — 6 bodies in **Regular
  and Teen** proportions, male and female. The only source found with real
  kid proportions; today's boy/girl are adult meshes scaled down. It's
  itch.io-only behind a click-through, and its realistic style clashes with
  the Kenney toy look.

---

## Prompt

> Work on Hot Wheels vs. Human (repo is the cwd). Read `CLAUDE.md` and
> `Documents/OPEN-THREADS.md` first. In that doc the **"Closed" section at
> the bottom is the most useful part** — it records where the previous
> session's diagnoses were *wrong*, which saves more time than what they got
> right.
>
> Open, roughly in the order a player would notice:
>
> 1. **`.bump` drives through its own mesh.** It uses the same
>    `track-wide-straight-bump-up` model as `rampJump` but kept a flat
>    `.line` spline, so cars pass through a 10 cm hump on every track that
>    has one. `CenterlineShape.crest` already exists and fixes it in one
>    line — but that turns every bump into a jump, which is a feel decision,
>    not a bug fix. Decide first. Related: `.bump` and `.rampJump` now render
>    as the same piece and behave differently; a taller dedicated ramp mesh
>    would settle both.
> 2. **Dev tooling ships in the app** (item 7). `RaceSession.drillLog` writes
>    `Documents/drill-log.txt` on every call, in release too. Gate it behind
>    `#if DEBUG` or a launch argument.
> 3. **The loop still reads wrong** (item 8) — never isolated. Needs eyes on
>    it before code.
> 4. **`crashes` may be dead space** on the results panel (item 6).
> 5. Leftovers from the hair work: `character-male-c`'s extracted island is a
>    **police cap**, already converted and offered nowhere — it belongs in
>    `HatStyle`. And `.character` hair ignores `hairColorHex` while every
>    picked style honours it, so a kid dragging the hair-colour swatches on
>    a default character sees nothing happen.
>
> Things that will cost you an hour if nobody tells you:
>
> - **Another session has been editing this working tree.** Check
>   `git status` before starting. If files you didn't touch are dirty, don't
>   sweep them into your own commits, and don't `git checkout`/`stash` —
>   use a worktree if you need a clean tree. Item 3 (reaction cam) is
>   in-flight from that session and uncommitted as of 7e98197.
> - **`RaceTuning.maxTrackPieces` went 75 → 2048** in someone else's commit
>   with no stated reason. Worth confirming that was deliberate.
> - **The rescue and crash counters cannot see track geometry.** Rail-mode
>   cars are kinematic and `RaceRulesSystem` skips every stuck/flip/fall
>   check for them (`RaceRulesSystem.swift`), so a clean drill log proves
>   nothing about collision. Assert geometry in tests instead.
> - **Reinstall the app before trusting any sim run.** A stale binary cost
>   the last session an hour chasing a "regression" on Loop-de-Leap that was
>   really an old build silently falling back to `.demo` — the race even
>   reported a plausible-looking 3.5 s finish.
> - **CoreSimulator dies constantly on this machine.** `killall -9
>   com.apple.CoreSimulator.CoreSimulatorService`, re-boot, rerun. It is not
>   your code.
>
> Verify the way this project does: build BOTH destinations, run the unit
> tests, and actually race in the simulator with screenshots — feel is
> human-tested, and several bugs this project has hit were invisible to a
> green test suite. Commit in small pieces with the reasoning in the
> message, and push.

## Closed 2026-07-20

**1 — the jump (6416a48).** As predicted. `CenterlineShape.crest` is a raised
cosine at 0.10 m, measured off the bump-up mesh so the spline sits on the
model rather than under it. Verified airborne on the solved lane (>0.3 m of
air) with a plain-straight control, and raced on Jumpy Junction.

**2 — the hill seam (0e7df53). The diagnosis in this file was wrong in an
instructive way.** There was no "lip at the junction between a flat slab and
a pitched slab". `TrackSpawner.bedCollision` used
`pitch = atan(rise / length)`, and a right-handed rotation about +X carries
+Z toward −Y — so every hill's collision slab was pitched *opposite* to its
own spline. On hillUp that stands the slab's high end up as a ~20 cm wall
at the entry seam. One character (`-atan`).

More importantly: **the rescue count this file said to drive to zero was
already zero, and had been for some time.** Rail-mode cars are kinematic and
`RaceRulesSystem` skips every stuck/rescue check for them
(`RaceRulesSystem.swift:140`) — they float straight through the lip. The
defect only ever bit chaos mode. The "Mount Kaboom needed 4 rescues" figure
predates rail mode being the default. Re-verified today across all 7 preset
tracks: 0 rescued, 0 destroyed, every car finishes. **The rescue counter is
not a usable signal for track geometry in the mode we ship** — geometry
needs tests (`hillBedSlabsPitchAlongTheirOwnRise`), not drill greps.

**4 — the twelve characters (fc91894).** A numbered "Person" row (1…6) under
Body in the Face tab. The variant list moved onto `DriverProfile` so the
picker, the bundle check and the pose check share one list.

**9 — the downhill start (3c61274, 26dc6ce).** `TrackLayoutSolver.solve`
normalises elevation so the track's lowest point rests on the ground, which
lifts the start instead of burying the first descent. That made
BlueprintValidator's "can't go underground" rule unreachable, so it's gone —
underground is now impossible by construction. `TrackLayout` gained
`startPosition`, and circuit closure is measured against it rather than the
origin (an elevated circuit no longer returns to zero).

All 7 starter tracks now open downhill: `StarterPresets.downhillStart`
*replaces* the first straight after the start gate with a `hillDown` rather
than inserting a piece, so piece counts, footprints and headings — and
therefore all 7 locked layouts — are untouched. The start gate ends up one
level up on its existing legs. Cars measurably gain speed on the descent
(2.2 → 2.5 m/s before the flat).

**5 — hair (4406c57).** The decision was "picking hair overrides the
character's own", and the art came from an unexpected place: not a
downloadable pack, but the roster we already ship.

Searched first. Kenney has no pack with detachable hair — Blocky is six
cubes with hair painted on (no silhouette), and the Animated Characters
series is one mesh with swappable PNGs. KayKit is fantasy adventurers in
helmets. The only CC0 pack with genuine mix-and-match hair meshes is
Quaternius Universal Base Characters (20 styles) — anatomically-detailed
adults in underwear, clothed by a *fantasy armour* pack. Not for this game.

Then measured what we had: every Kenney Mini character is built on the SAME
76-poly skull (z 0.343…0.661, x ±0.16 — identical across all twelve) with
hair as disconnected islands on top. `tools/extract_character_hair.py`
separates them; `tools/preview_character_hair.py` renders the result.
11 hair meshes + 12 bald cuts × 2 poses = 35 new USDZs, perfectly
style-matched because they ARE the shipping art.

Gotchas worth keeping:
- Blender's "separate by loose parts" does NOT work on these: the glTF
  import splits vertices at every UV seam, so no two faces share a vertex
  and every face becomes its own part. Islands have to be found by welding
  positions first.
- Selecting faces for `mesh.separate` requires clearing vertex AND edge
  flags too — entering edit mode rebuilds face selection from vertices, so
  stale flags hand it the whole mesh. That silently took the entire head off
  every character and still exported fine. Caught by comparing poly counts,
  not by looking.
- Height alone can't classify hair (long hair hangs below the crown, and
  beards sit above nothing). Skull-match + colormap colour + a cranium
  height floor gets all twelve right.

Still open on hair: **male-c's island is a police cap**, not hair. It
extracts correctly so his bald cut is hatless, but it's offered nowhere —
it belongs in `HatStyle`. That's a free hat if someone wants it.

Also: `.character` hair keeps its baked colour and ignores `hairColorHex`,
while every picked style honours it. Correct as designed (their own hair is
part of who they are), but it's a real asymmetry someone will notice. The
editor now hides the Colour swatches on `.character` and `.bald` rather than
offering taps that do nothing — the hair patch is the obvious next thing to
add to `RosterColormap` if someone wants "their own hair, my colour".

**Eyes are still baked.** Skin, Shirt and Pants are live on the roster now
(`RosterColormap`), but eyes and eyebrows are a few texels inside the skin
patch, not a patch of their own, so `eyeColorHex` only moves the
reaction-cam bust. Either extract an eye mask offline or accept it.

**Thin pale slivers** float beside some roster characters in the wardrobe
bench (`--wardrobe`) and the character editor — most visible on `bald`,
`longHair` and `spike`. Pre-existing geometry, confirmed present before the
colormap work (it read as a dark sliver then and simply repaints lighter
now); nobody has yet identified which mesh it belongs to.

## 3D grid avatars (crash — fixed by reverting)

A concurrent session swapped the profile picker and character-select GRID
tiles from the 2D `DriverFaceBadge` to a live `DriverPreviewView` (a full
RealityView) each. One RealityView per tile = N simultaneous RealityKit
scenes. That renders fine on the Simulator (the `--wardrobe` bench runs 16 at
once), but on a real device each scene needs its own Metal drawable pool and N
of them exhausts the GPU: `[CAMetalLayer nextDrawable] returning nil because
allocation failed`, then RealityKit binds a fallback 2D texture into the 1D
`tonemapLUT` slot and the render thread aborts under Metal validation. Crashed
on launch for anyone with a few profiles set up.

Capping DIDN'T work: `liveSceneCap = 5` still crashed the same device. The
count was never the real variable — a `RealityView` inside a recycling
`LazyVGrid`/`ScrollView` is, and RealityKit aborts on device with even a few.

Fixed properly with STATIC SNAPSHOTS (`DriverThumbnailStore`, iOS-only):
`DriverGridAvatar` shows the 2D `DriverFaceBadge` immediately, then swaps in a
still `UIImage` rendered ONCE off-screen through a single transient `ARView`
(`cameraMode: .nonAR`, parked off-screen in the key window so it actually
ticks). Renders are serialised on a task tail — one ARView alive at a time,
never N — so the on-grid live-scene count stays zero. Cached by appearance
signature; a blank/failed grab returns nil and the tile keeps its 2D badge, so
the worst case is a cosmetic downgrade, never a crash. Verified rendering real
3D stills on the Simulator; the single transient scene is the same shape as
the editor turntable that already works on device. Single, non-recycled
previews (editor turntable, customizer tab) stay live 3D as before.

If a device ever shows blank tiles: bump the 250 ms settle in
`DriverThumbnailStore.snapshot` (the rig may need longer to load/draw), or the
off-screen ARView isn't ticking there — fall back to `liveSceneCap`-style 2D
by having `DriverGridAvatar` skip the render.

## Closed 2026-07-20 (later session)

**Handoff 1 — `.bump` (38bb2ba).** Decided as "bumps should bump", and the
decision turned out to be forced rather than free. Rail mode launches where
the bed falls away faster than gravity; that threshold is crossed above
roughly a **2 cm** crest at race speed, and the mesh humps **10 cm**. So
there is no "match the mesh but stay planted" setting — any spline sitting
on this model launches off it. The choice was only ever *bumps jump* vs
*flatten the mesh*. `.bump` also joined `.rampJump` on exact-mesh collision
for chaos mode, and is now identical to it apart from the entry-speed gate.

**Handoff 2 / item 7 — drill logging (6fe1481).** `#if DEBUG` at the sink.

**Handoff 5 — hair leftovers (7c90a46).** `character-male-c`'s island is
`HatStyle.policeCap` now, loaded through the same mesh path as hair (same
extractor, same head-joint origin) but tinted from the hat swatch. The
hair-colour column hides for `.character` and `.bald` — the two styles it
cannot affect — because a control that does nothing is worse than no
control. Test now asserts every `HatStyle` with a mesh is both bundled
*and* offered by `DriverDressUp.props`, which is the gap that let a
converted USDZ sit in Resources reaching no head.

**NOT verified: the unit suite never ran.** Both destinations build green
with these changes plus the parallel session's loop work. The test suite
was attempted five times and died five times on environment, never on an
assertion — see the hazard below. Someone should run it before trusting
any of this, and nothing here has been pushed.

### Environment hazard that cost this session an hour

**Concurrent Claude sessions fight over one machine's simulators, and the
symptoms look like your code.** This session lost five test runs to it:

- A session working on an **unrelated repo** ran `pkill -f xcodebuild` and
  `killall -9 com.apple.CoreSimulator.CoreSimulatorService` before each of
  its own builds. That kills *every* simulator and *every* build on the
  machine. Symptoms: exit 144 (signal death), `Mach error -308 (ipc/mig)
  server died`, `Invalid device state`.
- A second session on **this** repo was testing on the same simulator UDID
  and the same DerivedData. Symptoms: `unable to attach DB: database is
  locked. Possibly there are two concurrent builds running in the same
  filesystem location.`

`-derivedDataPath` in a scratch dir fixes the lock. A dedicated
`simctl create` device does **not** save you — `killall CoreSimulatorService`
takes down devices you created too. Check `pgrep -fl xcodebuild` before
concluding anything about your own code, and note that the existing
"CoreSimulator dies constantly on this machine" advice below is at least
partly *this*, not hardware.

**Also: a shared working tree means shared test runs.** Both Hot Wheels
sessions were editing the same checkout, so either one's "tests green"
covers the *combination* of both sessions' uncommitted work, not their own
change in isolation. Commit your own hunks (`git hash-object -w` +
`git update-index --cacheinfo` stages a hand-built blob without touching
the working tree) before trusting attribution.

### Noticed while in there, not fixed

- **`.bump` drives through its own mesh.** `.bump` uses the same
  `track-wide-straight-bump-up` model as `rampJump` but keeps a flat
  `.line` spline, so cars pass through a 0.10 m hump on every track that has
  one. Giving it the crest shape would fix the visual — and would also turn
  every bump into a jump, which is a feel decision, not a bug fix.
  `.bump` and `.rampJump` are also now visually identical pieces that behave
  differently; a taller dedicated ramp mesh would settle both.
