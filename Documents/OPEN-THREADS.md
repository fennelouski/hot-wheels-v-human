# Open threads — known gaps and unfinished work

Written 2026-07-20 against `1f2b6a1`, and rewritten as items closed. **Read
the "Closed" sections at the bottom first** — they record where previous
sessions' diagnoses were *wrong*, which saves more time than what they got
right. Ordered by how much a player would notice.

**Current as of 2026-08-28.** Items 1–7 and 9 are done, and item 8 (the loop)
is isolated — it's a corkscrew by design, so what's left there is a decision,
not an investigation. Still open: that decision (8), spare asset packs (10),
hardware validation (11). The ghost-track, tunnel and dig work that landed after 2026-08-23 went unrecorded here until
now — if you add a feature, add its thread.

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

## ~~3. Reaction cam is a different person from the driver~~ — DONE

Fixed by whoever did the Kenney clip conversion; this entry outlived it.
`DriverPoser.loadBust` loads `profile.modelName(pose: .idle)` — the driver's
OWN roster model — and the clip map at the top of the file is Kenney's
(`emote-yes` for boosted, `die` for crashed, `attack-melee-right` for
celebrating, picked on what moves above the waist because the PiP crops to
head-and-shoulders). There is no `bakedAppearance` flag left in the file.

## ~~4. Eight of the twelve characters are unreachable~~ — DONE

`DriverProfile.characterVariant` ("a".."f") is wired through
`modelName(pose:)` and covered by tests, but **no view sets it** — the
editor only exposes the four body types, so each shows one fixed variant.

**Fix:** a variant picker in `CharacterEditorView` (the `Body` row is the
natural home). All 24 USDZs are bundled and `everyRosterModelIsBundled`
already guards them.

## ~~5. Hair fights the roster~~ — DONE

Hair is real geometry now, cut out of the roster itself. See "Closed" below.

## ~~6. `crashes` no longer earns its place~~ — DONE

The column now appears only when somebody actually crashed
(`ArenaHUDView.anyCrashes`). Rail mode finishes clean, so the usual race
prints a tidier table and a crash-strewn one still gets its scoreboard.
Deleting the column outright would have thrown away the only place the
count is ever visible.

## ~~7. Dev tooling shipping in the app~~ — DONE (6fe1481)

Gated behind `#if DEBUG`, print included. One guard at the sink, not
eight at the call sites.

## 8. Loop: "camera helps but something's still off" — ISOLATED 2026-08-28

**It isn't the camera and it isn't a rendering bug. The loop is a
corkscrew.** `PieceCatalog.swift` defines it as
`.verticalLoop(radius: 0.4, advance: 0, lateralShift: -0.2)`: the car climbs,
crosses over, and is set down one bed-width to the SIDE having advanced
**zero** distance along the track. Drive it and you go around and come out on
a parallel lane, next to where you went in.

That is what "something's still off" is. A kid's expectation of a loop is
Hot Wheels': in one side, around, out the far side, still travelling the same
line. This one translates you sideways instead of forwards, and no camera
angle can make a sideways exit read as a loop-the-loop.

It is also not a defect — it's faithful to the mesh. `track-narrow-looping`
IS a corkscrew piece, measured off the GLB, and the catalogue comment above
it says so plainly ("It climbs, crosses over, and sets you down one bed width
to the RIGHT having advanced nothing — the toy"). An earlier session even
fixed a real bug here (the mesh was mounted backwards); the fix was correct
and the strangeness survived it, which is why this thread outlived it.

Reproduce: race `--preset-track 2` (Loopy Louie) and toggle Chase Cam. The
loop is the barrel-shaped ring; watch the lane the car leaves on.

**The choice is a design one, so it's still yours:**
1. **Accept it.** It's the real toy geometry and the pieces either side line
   up. Costs nothing.
2. **Pair it.** Follow every `.loop` with a compensating jog so the net line
   through the piece is straight. Solver work, no new art, and the loop stops
   moving you sideways.
3. **New art.** A true loop-the-loop that returns to the same line. Kenney's
   toy kit doesn't ship one; this means modelling or sourcing a piece.

Don't tune the radius to "fix" it — the radius is what decides whether a
heavy car clears the loop and a light one gets flung, which is the game
(PRD §2.1) and is human-tested, not test-covered.

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

**Superseded (ec2ce1a).** The level-normalising lift was tried (see Closed
item 9) and then REMOVED: down means down, and underground is a feature —
tunnels through hills, whole tracks buried. An elevated start is built the
honest way, with `hillUp`s first.

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

## 11. Never validated on hardware

Everything in this repo has been verified on Simulators. Still unproven on
real devices, and all three are the kind of thing a Simulator cannot tell
you:

- **Multipeer reconnect drills** (`MULTIPEER-HANDTEST.md`). Simulator-to-
  Simulator Multipeer doesn't work reliably, so the lobby, the drop, and the
  auto-reconnect have never run over real Wi-Fi between a real iPad and a
  real Apple TV.
- **Memory on device.** The `--stress-track` drill sits flat at ~497 MB RSS
  on the Simulator. A real iPad's budget is not the Mac's.
- **Anything GPU-shaped.** The 3D-grid-avatar crash (below) rendered
  perfectly on the Simulator and killed real devices on launch. That class of
  bug is invisible here by construction.

## 12. Rail mode is deterministic, so records rarely move

Tracks keep a best time now (`RaceResultRecord`, shown on the results panel).
Worth knowing before someone reports it as broken: rail-mode physics are
deterministic, so the same cars on the same preset finish in *exactly* the
same time every run — Loopy Louie is 14.5 s twice in a row. So an AI-vs-AI
drill sets the record on its first run and then ties it forever.

Real play does move it: a kid's boost taps are the variable, and different
cars and tracks have their own rows. But if you're testing the feature from
the CLI with `--preset-track`, "NEW TRACK RECORD!" appears once and never
again, and that's correct behaviour rather than a bug.

## Prompt

> Work on Hot Wheels vs. Human (repo is the cwd). Read `CLAUDE.md` and
> `Documents/OPEN-THREADS.md` first. In that doc the **"Closed" section at
> the bottom is the most useful part** — it records where the previous
> session's diagnoses were *wrong*, which saves more time than what they got
> right.
>
> Open, roughly in the order a player would notice:
>
> 1. **The loop is a corkscrew** (item 8) — isolated at last, and now a
>    design call rather than a bug hunt: accept it, pair it with a
>    compensating jog, or get new art. Read the item before touching it.
> 2. **Nothing has run on real hardware** (item 11). Multipeer reconnect,
>    device memory, and anything GPU-shaped are all unproven.
> 3. **Music is seven synthesized placeholders** (`Audio/README.md`).
>    Ducking and looping are done; somebody has to pick real tracks.
> 4. **Accessibility is thin** — three files carry labels, nothing honours
>    Reduce Motion. Low urgency for a family build, but the character roster
>    is literally an accessibility pack.
> 5. **The hair row is twelve chips wide on an 834 pt screen.** Bald sits at
>    the end (deliberately — it's the option that takes hair away), so it
>    needs a drag to reach and scrolling to it pushes the middle styles off
>    the left edge. Wrapping to two rows fixes both; left alone on purpose.
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
normalised elevation so the track's lowest point rested on the ground, which
lifted the start instead of burying the first descent. That made
BlueprintValidator's "can't go underground" rule unreachable, so it's gone.
`TrackLayout` gained `startPosition`, and circuit closure is measured against
it rather than the origin (an elevated circuit no longer returns to zero).

**The lift itself was then reverted (ec2ce1a)**, so "underground is now
impossible by construction" — which this entry originally claimed — is NOT
true any more. Digging is a feature: `hillDown` from ground level goes to
negative levels, the arena mounds a hill over the buried run, and
`TunnelDressing` gives it a mouth at each end and lamps down the middle.

**Consequence, since fixed:** because `downhillStart` dug and nothing
climbed back out, every starter track ran almost entirely at level −1 —
Wiggle Worm had 19 of its 20 pieces underground. `downhillStart` now pairs
the opening `hillDown` with a `hillUp` on the first straight that has no
hill on either side of it (a `hillUp` beside another hill becomes a RUN,
which is ±2 levels per middle and wouldn't balance). The plunge off the
line survives, the dig became a short lit tunnel, and every preset ends
back at level 0: Wiggle Worm is down to 4 buried pieces of 20, and the
seven tracks carry 2–4 tunnel mouths each.

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

~~**Thin pale slivers** float beside some roster characters in the wardrobe
bench (`--wardrobe`) and the character editor — most visible on `bald`,
`longHair` and `spike`. Pre-existing geometry, confirmed present before the
colormap work (it read as a dark sliver then and simply repaints lighter
now); nobody has yet identified which mesh it belongs to.~~ — **SOLVED
2026-08-23**: it was `character-female-a`'s forearm crutches. The bench's hair
grid is all `body: .woman`, so those tiles were all her. See the App Store
readiness pass above.

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


## Closed 2026-08-23 — App Store readiness pass

**Track seams (`PieceCatalog.modelScale`).** The `ponytail:` note in
`PieceCatalog` was right about the cause and wrong about the cost. Hill
transition meshes rise 0.2056 and 0.1955 against a 0.2 elevation level; the
models were placed to be exact at the piece's ENTRY, leaving up to 6 mm as a
step at the far seam of every hill on every track. Fixed by scaling each mesh's
Y by `level / meshRise` — ≤ 2.7%, invisible against the bed's own faceting.
The catch worth knowing: the scale acts about the MODEL ORIGIN and the bed sits
below it, so the bed lift has to scale with it or the entry seam breaks instead.
`spawnedHillModelsCarryTheirSeamCorrectingScale` guards the spawner wiring,
which is the only place this can silently fall out.

**`character-female-a` is a crutch user, and that was the "stray triangles".**
Kenney Mini Characters is an accessibility pack. female-a ships with forearm
crutches welded into `body-mesh` and rigidly bound to the arm and leg joints —
fine standing, but the `drive` clip swings those joints independently and
scatters the aid into loose blocks around her. She is `variants[0]`, so she is
"Person 1" for BOTH Woman and Girl, which is exactly the two the bug was
reported against. `tools/strip_mobility_aid.py` cuts it: the 8 islands (176
polys, 4 mirrored pairs) whose shape appears on none of the other eleven. Her
four USDZs are now the only ones not converted straight from pristine source.

**This also closes "thin pale slivers" (below), which was the same bug.** That
note said slivers floated beside some characters in `--wardrobe`, "most visible
on `bald`, `longHair` and `spike`", and that nobody had identified the mesh.
They're the crutches: `WardrobePreviewGrid`'s whole hair grid is built on
`body: .woman`, so every one of those tiles IS female-a. A before/after of the
bench settles it — at `fdb16be` every woman tile has shafts jutting out of it,
and after the strip not one does. Read as slivers rather than crutches because
the bench renders them nearly edge-on at that camera.

**Hair colour on "Their Own" (`DriverProfile.hairPropModelName`).** The colormap
route was tried first and abandoned: Kenney paints hair and eyes to the SAME
flat texel on more than half the roster, so a hair patch can only be separated
on 3 of 12, and on the dark-haired characters (female-a, male-a, male-f) a Hair
swatch would repaint the eyes. The geometry route wins — picking a colour lifts
the character's own extracted hair mesh onto their bald cut and tints it,
reusing the path every picked hairstyle already uses. 10 of 12 get it.

Ceiling, deliberate: **male-b and male-c can't.** male-b's only cranium island
is a beard (it stays on the bald cut) and male-c's is a police cap — already
`HatStyle.policeCap`, and a "hair" swatch that repaints a police hat is worse
than no swatch. `canRecolorHair` is false for both and the editor hides the
column. Two more small ones: the tinted prop is FLAT (it loses the colormap's
light/dark ramp — same as every picked style already looks), and once a colour
is picked there's no swatch that means "back to their own" — Undo is the only
way back. A "Their Own" chip in the colour row would fix the second.

**Four UI tests had been failing since the features they cover changed**, and
nobody noticed because nobody ran the UI suite. All four were stale
assertions, not app bugs — verified by reproducing each at `fdb16be` before
touching anything, which is the only way to tell the two apart:
`RaceSetupUITests` walked straight to the track cards after the setup screen
became a three-step wizard, and matched a headline whose wording had changed;
`WorkshopTryItUITests` looked for the chassis chips while the customizer now
opens on the Body tab, and waited on the exact label `"m/s"` — that's
`DashboardView`'s standalone unit, while the race cover shows `SoloArenaView`,
which formats "1.3 m/s". **The whole suite is green now, both destinations.**
If you add a screen, run the UI suite; these went stale one commit at a time.

### Worth knowing: the Local Network prompt now fires on the home screen
Gating "Race on TV" on a real TV means browsing from the home screen, so iOS
asks for Local Network permission on first launch rather than when a kid taps
through. Denying it can't strand them — `TVFinder.blocked` shows the tile
anyway, and `RaceOnTVView`'s connection ladder explains the permission — but
the prompt is earlier and more out-of-context than it used to be. If that
reads badly with real kids, the fix is to hold `TVFinder.start()` until
something warmer than a cold launch.

**Eyes swatch hidden where it does nothing (`RosterColormap.canRecolorEyes`).**
Six of twelve have `eyes: nil` and the Face tab offered the column to all
twelve, saving a colour that never reached a pixel.

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
