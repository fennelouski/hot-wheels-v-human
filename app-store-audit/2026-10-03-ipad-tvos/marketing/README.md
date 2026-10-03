# Marketing preparation

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
