# iPad and Apple TV release preparation

The October 3 request limits HWvH to iPad and Apple TV and requires a full TV
workshop with Siri Remote controls. Existing source, identity and artwork are
preserved. iPhone, Mac, Catalyst and Vision destinations are excluded. No
visionOS build, boot, run, capture, upload or submission is permitted.

## Verified project preparation

- Debug and Release app, unit-test and UI-test settings resolve family 2 on
  iOS SDKs and family 3 on tvOS SDKs. Both minimum versions remain 26.0.
- Supported SDKs are iphoneos, iphonesimulator, appletvos and appletvsimulator.
  Designed for iPad on Mac and Vision, and Catalyst, are disabled.
- Existing touch UI tests are iOS-only. TV remote tests are separate.
- The camera permission text is iPad-only. The local network purpose names
  nearby iPads and Apple TVs. Multipeer service `hwvh-race` is unchanged.
- The privacy manifest declares the app's own UserDefaults use under CA92.1,
  no tracking and no developer data collection. The same manifest was verified
  inside both historical signed exports;
  the App Store privacy label has not been published.
- Existing iPad 1024 icon and TV layered icons and top shelf assets are present.
  The iPad icon's unused alpha channel was removed without changing any
  rendered pixel. Historical signed exports contain the opaque 1024-pixel iPad
  icon and TV layered runtime/marketing icons with all top shelf sizes.

`resolved-build-settings.json` records twelve unique target/configuration/SDK
combinations from read-only `xcodebuild -showBuildSettings`. It is not a build
or runtime test result. `icon-inventory.json` and
`icon-opacity-verification.json` record exact source assets.

## Historical build and package evidence

Production archive freeze `9b128e92539c0475033b00222731bfef865ef6b6` is bound to
863 native inputs by `native-source-inputs.json`. Its canonical SHA-256 is
`f653b283ce0f950df0e5124a6c964367888c2b0578e5fb7fdcb55141c07e7835`.
`native-builds.json` records successful Release iPad and TV Simulator builds
with a test-host-only testability override. Signed archives use the production
default, with testability disabled.

`signed-release-packages.json` records successful Release archives and actual
App Store distribution-signed IPA exports for iPad family `[2]` and TV family
`[3]`. The IPA signatures, existing team/bundle, App Store provisioning profiles
and `get-task-allow=false` were inspected, as were HWvH 1.0 (1), minimum OS 26,
arm64 binaries, compiled icons, bundled privacy manifest and encryption=false.
The first exports lacked profiles; a scoped, authorized automatic-provisioning
retry using the existing Xcode account succeeded. Archive source hashes and
archive-content digests stayed unchanged during those operations. Packages,
raw logs and distribution records remain outside Git under
`/tmp/hwvh-signed-release-20261003-92xr0ab0`. Neither IPA was uploaded.

Those exports are historical candidates. TV remote case04 subsequently found
that Left/Down can move focus off the placement cursor. The release owner
applied a tvOS-only fix disabling the header, scene and footer while moving
the cursor; its targeted runtime confirmation remains pending. The old TV
export is superseded. The existing iPad binary is unaffected by that guarded
change, but both candidates need a new global source proof before release.
`native-builds.json/currentWorkingTreeDelta` separately records the later
TV UI-test query/focus helper changes and the tvOS production source delta.
Do not describe the current whole working tree as matching the old manifest.

## Runtime work and release gates

`release-checklist.json` separates verified historical builds and exports from
pending actual iPad/Siri Remote checks, replacement TV packaging and store
work. `tv-model-test-summary.json` and `tv-model-test-details.json` record 14
passed model tests, including the lifecycle cancellation/countdown checks.
The iPad console log `/tmp/hwvh-ipad-models-20261003.log` reports 16 tests in
four suites passed and `TEST EXECUTE SUCCEEDED`. It also says result-summary
writing failed with `mkstemp: No space left on device`; the extracted summary
therefore shows `unknown` and zero tests. Its status is explicitly
`console-pass/result-summary-incomplete` in `native-builds.json` and the
checklist. This is a console pass with incomplete structured-result evidence,
not a normal complete xcresult proof or an unknown test failure.

The lifecycle patch owns and cancels coordinator tasks and session countdowns.
A preview closed during model loading must not attach content later. Closing
during countdown must not start a hidden race. Rematches keep their existing
building transition.

Public Apple lookup returned no listing for the exact bundle ID in the U.S.,
Netherlands and U.K. `public-store-lookup.json` records the requests. This does
not establish the state of an authenticated App Store Connect draft, TestFlight
build, previously removed listing or another storefront.

Apple's archived [QA1623](https://developer.apple.com/library/archive/qa/qa1623/_index.html)
says an ordinary update cannot remove a previously supported device family.
Before upload, inspect this app's actual store history. If a published build
supported iPhone, keep the iPad-only source prepared and resolve that store
constraint with the owner and Apple. Do not invent a capability requirement,
rename the bundle or delete the old app to bypass validation.

Ten composed marketing images are required for each supported gallery, using
actual pixels from the frozen submitted build. Apple's current
[screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)
accept landscape 2752×2064 for 13-inch iPad and 1920×1080 or 3840×2160 for Apple
TV. The gallery may contain one to ten images; this user's standard is ten.

The website copy is prepared in `privacy-policy-draft.md` and
`support-page-draft.md`. Standalone `public/hwvh/privacy.html` and
`public/hwvh/support.html` are committed in nathanfennel.com revision
`b5a6148f09666b133b6d90155739731832671365`. Only those two files were committed;
the other chat's untracked `.impeccable/` files are preserved. Source/static
checks passed and the existing public contact route returned HTTP 200. There
is now local browser evidence in `website-qa/browser-checks.json`: both pages
retain their unlisted robots directive and have no overflow at 320 and 1280
pixels. The public pages were subsequently published and verified on both
hosts from committed main `5c00d3f8ddbc48fa62f8504c527128a0ae8fa75b`.
Canonical `https://nathanfennel.com/hwvh/privacy.html` and
`https://nathanfennel.com/hwvh/support.html` return matching HTML, as do the AWS
copies under `https://nfbucketforstuff.s3.us-west-2.amazonaws.com/app-support/`.

The existing verified deployment command is
`npm exec --yes --package=node@22 -- python3 scripts/deploy-app-privacy.py`.
The explicit PAGES allowlist now includes both HWvH and How to Adult in
nathanfennel.com revision `5c00d3f8`. The local check verified 76 pages and
the migration cutoff guard. The authorized command then verified all 76
documents on both hosts. Protected production settings prevented local Vercel
packaging, so its existing Git-build fallback deployed the same committed SHA.
The READY deployment is
`https://nathanfennel-4fkazzv6r-nathan-fennels-projects.vercel.app`, with matching
Git metadata. Evidence is in `website-preparation.json` and the site's
`docs/app-policy-pages-deployment-2026-10-03.json`. Existing credentials were
used; no login, production routing, cutover or job ownership change occurred.
The dynamic website's AWS migration remains pending.

## App Review contact

Exact user-provided phone and email are kept in local, ignored
`review-contact.private.json`, with provenance and a draft name. They are
for Apple review and have not been saved in App Store Connect. Do not publish
that private file, reuse the phone as public support contact or infer that
metadata, pricing, country availability or submission is complete.
