# HWvH native design and finish-review handoff

Recorded 2026-10-03. This documentation pass changed no production source, built no app, used no GUI or account operation, and made no commit.

## Frozen artifact and evidence

Previously frozen native source: `9b128e92539c0475033b00222731bfef865ef6b6`. Its native source-input receipt covers 863 inputs with canonical SHA-256 `f653b283ce0f950df0e5124a6c964367888c2b0578e5fb7fdcb55141c07e7835`. Subsequent TV runtime testing found cursor focus escaping on left/down input. Root is correcting focus isolation while the cursor is active; the correction, final native freeze and replacement build/package proof remain pending. The receipts below describe the earlier revision and must not be presented as final TV packages for the correction. UI-test helper edits are separately pending.

| Evidence file in this audit directory | Established result | Limit |
| --- | --- | --- |
| `native-source-inputs.json` | Frozen revision and native-input hashes | Documentation and per-user state are excluded |
| `native-builds.json` | Successful Release iPadOS and tvOS Simulator builds for testing; HWvH 1.0 (1), minimum OS 26, families 2 / 3 | Test-host `ENABLE_TESTABILITY=YES` is an override, not the production package setting |
| `tv-model-test-summary.json`, `tv-model-test-details.json` | 14 of 14 passed: race-lifetime and remote track-builder/persistence model checks | No visual, focus, real-device networking or full workshop acceptance proof |
| `native-builds.json/modelTestEvidence/iPadOS`, console log `/tmp/hwvh-ipad-models-20261003.log` | Console records 16 tests in four suites passed and test execution succeeded | The xcresult summary failed to write because the disk was full; its `unknown` / zero-test extract is incomplete. This is a console pass, not complete structured-result evidence |
| `signed-release-packages.json` | Production Release archives and App Store exports verified for iPadOS/tvOS; exported IPAs have valid Apple Distribution signatures and non-debug entitlements | Neither IPA uploaded; package preparation does not prove store history, acceptance or submission |
| `marketing/manifest.draft.json` | Draft capture/gallery plan | No completed ten-image reviewed gallery per platform |

Use the receipts above and the refreshed `release-checklist.json` for historical source/package facts and the current source delta. The checklist marks the TV package superseded and the replacement freeze pending. The unchanged iPad candidate still needs binding to the new global input proof. Do not silently infer runtime/store completion from package preparation.

## Input packet for the independent native finish reviewer

- **Request and confirmed constraints:** preserve iPad; give tvOS the full car, racer, track and local-race workflows through the remote; navy/yellow toy workshop; minimum 60 pt remote targets; profile gate; no visionOS work. The owner-provided App Review contact is private and excluded.
- **Artifact:** require the final replacement native freeze and corresponding source/build/package receipts before release review. The historical source above and its receipts explain the starting point. Inspect `Hot Wheels v Human/App/RootView.swift`, `App/TVWorkshopControls.swift`, `Features/Customizer/TVCustomizerView.swift`, `Features/Customizer/TVPaintTools.swift`, `Features/Customizer/TVTwoPlayerCustomizerView.swift`, `Features/TrackBuilder/TVTrackBuilderView.swift`, the profile/racer/garage screens and shared arena/race lifetime code.
- **Written spec:** root `DESIGN.md`, `.impeccable/design.json`, this directory's `native-surface-brief.md`, and `/Users/nathan/Documents/GitHub/app-design-guidelines.md`.
- **Visual authority:** the preserved iPad interface and implemented frozen TV interface. No approved comp, seeded form board or comp-fidelity diff exists for this retrospective documentation pass. Do not manufacture one or describe source extraction as comp approval.
- **References:** Impeccable `reference/ios.md` and `reference/craft-floor.md`, plus Apple TV native focus/input conventions. Installed skill root: `/Users/nathan/.codex/plugins/cache/openai-curated-remote/impeccable/4.3.1/skills/impeccable/`. Both reference paths exist; the finish reviewer must read them rather than treating this handoff as a substitute.
- **Detector:** no Impeccable HTML/CSS detector ran. It has no verdict on SwiftUI/RealityKit. The reviewer must judge native platform behavior and the craft floor.
- **Required screenshots and behavior records:** pending below. No placeholder path denotes an existing capture. Pass genuine frozen-build captures from every inspected native device class and the runtime log/recording needed for focus and lifetime checks.
- **Prior source review:** the known imported-drawing lifetime and default-portal reachability defects were fixed before the freeze. No other confirmed material blocking source finding remained in that review. This is not a visual or device-multiplayer verdict.

## Evidence still required

| Native evidence | Required coverage | Current acceptance state |
| --- | --- | --- |
| iPad captures | Profile gate/home; car paint/livery/stickers/drawing/driver; racer; track pieces/decorations/worlds/camera/library/portal; Garage; opposing two-player bench; race controls/results | Pending frozen-build visual acceptance |
| TV captures and remote run | Profile gate/home; full car/racer/track tools; focus vs selection; custom color; sticker/drawing; remote placement and portal exits; Garage/library; two-player switch/race; race controls/results | Pending frozen-build visual and focus acceptance |
| TV cursor correction and new freeze | Reproduce left/down movement, verify cursor focus isolation, Select placement and Menu/Back return, then bind final source/build/package receipts | Runtime defect confirmed; correction and final proof pending |
| Persistence | Explicit save/failure feedback, relaunch saved car/racer/track/profile/settings, section switching and drawing/undo | Pending end-to-end acceptance; source/model evidence is narrower |
| Race lifetime | Repeated preview, Back/close/reopen, countdown cancellation, two-player Race Together, rematch and navigation return | Model cancellation checks passed; native runtime acceptance pending |
| Physical local multiplayer | Actual iPad-to-Apple-TV discovery, join, reconnect and equivalent race behavior | Pending; do not claim all-device multiplayer passed |
| Accessibility/adaptivity | VoiceOver labels/order, TV focus reachability, contrast, increased settings, Reduce Motion beyond shared buttons, iPad larger text/window/orientation/keyboard | Pending native inspection; fixed TV point sizes and dark colors are current implementation, not certification |

After valid captures are available, dispatch a fresh independent Impeccable finish reviewer with this packet and actual capture paths. Native captures should be indexed under `.impeccable/review/` or the existing audit capture tree with device class, OS, frozen build, screen/flow and provenance. Preserve raw captures. Require the reviewer’s contract sections and actual disposition; there is no `ship` verdict in this document. Run correction/recapture/verdict work only on material reviewer findings and update the frozen-source receipt if production code changes.

## Marketing and store gates

Prepare ten composed images for each supported iPad and Apple TV gallery, using each platform's actual submitted-build pixels. The first three communicate the main value; rotate three to four background treatments; use one to three genuine captures per image and concise top-centered headlines. Record source capture/build, composition output, dimensions, feature claims and review in the manifest. Check the images actually uploaded before submission. The current draft is not final evidence.

Authenticated App Store Connect verification still must establish the actual app record/history and prior device-family restrictions, correct selected builds, saved metadata/privacy/availability/free pricing and review submission. Privacy statements must be checked against the submitted binary and actual local networking/camera behavior, not copied from workshop design language. The private App Review contact belongs only in authorized store fields and must never appear in committed documentation, screenshots or public marketing.

Documentation is now available for review. Native visual acceptance, marketing completion and store submission remain open release gates; do not mark the overall release complete from this handoff alone.
