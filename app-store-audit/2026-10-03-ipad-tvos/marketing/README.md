# Final iPad and Apple TV marketing

Twenty reviewed marketing images are ready locally for release source `44d929c6f1d54d6063270fb18e023a25062da2f2`. The iPad gallery has ten 2752×2064 JPEGs; Apple TV has ten 1920×1080 JPEGs. Each uses genuine native captures, four alternating backgrounds, centered short headlines, an upright centered hero and outward-fanned supporting captures. The release owner independently approved both contact sheets and full TV10/iPad03 plus the bright Driver native capture on October 3. No App Store gallery upload is claimed by this record.

- [Final handoff](../final-handoff-tv-control-final.md).
- [Current exports and visible capture provenance](exports/tv-control-final-01/review-index.html).
- [iPad contact sheet](exports/tv-control-final-01/review/ipad-13-contact-sheet.png).
- [Apple TV contact sheet](exports/tv-control-final-01/review/apple-tv-contact-sheet.png).
- [Exact dimensions, image hashes and pixel checks](final-gallery-verification-tv-control-final.json).
- [Final native source and build proof](../native-builds-tv-control-final.json).
- [Explicit retained-capture compatibility](source-compatibility-tv-control-final.json).

The final TV camera, visibility and boost heroes were captured at `44d929c`. The retained iPad originals and unaffected TV workshop originals keep their actual `69833ad` capture revision and build fields. The compatibility proof records the reviewed tvOS-only production delta and fresh final iPad/TV compilation. It does not claim a new iPad capture run. Blank, wall and transition captures remain preserved outside the galleries; they are excluded from positive claims.

ASC app `6818777508`, HWvH, was authenticated and created by the release owner for iOS and tvOS version 1.0, with no prior published families/builds. Signed artifacts are preserved under `/Users/nathan/CodexReleaseArtifacts/HWvH/2026-10-03-44d929c`. The exact upload plan awaits the release owner's review. No package upload or App Review submission has been performed by this marketing task.

## Historical 5643eca preparation, preserved

# Marketing preparation

Current source evidence is `5643eca1662dfc91f39d851ca0ea2ab5a8f9ce80`, after the iPad drawing-restoration fix. **Final composition remains held for meaningful iPad race captures and root’s camera review. No current gallery has been rendered or uploaded.** The strict ten-image rule remains intact.

- [Current source/claim plan and remaining captures](capture-plan.drawing-final-held.json).
- [Fresh native capture index](native-review-drawing-final/native-capture-index.json): 67 genuine PNG screenshots across final iPad gallery, drawing-restoration and TV remote UI runs; original bytes and attachment manifests preserved.
- [Current native build proof](../native-builds-drawing-final-gallery.json): exact 864 input equality, compiled executables, Release build logs, xctestrun paths/hashes, passed test identifiers and genuine per-run device/configuration records.
- [Eight verified iPad non-race feature mappings](feature-verification-ipad-drawing-final-nonrace.json).
- [TV feature evidence](feature-verification-tv-drawing-final.json) and [unrendered TV-only candidate manifest](manifest.tv-drawing-final.json).

The final iPad gallery run passed 24 tests; the separate drawing-restoration run passed two model and one UI test. TV remote UI passed all ten tests and produced 22 original screenshots. The earlier final TV run passed 14 model tests only; it is not represented as UI coverage. The 864 recorded native/project/test files match the frozen commit and current bytes at evidence verification, canonical SHA-256 `e7672e3ec0acfbfee5bfd26fc1e7b52b5e6265f249bac52c0048bf908dcae5e7`. Signed distribution packages retain production testability disabled; screenshot hosts explicitly enable it for XCTest.

Fresh TV08 and TV15 remain transition/blank frames, and TV19 is an orange-wall frame. All are excluded from marketing. iPad IPAD13–15 likewise show mostly the orange track wall and cannot serve as race/boost heroes. Root is investigating the actual camera path and a weak yellow-on-yellow camera label before accepting final imagery. No editor or track screenshot substitutes for a race scene.

Earlier 46fc491 records, source maps, tooling checks and capture review sheets remain untouched historical evidence. A source change requires new exact native/build/harness/capture records; do not relabel an older screenshot. The prepared compositor and four navy/yellow/orange/blue backgrounds remain unchanged.

## Historical preparation and tool instructions

This folder holds the iPad and Apple TV capture plan, draft composition manifest,
final native evidence and composed galleries. No final marketing gallery exists
until genuine captures from the frozen source have been supplied and reviewed.

`capture-plan.json` proposes twelve useful native states per platform, including
ten heroes and two extra support states. Its headlines are planned claims with
pending verification. The first three cover track building, car customization
and racing. Use the actual final UI to approve, shorten or replace each claim.

`manifest.draft.json` is deliberately incomplete. It has no native captures and
contains pending build and evidence values, so normal compositor validation
must fail. Do not use it as evidence of a gallery export. The final manifest
must reference actual native captures and files supporting every headline.

The read-only preparation and composition commands are documented in
[`tools/marketing-README.md`](../../../tools/marketing-README.md). The compositor
is [`tools/marketing-compose.swift`](../../../tools/marketing-compose.swift).

Apple's [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
were checked on 2026-10-03. Target output sizes are landscape 2752×2064 for iPad
13-inch and 1920×1080 for Apple TV. Each gallery will have ten opaque images.
The marketing work does not build or run iPhone, Mac or visionOS destinations.

Final checks still required:

- Final source revision and native build inputs match all capture proof.
- Both platforms pass their actual touch or Siri Remote workflows.
- Every image uses one to three captures from its own platform and device.
- Each headline has recorded evidence against the final build.
- Contact sheets and full-size outputs are visually reviewed.
- Uploaded App Store Connect galleries match the reviewed local exports.
