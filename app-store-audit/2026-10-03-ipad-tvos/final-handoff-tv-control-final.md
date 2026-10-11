# Final HWvH release handoff

The final native release source is `44d929c6f1d54d6063270fb18e023a25062da2f2`, version 1.0, build 1. iPad is family `[2]`; Apple TV is family `[3]`; both require OS 26. Production archives use the normal Release default with testability disabled. No iPhone, Mac or visionOS release was built by this task.

The release owner verified and created ASC app `6818777508`, name HWvH, SKU `hwvh-ipad-tvos-2026`, using the existing bundle `com.nathanfennel.Hot-Wheels-v-Human`. Both iOS and tvOS 1.0 were Prepare for Submission with no prior published device families or builds. This is authenticated owner evidence, separate from historical public lookup. The original record-creation screenshot is preserved privately outside Git.

## Source and native verification

All 864 native/project/test inputs matched the final freeze before and after archives, runtime verification and gallery composition. The [source proof](native-source-inputs-tv-control-final.json) has canonical input hash `fc4fbdb72493ee39da8a2eb82c24915d1ad319b9e9ad8920eea39f9af499d678`. The final production-input comparison preserves the exact reviewed two-file tvOS-only delta: readable camera/visibility buttons with dark backing and a results hint naming the local Rematch control. iPad production behavior is unchanged.

The [final native build proof](native-builds-tv-control-final.json) records fresh Release compilation for both platforms and 18 passed final TV tests, 14 models plus four remote UI flows. Those UI flows cover camera/radio/volume, results/rematch, bright-world selected/focused visibility and actual remote boost. The retained iPad capture run passed 28 tests at its actual `69833ad` revision. The [per-capture compatibility proof](marketing/source-compatibility-tv-control-final.json) records why its 12 retained originals and eight unaffected TV workshop originals apply to this release. Actual capture revisions and hashes remain visible. No fresh final iPad runtime run or complete final TV rerun is claimed.

## Signed packages and upload plan

Durable root: `/Users/nathan/CodexReleaseArtifacts/HWvH/2026-10-03-44d929c`.

| Platform | Durable archive | Local IPA SHA-256 |
|---|---|---|
| iPad | `signed/ipad.xcarchive` | `2a2224f93509362b8552784bdb131d79fe8edb30b9012ab10d7c2fef0fe37328` |
| Apple TV | `signed/tvos.xcarchive` | `6f767271c88fe537184f5005e1f0c82ec5c0798395569fb3930b99d50a9fa5f1` |

Each IPA is `signed/<platform>-app-store-export/Hot Wheels v Human.ipa`. [Package inspection](signed-release-packages-tv-control-final.json) verifies actual distribution signatures, profile/bundle match, `get-task-allow=false`, families, version/build, OS 26, opaque iPad icon, layered TV icons and top shelf, encryption flag and the privacy manifest. [Durable preservation](durable-artifacts-tv-control-final.json) verifies all copied file bytes and both archive/export signatures without replacing the originals.

The [exact upload plan](upload-plan-tv-control-final.json) uses each durable archive sequentially with `xcodebuild -exportArchive`, `destination=upload`, automatic signing through the existing Xcode account, `manageAppVersionAndBuildNumber=false` and fresh output/log directories. No rebuild or source/version change is requested. The upload-options plist is outside native inputs at the durable root. Upload remains held until the release owner reviews the concrete plan. No upload, Apple processing or App Review submission is claimed here.

## Ready marketing assets

[Gallery review](marketing/exports/tv-control-final-01/review-index.html) has ten standalone opaque sRGB JPEGs per platform. iPad files are in `marketing/exports/tv-control-final-01/ipad-13`, 2752×2064. TV files are in `marketing/exports/tv-control-final-01/apple-tv`, 1920×1080. The exact ordered file and decoded-pixel hashes are in [final-gallery-verification-tv-control-final.json](marketing/final-gallery-verification-tv-control-final.json). The [original pixel provenance](marketing/exports/tv-control-final-01/marketing-provenance.json) includes capture fields, proof hashes and composition transforms.

| Order | iPad file | Apple TV file |
|---|---|---|
| 01 | `01-build-tracks.jpg` | `01-build-tracks.jpg` |
| 02 | `02-make-your-car.jpg` | `02-make-your-car.jpg` |
| 03 | `03-race-creations.jpg` | `03-race-creations.jpg` |
| 04 | `04-create-racer.jpg` | `04-create-racer.jpg` |
| 05 | `05-pick-paint.jpg` | `05-pick-paint.jpg` |
| 06 | `06-draw-your-way.jpg` | `06-draw-your-way.jpg` |
| 07 | `07-add-stickers.jpg` | `07-add-stickers.jpg` |
| 08 | `08-choose-world.jpg` | `08-build-worlds.jpg` |
| 09 | `09-save-builds.jpg` | `09-save-builds.jpg` |
| 10 | `10-hold-boost.jpg` | `10-remote-boost.jpg` |

The release owner independently approved both contact sheets and full TV10/iPad03 plus the real bright Driver output. Transition, wall and blank captures are retained as historical evidence and excluded from marketing. No screenshot pixels were invented or retouched.

## Remaining owner work

The release owner owns App Store metadata, gallery upload, pricing/countries, privacy and age declarations, review contact details, processed-build selection and final App Review submission. The scoped [audio/model provenance review](content-provenance-tv-control-final.md) found 17 CC0 source-pack license documents. Seven radio/music tracks are documented original synthesis. Commercial license evidence for 72 ElevenLabs-generated effect/voice files remains unrecorded; the owner needs generation-time subscription evidence before affirming those rights.

No assets, credentials or account agreements were changed during this provenance review. Personal review contact details and account screenshots remain outside Git. Earlier package, capture and failed-test proofs are preserved with their actual revisions.
