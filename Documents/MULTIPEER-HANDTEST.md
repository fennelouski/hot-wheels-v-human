# Multipeer hand-test — real iPad + real Apple TV (~10 min)

Phase 3's DoD has never been verified on hardware. This script walks the
whole loop. Run it top to bottom; note PASS/FAIL per step and report back.

## Setup (2 min)

1. Both devices on the **same Wi-Fi network** (not a guest network — many
   guest/hotel networks block peer discovery).
2. Build & install from Xcode onto both devices (one multiplatform target,
   pick each destination and Run).
3. Order matters for step 4's timing but not correctness — either device
   can start first.

## Test 1 — Discover & connect (2 min)

1. Open the app on the **Apple TV**. Expect the lobby: "Hot Wheels vs.
   Human — Open the app on your iPad to join!"
2. Open the app on the **iPad** → tap **Race on TV**.
3. **First run only:** iPad shows the Local Network permission alert
   ("Hot Wheels vs. Human connects your iPad to your Apple TV to race.").
   Tap **Allow**. ⚠️ If you tap Don't Allow, discovery finds nothing
   forever — fix in Settings → Privacy → Local Network.
4. Within ~5 s the TV should play the join horn and show a car card with
   the iPad's name; the iPad dashboard switches from "Looking for the
   arena…" to "Getting the race ready…".

   - **FAIL, no connection after 30 s:** note whether the permission alert
     ever appeared (if not, that's a plist/entitlement problem — but both
     built app plists were audit-verified to carry NSBonjourServices +
     NSLocalNetworkUsageDescription). Try toggling Wi-Fi on the iPad once.

## Test 2 — Race + boost round-trip (3 min)

1. The race should start on the TV automatically (design + demo/selected
   track submit on connect, ready-up is automatic in this flow).
2. Watch the TV: countdown → cars drive. The iPad is the dashboard:
   progress bar, lives, speedometer move with the race.
3. When the boost ring fills, **tap the boost button**. Expect the car on
   the TV to visibly surge in **well under a beat** (~150 ms budget).
   Do this 3–4 times. Note any tap that felt laggy or did nothing
   (dedupe means a dropped packet = that boost is simply lost — one miss
   in many taps is tolerable, misses every time is a FAIL).
4. **Hold FOR CAM** on the iPad → driver reaction PiP appears on the TV
   while held, disappears on release.

## Test 3 — Reconnect drills (3 min)

Each drill starts from a connected, racing (or lobby) state.

1. **iPad app backgrounded:** swipe to home on the iPad, wait 10 s,
   reopen. Expect: iPad shows "Whoops, lost the TV!" then reconnects by
   itself; race resumes streaming (the race keeps running on the TV
   regardless — TV is authoritative).
2. **TV app killed:** force-quit the TV app, relaunch it. Expect: iPad
   drops to "Whoops, lost the TV!", then reconnects, **resubmits its
   design + track automatically**, and a fresh race can start. (This
   resubmit-on-reconnect was added in this audit — before it, a TV
   restart stranded the iPad forever.)
3. **Walk away (optional):** carry the iPad out of Wi-Fi range or toggle
   airplane mode 10 s. Same expectation as drill 1.

   - **Known suspect if reconnect fails:** MultipeerTransport reuses one
     MCSession across drops; the standard fix is recreating the MCSession
     on drop before re-browsing (MultipeerTransport.start already builds a
     fresh session — a failed drill 1/3 means wiring stop()+start() into
     the dropped state). Report which drill failed and I'll wire it.

## Test 4 — Two quick sanity checks (1 min)

1. **Volume:** TV plays engine/crowd audio; iPad plays UI sounds. No
   double music playing from both.
2. **Sleep:** let the TV screensaver kick in (or press Menu) mid-lobby,
   wake it. Lobby should still be advertising and joinable.

## Test 5 — Two iPads (if you have a second one, +3 min)

1. Connect iPad A first (it's the **captain** — TV card shows
   "picks the track!"), then iPad B. Both cards appear with
   "getting set…" status.
2. Tap READY on A only → race must NOT start. Tap READY on B → countdown.
3. Verify each iPad's boost drives **its own car** (A boosts, A's car
   surges — the whole point of ownerID pairing). No robot in the race.
4. Connect a third device (or a phone build) → TV shows
   "Two racers max — grab the next race!" and the lobby stays at two.

## Report back

For each: Test 1 ☐  Test 2 ☐ (boost latency feel: ____)  Test 3.1 ☐
Test 3.2 ☐  Test 3.3 ☐  Test 4 ☐ — plus anything that looked wrong.
