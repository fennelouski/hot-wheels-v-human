# HWvH App Store draft

This copy is prepared locally and must match the final verified build. No
App Store Connect record, platform metadata, privacy label, contact field,
pricing or country setting has been saved by the project agent. The bundle
ID, scheme and existing release display name are preserved.

- Name: HWvH
- Subtitle: Build tracks. Race your way.
- Primary category: Games
- Proposed genres: Racing, Simulation
- Primary language: English U.S.
- Copyright draft: 2026 Nathan Fennel
- Price: Free in every eligible country, per the user's instruction
- Availability: Every country Apple permits, subject to actual account and
  regional release requirements
- Platforms: iPadOS and tvOS
- Privacy URL proposed: https://nathanfennel.com/hwvh/privacy.html
- Support URL proposed: https://nathanfennel.com/hwvh/support.html
- App ID and SKU: Inspect the existing App Store Connect record. Do not invent.

## Promotional text

Build a wild track, make a racer your own, and race on iPad or Apple TV. No accounts or ads. Your next great race starts in the workshop.

## Description

Build it. Race it. Try something wilder.

HWvH turns toy tracks and custom racers into a playground on iPad and Apple TV.

MAKE YOUR RACER
Pick a character, choose colors and style a car with chassis, tires, paint and patterns. Save your favorites for the next race.

BUILD YOUR TRACK
Mix straights, curves, hills, loops, jumps and portals. Pick a world, add decorations and try the track while you build.

RACE YOUR WAY
Race a computer opponent, run a test drive or set up local multiplayer with nearby iPads and Apple TV. Play standalone on either supported platform.

MADE FOR YOUR SCREEN
Use touch on iPad or focus and select with the Siri Remote on Apple TV. iPad also offers camera color picking and Apple Pencil drawing.

No accounts. No ads. No in-app purchases. Your saved library stays on your device. Local multiplayer needs nearby devices and local network access.

Requires iPadOS 26 or tvOS 26 or later. The app does not automatically sync saved libraries through iCloud.

## Keywords

track,racing,toy,car,loop,garage,creative,build,physics,local,multiplayer,driver,customize

## Review notes draft

The iPadOS binary supports only UIDeviceFamily 2. The tvOS binary supports
only UIDeviceFamily 3. Neither build is intended for iPhone, Mac or Vision.
The release display name is HWvH. The target and bundle retain their original
internal identifiers.

There is no login, purchase or online backend. Standalone building and racing
can be tested on either supported platform. On Apple TV, use Siri Remote
directional navigation and Select for editing; Menu returns to the previous
screen. For local multiplayer, open the TV lobby and join from an iPad with
Local Network permission. A real iPad/Apple TV pair is required to verify
hardware networking; simulator-to-simulator discovery is not reliable.

The optional iPad camera feature analyzes one image on-device for character
colors and does not save or transmit the original photo. Manual styling is
available without camera permission. Apple TV has no camera permission.

App Review phone and email come from the user's explicit instruction and
are in local, ignored `review-contact.private.json`. Nathan/Fennel is a draft
name until the release owner checks the actual contact controls. This file
has not been saved in App Store Connect.

## Submission gates

Inspect prior published device families. If this is an update to a published
universal build, Apple's device-family rule may prevent removing iPhone from
that record. Keep the requested iPad-only native configuration; do not create
a replacement app, delete a listing or invent hardware requirements without
an explicit release decision.

Confirm final native UI, persistence, camera fallback, local network denial,
real-device multiplayer, remote focus, race preview close/reopen and rematch.
Inspect both signed exports and source revision. Verify ten composed images
per platform after upload. Publish and verify the unlisted website routes
under the workspace deployment policy before saving them as store links.

The source manifest proposes Data Not Collected because the developer does
not receive the game library or local race traffic. It declares UserDefaults
CA92.1 and no tracking. The encryption flag is false because encryption is
provided by Apple's MCSession, with no app-owned encryption implementation.
The release owner must answer the actual privacy, age rating, rights,
export, trader and agreement controls truthfully. No attestations have been
completed by this project preparation.

Do not select the Kids category merely because the game is designed for
children. Review that category's actual controls and requirements first.
