# Open threads — known gaps and unfinished work

Written 2026-07-20. Every item below was **verified against `main` at commit
`1f2b6a1`**, not remembered. Ordered by how much a player would notice.

Paste the prompt at the bottom into a fresh session to pick this up.

---

## 1. The jump doesn't actually jump (rail mode)

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

## 2. A hill seam still traps cars — the rescue only hides it

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

## 4. Eight of the twelve characters are unreachable

`DriverProfile.characterVariant` ("a".."f") is wired through
`modelName(pose:)` and covered by tests, but **no view sets it** — the
editor only exposes the four body types, so each shows one fixed variant.

**Fix:** a variant picker in `CharacterEditorView` (the `Body` row is the
natural home). All 24 USDZs are bundled and `everyRosterModelIsBundled`
already guards them.

## 5. Hair fights the roster

`DriverDressUp` still builds hair from procedural boxes and spheres
(`long-hair`, `extra-long-hair`, `pigtails`, `curly-hair`), but roster
characters have hair **baked into their mesh and colormap**. So `HairStyle`
now layers geometry on top of hair that's already there. In the
`--wardrobe` bench, `long-hair` and `pigtails` don't visibly render at all.

**Decide first, then build:** is hair a customization axis, or part of
picking your character? If it stays an axis, the honest version is real
hair meshes and a bald base — which the roster doesn't provide. If it goes,
retire `HairStyle` from the editor and let the character carry it.

## 6. `crashes` no longer earns its place

With flinging fixed and stuck reclassified as a rescue, the results panel
reads `crashes 0` almost every race (7-track drill: 14/14 finished, 0
crashes). It's honest — it now counts only falls and flips — but it may be
dead space on the results screen.

## 7. Dev tooling shipping in the app

`RaceSession.drillLog` writes `Documents/drill-log.txt` on **every call**,
in release too. Great for CLI drills, wrong for a kid's iPad. Gate it
behind `#if DEBUG` or a launch argument.

## 8. Loop: "camera helps but something's still off"

The loop's geometry measures correct (a true 0.8 m ring in the Y-Z plane
matching its spline) and the chase camera now swings to a 3/4 side angle so
it reads as a circle rather than an edge-on wall. Feedback after that fix
was that something remains wrong, and it was never isolated.

Prime suspects, both inherent to the current piece: the exit jogs 0.2 m
sideways (`lateralShift`, so entry and exit tracks don't collide), and the
ring overhangs its neighbours (occupies z −0.31…+0.49 while advancing only
0.18). Needs eyes on it before code.

## 9. Downhill start — never built

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
> `Documents/OPEN-THREADS.md` first — the latter lists verified open gaps
> with file paths and repro steps.
>
> Please tackle, in this order:
>
> 1. **Make the jump actually jump.** `rampJump` has a flat spline, and rail
>    mode only launches off a spline crest, so it's currently a flat
>    straight in the mode we ship. Add a cresting centreline shape. Keep
>    entry/exit at y = 0 so the piece stays swappable with `.straight` —
>    that's what keeps all 7 locked preset layouts valid.
> 2. **Fix the hillUp seam** that wedges cars. The stuck-rescue currently
>    hides it; find it via `Documents/drill-log.txt` (`--preset-track 1`,
>    grep `rescued`) and fix the bed-slab junction in `TrackSpawner`. Then
>    confirm the rescue count drops to 0 across all 7 tracks.
> 3. **Add a character-variant picker** so all 12 roster characters are
>    reachable, not 4.
> 4. **Build the downhill start** — cars launch down a slope instead of
>    from a flat line. Needs the solver to allow an above-ground start.
>
> Then tell me what you'd do about hair (item 5) — I want to decide that
> one, not have it decided for me.
>
> Verify the way this project does: build BOTH destinations, run the unit
> tests, and actually race in the simulator with screenshots — feel is
> human-tested, and several bugs this project has hit were invisible to a
> green test suite. Commit in small pieces with the reasoning in the
> message, and push.
