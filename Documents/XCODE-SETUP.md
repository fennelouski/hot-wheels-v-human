# XCODE-SETUP — one-time project configuration (Phase 0)

The project (`objectVersion 77`, Xcode 26) uses **filesystem-synchronized folders**: anything added under `Hot Wheels v Human/` on disk is automatically part of the app target. No pbxproj surgery needed for day-to-day work. Only the settings below need touching.

## 1. Enable tvOS on the existing target (recommended over a second target)
In `project.pbxproj` (or Xcode → target → Build Settings), for both Debug and Release of the app target:

```
SUPPORTED_PLATFORMS = "appletvos appletvsimulator iphoneos iphonesimulator";
TARGETED_DEVICE_FAMILY = "2,3";
"TARGETED_DEVICE_FAMILY[sdk=iphoneos*]" = 2;
"TARGETED_DEVICE_FAMILY[sdk=iphonesimulator*]" = 2;
"TARGETED_DEVICE_FAMILY[sdk=appletvos*]" = 3;
"TARGETED_DEVICE_FAMILY[sdk=appletvsimulator*]" = 3;
IPHONEOS_DEPLOYMENT_TARGET = 26.0;
TVOS_DEPLOYMENT_TARGET = 26.0;
SUPPORTS_MACCATALYST = NO;
SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO;
SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD = NO;
```

These settings apply to the app, unit-test and UI-test targets in Debug and
Release. Xcode generates `UIDeviceFamily` as `[2]` for iPadOS and `[3]` for
tvOS. Never add it by hand to Info.plist. Verify the generated value in both
signed exports before upload.

**iPhone is deliberately not shipped.** The iPad workshop has no supported
phone layout. macOS and visionOS are excluded as well. Existing platform
source and previous release artifacts remain preserved. The user has stopped
all visionOS build, Simulator, capture and submission work.

Keep `SDKROOT = auto`. The existing touch-specific UI suites compile only on
iOS. tvOS has a separate Siri Remote suite, using focus and directional
navigation. A successful iPad UI suite does not establish TV functionality.
iPad-only camera and PencilKit APIs must use `#if os(iOS)` because UIKit also
exists on tvOS.

Why one target: the synced folder means every new file lands in *the* target automatically; two targets would require re-doing membership continually and is the main way this project could get miserable for an agent to maintain.

## 1b. Display name is per-configuration
"Hot Wheels" is a Mattel trademark (PRD §1.1), so the shipped build must not
show it. The app target sets, in the app target's two configurations:

```
INFOPLIST_KEY_CFBundleDisplayName = "Hot Wheels vs Humans";   // Debug
INFOPLIST_KEY_CFBundleDisplayName = "HWvH";                   // Release
```

On-screen text goes through `AppBranding.name` (`App/Platform.swift`), which
switches on `#if DEBUG` to match. `PRODUCT_NAME`, the bundle ID, the scheme and
the `hwvh-race` Multipeer service are unchanged — they are tooling and wire
identifiers, and renaming the service would break discovery against installed
builds. Verify a release name with `-configuration Release`; the commands in §8
all default to Debug.

## 2. Info.plist — required for Multipeer Connectivity
Without these, peers silently never find each other on modern OSes:

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Connects nearby iPads and Apple TVs so you can race together.</string>
<key>NSBonjourServices</key>
<array>
    <string>_hwvh-race._tcp</string>
    <string>_hwvh-race._udp</string>
</array>
```
Service type constant in code must match: `hwvh-race`.

The camera usage description is generated only for the iOS SDKs. tvOS does
not request camera access. `ITSAppUsesNonExemptEncryption = false` records
that local multiplayer uses Apple's encrypted `MCSession` rather than an
app-owned encryption implementation. `PrivacyInfo.xcprivacy` declares no
tracking or developer collection and the `CA92.1` required reason for the
app's own `lastProfileID` UserDefaults value. Review these declarations if
networking, persistence or permissions change.


## 3. Entitlements
`Hot_Wheels_v_Human.entitlements` already exists. No special entitlements are needed for Multipeer. If SwiftData/CloudKit sync is ever added, do it later — keep v1 local-only.

## 4. SwiftData template cleanup
Delete `Item.swift`; replace the `ModelContainer` schema with `[CarDesign.self, DriverProfile.self, TrackBlueprintRecord.self]` once those exist (Phase 1/4). SwiftData is available on both destinations. Keep profiles, driver designs, cars, tracks and race records persistent on tvOS as well as iPad. A TV-only session must not require an iPad to create or edit them.

## 5. Asset conversion tooling (on this Mac)
GLB/FBX → USDZ options, pick whichever is installed:
- **Reality Converter** app (Apple, free): drag GLB in, export USDZ. Fastest for one-offs.
- **Blender CLI** (batch): `blender -b -P tools/convert_glb_to_usdz.py` (script to be written in Phase 0; Blender imports GLB and exports USD natively).
- Apple's `usdzconvert` (USD Python tools) if present.

Output naming convention in `Resources/Models3D/`: keep source names, e.g. `track-wide-straight.usdz`, `vehicle-speedster.usdz`. RealityKit loads with `Entity(named: "track-wide-straight", in: .main)` — bundle inclusion is automatic because `Resources/` is inside the synced folder. Verify each USDZ opens in Quick Look before committing.

## 6. README files inside the synced folder
Synchronized folders may treat the per-directory `README.md` files as bundle resources. Harmless, but if you want them excluded: select the synced folder in Xcode → File Inspector → add membership exceptions for `*.md` (or just leave them; a few KB of docs in the bundle hurts nothing).

## 7. Simulators needed
- iPad Pro 11" (iPadOS 26.x) — primary dev loop (Solo Arena).
- Apple TV 4K (tvOS 26.x) — arena verification.
- Multipeer between two Simulators is unreliable; test networking with ≥1 real device. Solo Arena (LoopbackTransport) exists precisely so 95% of development never needs networking.

## 8. Build/test from CLI (for Claude Code)
```bash
# iPad build
xcodebuild -project "Hot Wheels v Human.xcodeproj" -scheme "Hot Wheels v Human" \
  -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5)' build
# tvOS build
xcodebuild -project "Hot Wheels v Human.xcodeproj" -scheme "Hot Wheels v Human" \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' build
# iPad unit and touch UI tests
xcodebuild -project "Hot Wheels v Human.xcodeproj" -scheme "Hot Wheels v Human" \
  -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5)' \
  -parallel-testing-enabled NO test
# tvOS unit and Siri Remote UI tests
xcodebuild -project "Hot Wheels v Human.xcodeproj" -scheme "Hot Wheels v Human" \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' \
  -parallel-testing-enabled NO test
```
(Adjust simulator names to `xcrun simctl list devices available`.)

**The UI suite needs `-parallel-testing-enabled NO` to be trustworthy on this
machine.** Xcode fans the UI tests across four simulator clones by default,
and under that load taps land before the view they're aimed at exists — a
different one or two tests fail on each run and every one of them passes in
isolation. The historical pre-October iPad run had 26 UI tests, 0 failures in about 7 minutes. Current release evidence belongs in `app-store-audit/2026-10-03-ipad-tvos`; do not reuse that historical result as current proof. In parallel: green
about as often as not. Chasing one of those failures as a real bug costs an
hour; the tests that are load-sensitive are the ones that tap a palette chip
and then assert on a piece count, because the 3D spawn behind it is async.

**Never pipe these without `set -o pipefail`.** `xcodebuild … test | tail`
reports *tail's* exit code, which is always 0 — a failing suite looks green.
That is how `WorkshopTryItUITests.testCharacterEditorPiPAndTestDrive` sat
broken through several sessions: the failure was in the log the whole time,
under an exit status that said everything passed. Read the log for
`** TEST FAILED **`, or don't pipe.

Dev benches have no home-screen tile and are reached by launch argument —
`xcrun simctl launch <udid> com.nathanfennel.Hot-Wheels-v-Human <arg>`:
`--test-mode` (physics A/B), `--pip-tuner`, `--wardrobe`, `--reaction-cam`.
The full list is at the top of `App/RootView.swift`.
