# XCODE-SETUP — one-time project configuration (Phase 0)

The project (`objectVersion 77`, Xcode 26) uses **filesystem-synchronized folders**: anything added under `Hot Wheels v Human/` on disk is automatically part of the app target. No pbxproj surgery needed for day-to-day work. Only the settings below need touching.

## 1. Enable tvOS on the existing target (recommended over a second target)
In `project.pbxproj` (or Xcode → target → Build Settings), for both Debug and Release of the app target:

```
SUPPORTED_PLATFORMS = "appletvos appletvsimulator iphoneos iphonesimulator macosx xros xrsimulator";
TARGETED_DEVICE_FAMILY = "1,2,3,7";        // 3 = Apple TV
TVOS_DEPLOYMENT_TARGET = 26.0;
```
Keep `SDKROOT = auto`. Then add a tvOS run destination via Product → Destination. If any template code fails to compile on tvOS (e.g., iPad-only APIs), wrap with `#if !os(tvOS)` rather than removing.

Why one target: the synced folder means every new file lands in *the* target automatically; two targets would require re-doing membership continually and is the main way this project could get miserable for an agent to maintain.

## 2. Info.plist — required for Multipeer Connectivity
Without these, peers silently never find each other on modern OSes:

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Hot Wheels vs. Human connects your iPad to your Apple TV to race.</string>
<key>NSBonjourServices</key>
<array>
    <string>_hwvh-race._tcp</string>
    <string>_hwvh-race._udp</string>
</array>
```
Service type constant in code must match: `hwvh-race`.

## 3. Entitlements
`Hot_Wheels_v_Human.entitlements` already exists. No special entitlements are needed for Multipeer. If SwiftData/CloudKit sync is ever added, do it later — keep v1 local-only.

## 4. SwiftData template cleanup
Delete `Item.swift`; replace the `ModelContainer` schema with `[CarDesign.self, DriverProfile.self, TrackBlueprintRecord.self]` once those exist (Phase 1/4). On tvOS, SwiftData is available but we don't persist designs there — guard container usage with `#if !os(tvOS)` if simpler.

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
  -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M4)' build
# tvOS build
xcodebuild -project "Hot Wheels v Human.xcodeproj" -scheme "Hot Wheels v Human" \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' build
# unit tests
xcodebuild -project "Hot Wheels v Human.xcodeproj" -scheme "Hot Wheels v Human" \
  -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M4)' test
```
(Adjust simulator names to `xcrun simctl list devices available`.)
