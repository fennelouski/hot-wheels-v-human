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
  no tracking and no developer data collection. This is source-level evidence;
  the App Store privacy label has not been published.
- Existing iPad 1024 icon and TV layered icons and top shelf assets are present.
  The iPad icon's unused alpha channel was removed without changing any
  rendered pixel. Signed export icon inspection remains pending.

`resolved-build-settings.json` records twelve unique target/configuration/SDK
combinations from read-only `xcodebuild -showBuildSettings`. It is not a build
or runtime test result. `icon-inventory.json` and
`icon-opacity-verification.json` record exact source assets.

## Runtime work and release gates

`release-checklist.json` separates verified settings from pending integrated
builds, actual iPad and Siri Remote checks, signed exports and store work. The
lifecycle patch owns and cancels coordinator tasks and session countdowns;
its separate regression tests still need the release owner's integrated run.
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
was no browser visual check, push or deployment. The new `/hwvh/` routes
remain unverified on live hosts.

The existing verified deployment command is
`npm exec --yes --package=node@22 -- python3 scripts/deploy-app-privacy.py`.
The explicit PAGES allowlist now includes both HWvH and How to Adult in
nathanfennel.com revision `5c00d3f8`. The local check verified 76 pages and
the migration cutoff guard. Actual same-revision AWS/Vercel deployment is pending. This project agent read the command but did not run it,
refresh credentials, change routing or add background jobs. Evidence is in
`website-preparation.json`.

## App Review contact

Exact user-provided phone and email are kept in local, ignored
`review-contact.private.json`, with provenance and a draft name. They are
for Apple review and have not been saved in App Store Connect. Do not publish
that private file, reuse the phone as public support contact or infer that
metadata, pricing, country availability or submission is complete.
