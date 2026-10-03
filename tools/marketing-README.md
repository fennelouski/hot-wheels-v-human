# HWvH marketing compositor

`marketing-compose.swift` makes the complete iPad and Apple TV galleries from
an explicit native-capture manifest. It adapts the tested How to Adult compositor
without changing that project's script. It creates no app UI and never boots,
launches or reads a Simulator.

Run from this repository:

```sh
swift tools/marketing-compose.swift --self-test
swift tools/marketing-compose.swift --validate app-store-audit/2026-10-03-ipad-tvos/marketing/manifest.json
swift tools/marketing-compose.swift app-store-audit/2026-10-03-ipad-tvos/marketing/manifest.json
```

The self-test uses temporary solid-color fixtures only to check encoding,
platform separation and composition geometry. Normal execution rejects these
fixtures. The self-test removes its temporary images. Its success proves the
tool's behavior, not any HWvH feature or release readiness.

## Required inputs

Copy `manifest.draft.json` to `manifest.json` only after the native source is
frozen. Replace the pending revision, build reference and all evidence. Add
the real capture records; bind image layers to actual capture IDs. Do not
invent a native screenshot or mark a planned feature verified.

Each capture has `id`, `path`, `platform`, `sha256` and a `nativeCapture` object.
Relative paths resolve beside the manifest. The platform is `ipad-13` or
`apple-tv`. Native provenance includes:

- `kind`: `native-screenshot`
- `platform`, `revision` and `sourceBuildRef`, matching the manifest
- `device`, `deviceIdentifier`, `captureMethod` and `capturedAtUTC`
- `workingTreeInputsPath` and `workingTreeInputsSHA256`
- `attachmentManifestPath` and `attachmentManifestSHA256`

Preserve additional build, test, device and capture fields. The compositor
copies them into its receipt, including arrays and numbers. The input and
attachment proofs must be actual saved files with matching SHA-256 hashes.
Use the final native capture export and UI-test evidence as their source.
The same working-tree inputs and native build must support every gallery.

The submitted app's name is HWvH. Capture the Release configuration when the
name is visible. Keep build configuration and display-name verification in
the native provenance; changing text inside the screenshot is prohibited.

Each image also names a `featureID` and has `evidence` with a status of
`verified-native-build`, a plain observation in `summary`, the matching
`sourceBuildRef`, and a proof file's `proofPath` and `proofSHA256`. The proof
must connect the feature to the final native build through a passed test or
recorded native review. A source-code declaration alone does not prove runtime
behavior. The claim plan remains pending until that evidence exists.

## Output and review

The compositor writes exactly ten opaque sRGB JPEGs for each included platform.
It uses four alternating geometric toy-track backgrounds in the app's navy,
yellow, orange and blue colors. The upright hero is drawn last. Optional left
and right captures fan counterclockwise and clockwise behind it. All app pixels
come from original captures with uniform scaling and standard orientation.
There are no filters, UI overlays, retouched controls or cropped app images.

Every capture must retain native landscape dimensions accepted for its gallery:
2752×2064 or 2732×2048 for iPad 13-inch, and 1920×1080 or 3840×2160 for Apple TV.
Output sizes are 2752×2064 and 1920×1080. Apple's current
[screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
allow one to ten images and prohibit transparency. The owner's requirement is
ten images. The source was checked on 2026-10-03.

Outputs must be inside `app-store-audit`. Pick a new `outputDirectory` for every
export. The tool refuses to overwrite existing output files or provenance.
`marketing-provenance.json` records all source/output hashes, native provenance,
headline proof, revision, build reference, compositor hash and layer transforms.
`review-index.html` links the originals and full-size exports. The `review`
folder contains one contact sheet per included platform.

Inspect both contact sheets and representative full-size images after rendering.
Check readable UI, unclipped headlines, correct fan directions, useful capture
framing and truthful claims. Store upload, gallery inspection in App Store
Connect and submission are separate steps. This tool neither uploads nor submits.
