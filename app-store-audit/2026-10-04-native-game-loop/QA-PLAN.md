# HWvH launch and finish QA plan

This candidate preserves the existing navy/yellow toy workshop and the user's iPad and tvOS-only platform scope. It is based on `44d929c6f1d54d6063270fb18e023a25062da2f2`. The 2026-10-03 release galleries/packages and audit are historical, not proof of these changed bytes.

The root audit is at `../..` in the workspace's `app-release-audit/games/2026-10-03/hot-wheels-native-launch-finish-audit.md` and its JSON companion. It already verified extensive TV workshop parity. This round concentrates on changed launch, settings, race/result and sharing surfaces.

## Held inputs and compile

The numbered `native-inputs.candidate-*.json` records cover native sources/resources, project and test sources. Native files were tracked-clean at the base revision; pre-existing documentation, marketing/tooling edits and all historical artifacts are preserved. No version, device-family or supported-platform settings were changed.

Root owns the serialized jobs2 slot. The proposed commands, run sequentially only after that slot is released, are:

```sh
xcodebuild -project 'Hot Wheels v Human.xcodeproj' -scheme 'Hot Wheels v Human' -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/hwvh-game-loop-ipad-20261004 -jobs 2 CODE_SIGNING_ALLOWED=NO build-for-testing
xcodebuild -project 'Hot Wheels v Human.xcodeproj' -scheme 'Hot Wheels v Human' -configuration Debug -destination 'generic/platform=tvOS Simulator' -derivedDataPath /tmp/hwvh-game-loop-tv-20261004 -jobs 2 CODE_SIGNING_ALLOWED=NO build-for-testing
```

Record logs, exit codes, exact native input hashes, .xctestrun/app/dylib hashes and Info.plist version/device families. Preserve every failed build receipt before a narrow repair. No signing, upload or release occurs here.

## Runtime isolation

Root allocated TV `BF090DFE-C6F6-4FF4-AB70-8870241B497E`, tvOS26.5. After the final Fendoku handback, root separately allocated Pad `025B233C-9EE8-48DD-A4E8-BB88CF93F0DE`, iOS26.5, for exactly the three named UI methods after the TV Share correction passed. Both are verified Shutdown before their bounded runs. Other device UUIDs remain untouched.

Before booting an allocated device, record the existing normal app stores/preferences by path, size and hash, without printing their contents. Review the compiled DEBUG fixture branches. Each UI method launches with a new `-HWTestSession UUID`; relaunch within a method reuses that UUID. SwiftData lives at a private tmp directory, preferences use its private suite, sound/haptic output and Bonjour/Multipeer start are suppressed. The test host chooses real existing deterministic starter content. No fake result state, altered race rules or physical photo-library seed is used. Unit tests use a blank host and memory-only models.

Use only headless simctl/XCTest on an allocated UUID. Read appearance before and after, with no appearance or host setting changes. Do not open Simulator.app or send native keyboard/mouse input. Capture native XCUIScreen attachments. Shut down the owned device in a finally block, even on failure. Verify that normal stores/preferences did not change.

## Bounded tests

Enumerate the compiled test identifiers first. Do not count zero tests as a pass or repeat a broad suite to discover filtering grammar.

- `GameLoopTests.absentPreferencesAreOnAndSavedChoicesSurviveAnotherStore`: fresh values On, independent choices, stored Off, OS Reduce Motion precedence.
- `GameLoopTests.finishSnapshotIsImmutableAndRanksFinishersBeforeOutCars`: actual freeze factory copies racer values and ranks finishers ahead of out cars.
- `GameLoopTests.realImageAndResultRoundTripAndBadPayloadIsRejected`: decoded native image/result equality, corrupt/oversized image and envelope rejection.
- `GameLoopTests.standaloneTVHandoffTransfersFrozenBytesToDashboardAndStops`: the real codec/loopback path transfers exact image bytes to a dashboard without inventing telemetry and releases consumers.
- `GameLoopTests.nativeExportIsADecodableImageWithTheRealFrameAndResult`: actual native renderer produces a decoded PNG in private storage, keeps visible fixture pixels and includes the verified numeric App Store URL.
- Existing `CodecTests` are a relevant narrow regression for stale telemetry dropping; run only if enumeration confirms their identifiers.

`GameLoopUITests` has three methods per platform:

1. `testFirstViewportPlayActualFinishShareAndRematch`: first launch has visible Play without scrolling/profile creation; TV default focus is Play. Play reaches a real deterministic starter race through normal physics/rules, real result statistics, a decoded finish image, and a fresh race after Rematch. iPad opens the actual native ShareLink chooser, records its ActivityListView accessibility tree, dismisses through an observed native dismissal control, and retains the same frozen result before Rematch. No recipient or external destination is selected. TV exposes the local image handoff panel. Attach each actual state.
2. `testIndependentSavedSettingsAndCalmPlay`: defaults On, animation Off leaves haptics On, both Off survive relaunch. iPad uses process-local UIKit largest-text category. Play remains in the first viewport. Actual calm camera and boost controls remain visible. No system Reduce Motion or appearance settings are changed.
3. `testOptionalProfileStillOpensEveryWorkshop`: normal profile creation still opens the workshop. All eight TV destinations remain, and real remote-focused paint changes affect the car. iPad retains its touch destinations. Existing broader persistence/parity receipts remain historical; they are not relabeled as new passes.

## Pixel review and required limits

Review launch, settings, actual result, actual frozen frame and rematch on both platforms. The render texture capture is new iOS/tvOS26 API. Check orientation, color, actual cars/track, result agreement and absence of blank frames, including calm mode. No replacement art or marketing composites count as native QA.

TV ShareLink is unavailable in the installed Apple SDK. Standalone TV Share uses the existing local encrypted service only while the panel is open, then an iPad's native share action. Automated loopback verifies protocol/data fidelity. Physical TV-to-iPad discovery, permissions, delivery, reconnect and successful user-selected sharing remain required manual-device checks. Simulator-to-Simulator discovery is not reliable proof.

This is continuous physics, so no artificial CPU-turn delay is added. Actual computer movement and the genuine Boosting indicator are visible. The existing boost/reaction timing remains unchanged. Largest-text launch/settings checks do not certify every legacy workshop at every accessibility/window size. No full-release approval is implied until root reviews current pixels and remaining limits.
