# HWvH1.0(1) iPadOS and tvOS Release plan

Committed candidate: `260f864b143b16f49418e5b8f8d35a6a9849c6bf`. Version stays **1.0(1)**. All889 native inputs still match `7377115b02eb7fc59511deeb171f4ce00128b84a6c0f8c110b3247a2bd4de519` in recorded order; no production files changed.

**Queued only.** Root must explicitly allocate the serialized jobs2 slot and authorize upload execution. This preparation runs no xcodebuild, device, browser or deployment action.

The exact existing scheme is `Hot Wheels v Human`, proven by local scheme management and prior successful Release commands under the unchanged project. There is no checked-in shared xcscheme file; no configuration is added. The approved upload plist is copied byte-for-byte; the local export plist changes only destination to export. Both keep manageAppVersionAndBuildNumber=false and the same existing signing account/team.

Fresh immutable artifact root, not created yet: `/Users/nathan/CodexReleaseArtifacts/HWvH/2026-10-04-260f864b-1.0-1`. iPad uses generic iOS/family2 and TV uses generic tvOS/family3, minimumOS26.0. iPhone, Mac and Vision remain excluded.

For each platform, serialize archive → actual archive inspection → local App Store distribution export → actual distribution inspection → unchanged source/archive check → authorized upload. Exact subprocess argument arrays, output paths and logs are in the JSON. No shell interpolation or automatic version update is required.

Before upload, verify exact identity/version/family/arm64, actual signature and provisioning/profile entitlements, compiled privacy/local-network/camera/icon/model/audio resources, Release guards and actual encryption key. Empty source entitlements do not prove final signing capabilities. Development-signed archive is not mistaken for the separately verified distribution export. Preserve failures and compare Info.plist semantically if signing export reserializes it.

The source encryption key is present and false; no compiled archive exists for this commit yet. Report its actual compiled presence/value without legal answers or source changes.

Fresh root Apple records show **No Builds** and both1.0 platforms **Prepare for Submission**. Previous October3 packages are historical. Upload success will prove delivery only; root separately verifies processing, build selection, galleries, metadata and submission. Physical TV-to-iPad nearby handoff and actual haptic/audio hardware remain unverified.

No Git push, API key, new credentials/access, paid compute, source edit, runtime or web deployment belongs to this plan. Native releases are outside the AWS website migration policy.
