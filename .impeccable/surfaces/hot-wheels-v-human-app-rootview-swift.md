---
version: 1
slug: "hot-wheels-v-human-app-rootview-swift"
primary_target: "Hot Wheels v Human/App/RootView.swift"
related_targets: ["Hot Wheels v Human/App/TVWorkshopControls.swift","Hot Wheels v Human/Features/Customizer/TVCustomizerView.swift","Hot Wheels v Human/Features/Customizer/TVPaintTools.swift","Hot Wheels v Human/Features/Customizer/TVTwoPlayerCustomizerView.swift","Hot Wheels v Human/Features/TrackBuilder/TVTrackBuilderView.swift","Hot Wheels v Human/Features/Arena/SoloArenaView.swift"]
---

# HWvH native workshop surface brief

Recorded 2026-10-03 from the native implementation reviewed at `9b128e92539c0475033b00222731bfef865ef6b6`. That freeze is historical for TV following the cursor-focus defect found in runtime testing; a correction and final source/package proof are pending.

## Scope and authority

Primary target: `Hot Wheels v Human/App/RootView.swift`. Related targets are the TV home/control style, profile picker, car/racer workshops, track workshop, two-player bench and shared race presentation. This is development documentation, never app-delivered copy.

The owner requires iPad and tvOS only, full TV workshop parity through the remote, and preservation of the existing iPad design. The current TV implementation is the visual authority for documentation: navy and yellow toy workshop, large controls, persistent real previews and local racing. No replacement identity, generated comp or seeded form selection was requested. This retrospective brief does not claim that a design contract was approved before implementation. Existing visionOS source/artifacts remain preserved; no visionOS build, boot, run, capture, upload or submission is authorized.

Visitor mode: **Operate**. The local player enters the workshop to make a toy, save it and race it. Race presentation is an experience reached from that operation. The visitor mode and this surface's composition are local strategy, not global tokens.

## Direction contract

**THESIS:** Put the creation beside the controls that change it. The TV workshop owns a usable remote bench rather than compressing the iPad's touch gestures into unlabeled remote shortcuts.

**OWN-WORLD:** Navy workbench, rounded system type, genuine toy previews and SF Symbols. Selected controls stay yellow with black text; a separate white outline follows remote focus. Every workshop remote control has a minimum 60 pt target.

**STORY:** Choose a local player, build or select a car/racer/track, see the changes, save successfully and race. Failures keep the draft available. Saved creations remain reachable from the workshop.

**FIRST VIEWPORT:** The TV profile gate precedes home. Home centers a maximum 1600 pt column, with identity and player switch above a full-width Quick Play action. A four-column workshop grid follows. Car/racer editing balances a persistent preview pane against a scrolling tool pane; track editing keeps a 60/40 scene/inspector workspace between permanent sections and actions.

**FORM:** Preserve the implemented native workbench. Ordered form-list position and seed key: not applicable to this source-documentation pass; no exploration script or identity-selection round ran. Written source authority is the frozen revision and `DESIGN.md`.

**FINISH:** unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

## Actual flows and hierarchy

| Entry | Creation or state | Primary action | Remote treatment / return |
| --- | --- | --- | --- |
| Profile gate | Existing local player or new racer | Select player / save new player | Adaptive native focus grid; save error leaves the gate usable; home player button returns here |
| Home | Current local player | Quick Play | Default focus on the wide action; Build a Car, Build a Track, Race a Robot, Garage, 2-Player Build, My Racers and Race with iPad remain distinct destinations |
| Build a Car | Body, chassis, tires, paint, livery, stickers, drawing, driver | Save Car / Test Drive | Preview and orbit controls stay visible; tabs and tools form separate focus sections; save failure retains edits |
| My Racers | Face, hair, clothes, extras | Save / Test Drive | Real racer preview with named orbit controls; native name field and reachable edit/select actions |
| Garage | Saved car and driver | Race / edit or remix | Actual car preview, name and secondary copy/scrap actions; preserve destructive confirmation |
| Build a Track | Pieces, decorations, worlds, camera, library | Save Copy / Race It | Scene, explicit inspector and persistent footer; remote cursor mode names Select and Back behavior; paired portals validated by shared model |
| 2-Player Build | Independent player-one and player-two drafts | Race Together | TV alternates the active bench; iPad retains the opposing bench; return/reopen requires runtime lifetime evidence |
| Race with iPad | Nearby local game session | Host / join race | Uses the local multiplayer transport; discovery, reconnect and physical-device parity remain unproved in this record |
| Race presentation | Car/driver, track and local opponents | Boost / rematch | Named camera, track visibility, radio and boost controls; exit returns to native workshop/lobby navigation |

## Signature interaction and motion

**Persistent toy, moving focus:** remote focus traverses tabs, shelves and actions while the same real creation remains visible. Selection remains yellow after focus leaves it. The shared control's white ring and 1.035 focus scale explain what Select will do; press scale is 0.98. Its 0.16/0.10 second ease-out transitions disable under Reduce Motion. This statement covers that style, not all scene/camera/race animation.

For track placement, Move with Remote is an explicit input mode with a visible cursor. Back returns to controls; it must not trap the user or remove the normal route back to the workshop. Runtime testing found that left/down movement could lose focus. The intended correction disables surrounding header/scene/footer controls while the cursor is active, keeping focus on Place Here until Select places or Menu/Back exits. This correction still needs native verification and a replacement TV freeze/package proof. Review this in a native runtime, not from a static scene image alone.

## Review state

`DESIGN.md` and `.impeccable/design.json` document the reviewed implementation and the pending cursor correction. Sidecar HTML/CSS samples are documentation previews, not native app screenshots. Native HTML/CSS detection is inapplicable and was not run. The [native design handoff](/Users/nathan/Documents/GitHub/hot-wheels-v-human/app-store-audit/2026-10-03-ipad-tvos/native-design-handoff.md) supplies the finish-review packet and lists the missing runtime/capture evidence.

No native visual acceptance score or finish-review disposition is asserted here. Model tests and signed exports are narrower evidence. Final marketing galleries, uploaded gallery inspection, authenticated store state and submission remain pending until recorded by the responsible release task.
