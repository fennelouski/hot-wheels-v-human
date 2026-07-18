---
name: verify
description: Build, launch, and drive Hot Wheels v Human in the iPad simulator to verify changes at the GUI surface.
---

# Verifying Hot Wheels v Human

## Build / launch
- iPad sim: `iPad Pro 11-inch (M4)` = `F11899C4-D27C-4878-9AF0-BDDE4C72D549`; tvOS sim: `Apple TV 4K (3rd generation)` = `740ECE7B-E146-4AD2-BE24-B30D93AA5DC1`.
- Build commands: `Documents/XCODE-SETUP.md` §8. Keep BOTH destinations green.
- Static screens: `xcrun simctl launch com.nathanfennel.Hot-Wheels-v-Human <dev-arg>` then `xcrun simctl io <id> screenshot`. Dev args live at the top of `App/RootView.swift` (`--solo-arena`, `--race-on-tv`, `--trackbuilder`, …) and skip the profile gate.

## Driving interactions (taps)
simctl can't tap. Write a throwaway-or-keep XCUITest in `Hot Wheels v HumanUITests/` (see `RaceSetupUITests.swift` as the template):
- Launch with the dev arg via `app.launchArguments`.
- Match SwiftUI cards by predicate containment — labels concatenate ("Wiggle Worm, 20 pieces"). Prefer structural text ("pieces") over content names; starter rosters change.
- Attach screenshots (`XCTAttachment`, `.keepAlways`) at each step.
- Run with `-only-testing:"Hot Wheels v HumanUITests/<Class>" -parallel-testing-enabled NO -resultBundlePath <scratch>/x.xcresult` against the booted sim by id (cloning wedges CoreSimulator).
- Export evidence: `xcrun xcresulttool export attachments --path x.xcresult --output-path <dir>` (manifest.json maps names).

## Gotchas
- CoreSimulator wedge ("Failed to clone device", "Unable to find a device"): `killall -9 com.apple.CoreSimulator.CoreSimulatorService`, re-boot the sim, rerun without parallel testing.
- Multipeer does NOT work sim-to-sim — TV↔iPad flows verify on real devices via `Documents/MULTIPEER-HANDTEST.md`. In-sim, the dashboard correctly parks on "Looking for the arena…".
- Solo Arena (`--solo-arena`) is the full networked loop in-process — use it to watch a race actually run.
