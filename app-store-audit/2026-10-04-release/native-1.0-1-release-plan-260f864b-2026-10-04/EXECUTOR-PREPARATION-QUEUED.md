# Allocation-gated HWvH release executor

The exact approved1.0(1) iPadOS/tvOS release plan is queued. HowToAdult currently owns the serialized slot. No Xcode command has run for this plan.

`execute-verified-release.py` defaults to read-only preflight, which passed for commit260f864b, all889 frozen inputs, recorded-order737711… aggregate, exact40 committed blobs and an empty index. Syntax was checked with Python ast.parse. Audit-only files were written.

Every executing stage requires a fresh receipt written only after direct root allocation. The NOT-ACTIVE template deliberately has serializedSlotAllocated=false and is rejected. The executor checks current host xcodebuild ownership and holds an exclusive lock through each stage. It runs one operation/platform at a time using the unchanged plan's exact subprocess argv. No shell interpolation is used.

After allocation, execute serially: iPad archive, iPad local-export, iPad upload; then TV archive, TV local-export, TV upload. Each stage verifies source before/after, preserves original command logs and actual return code, and writes a unique attempt receipt. Upload additionally requires successful immutable archive/distribution checks. A failed stage stops; existing outputs are never overwritten or silently retried.

The verifier distinguishes actual archive provisioning from App Store distribution provisioning, compares signed entitlements with the actual profile, inspects actual encryption/local-network/camera/privacy/platform/version settings, and fingerprints full archive/bundle contents. It compares copied audio/models byte-for-byte. Xcode-optimized PNGs use frozen source hashes, actual CopyPNGFile mappings and dimensions; this does not claim a separate pixel review. Archive and export resource bytes must match, while a semantically equal full Info.plist may be reserialized during signing. Native asset icons/top shelf are inspected from Assets.car.

The executor does not edit production, bump versions, grant permissions, generate/read API keys, operate a device/browser, push or deploy websites. Upload delivery will still require fresh root Apple processing/build-selection/gallery/submission checks. Paired physical nearby handoff remains unverified.
