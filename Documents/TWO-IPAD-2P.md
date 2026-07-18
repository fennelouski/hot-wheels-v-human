# Two-iPad 2P — design doc (v2 stretch, PRD §"v2 stretch goal")

Status: **BUILT 2026-07-18** (signed off in-session). Implementation notes:
- Captain gating shipped as *first-valid-track-wins* — blueprint/config
  messages carry no sender, so attributing them to the captain would have
  meant more wire churn. The captain submits on connect, so first-wins is
  captain-wins in practice; solo keeps last-track-wins (rebuild → resubmit).
- The READY tap applies to the whole Race-on-TV flow (1P included) — an
  iPad can't know whether a second one is coming. Solo Arena still
  auto-readies. Everything else landed as designed; rules unit-tested in
  `TwoPlayerCoordinationTests`. Real two-iPad verification: piggyback on
  `MULTIPEER-HANDTEST.md` with a second iPad.
Scope: two iPads, one Apple TV, one race, one lane each. Split-screen 2P
on a single iPad stays the default 2P mode; this adds the two-device
variant on top of the same protocol.

## What already works (verified in code, no changes needed)

- **Transport:** the TV keeps advertising after the first iPad connects
  (`MultipeerTransport` host path), so a second iPad can join today.
  `send()` broadcasts to all peers; that's fine for snapshots.
- **Per-iPad dashboards:** `DashboardModel.myCar` filters every snapshot
  by its own `playerID`; boosts and reaction cams already carry
  `playerID` and are validated server-side. Two dashboards render
  themselves with zero changes.
- **Ready/rematch:** readiness is per-player and the race/rematch waits
  for *all* players — correct for 2P as-is.
- **TV lobby:** already renders one card per connected player and keeps
  playing the join horn.

## The three real gaps

### 1. Design ownership is arrival-order roulette
`RaceCoordinator.startRaceIfReady` pairs `designs[i]` with `players[i]`.
With two iPads submitting concurrently, iPad B's car can land on iPad
A's boost button.

**Proposal:** additive wire change — `carDesign` gains an optional
`ownerID: UUID?` (old peers decode it as nil → arrival-order fallback,
no `gameProtocolVersion` bump). Coordinator pairs by ownerID when
present. This is the only protocol change in the whole feature.

### 2. Config and track: who decides?
Both iPads currently fire `matchConfig` and `trackBlueprint`;
last-writer-wins silently.

**Proposal:** first iPad to say hello is the **Track Captain**.
- Host accepts blueprint + config only from the captain; a second iPad's
  track is answered with a friendly raceEvent, not silence.
- Host derives the mode itself: 2 human players connected → `.twoPlayer`,
  `aiDifficulty` ignored (2 lanes, 2 humans, no robot — see gap 3).
- TV lobby shows who's captain ("Ava picks the track!").
- iPad flow change: `RaceOnTVView` stops auto-readying; each iPad gets a
  big TAP WHEN READY button so the captain isn't racing before player 2
  finds the couch. (1P keeps auto-ready.)

### 3. Two lanes is a hard ceiling
Tracks are 2-lane by design (v1 rule; lane = index % 2 everywhere).
Consequences, not problems to fix:
- 2P = exactly 2 humans, **no robot** — a third racer would share a lane
  spline and rear-end its lane-mate forever. The PRD agrees (2P is
  human vs. human).
- The loop's narrow lane offset means 2P loops are shoulder-to-shoulder;
  already true of today's demo pair, it's a feature (crashes are funny).
- A third iPad saying hello mid-lobby gets a kind rejection on the TV
  ("Two racers max — grab the next race!") instead of today's silent
  ignore. Same for any hello arriving mid-race.

## Not doing (YAGNI, listed so we don't re-litigate)

- Track voting/merging — captain picks, rematch button re-runs.
- Per-player split camera on TV — one chase cam frames both cars today.
- Spectator iPads, 3+ players, lane picker — all need the 2-lane rule
  broken first, which is a v3 conversation.

## Build estimate (after sign-off)

Small: ownerID on carDesign + coordinator pairing (with test), captain
gating + kind rejections (with test), READY button on RaceOnTVView, TV
lobby captain label. One session including sim verification via two
loopback dashboards; real two-iPad verification piggybacks on the
MULTIPEER-HANDTEST.md session.
