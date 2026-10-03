# Hot Wheels vs. Human

A toy-racing game for iPad + Apple TV, designed by a kid and built as a family project. Build tracks, cars and racers on either platform, then race them with real physics. The Siri Remote controls the TV workshop and local races. An iPad can also become the controller for a nearby Apple TV.

> The public release is named HWvH. The repository and bundle identifier keep their existing names. This is a family project with no affiliation to Mattel.

## How it plays

- **iPad = Workshop.** Build a car (chassis, tires, paint), draw a track (straights, curves, a loop), customize your driver.
- **Apple TV = Workshop and Arena.** Use the remote to build tracks, decorate worlds, paint cars, create racers, save designs and race on the big screen. Choose Race with iPad to host nearby players.
- **iPad during the race = Controller.** Tap to boost, watch your driver's reaction cam.
- Local Multipeer networking only. No accounts, no analytics, no ads — it's for kids.

## Project layout

| Path | What |
|---|---|
| `Documents/` | PRD, architecture, phased build plan (`BUILD-ORDER.md`) |
| `Hot Wheels v Human/` | The app — one multiplatform target (iPadOS 26 + tvOS 26), SwiftUI + RealityKit |
| `Graphics/3DModels/Source/` | Pristine CC0 asset packs (don't edit) |
| `tools/` | Headless-Blender GLB→USDZ conversion |

Every folder has a `README.md` saying what gets built there. Start with `CLAUDE.md` and `Documents/BUILD-ORDER.md`.

## Building

Xcode 26+. Open `Hot Wheels v Human.xcodeproj` and run on an iPad or Apple TV simulator, or from the CLI per `Documents/XCODE-SETUP.md` §8. No dependencies to install — zero SPM packages.

**Status:** every phase in `Documents/BUILD-ORDER.md` is built — P0–P7 plus the
C-series profile/character work — and the game is playable end to end: build a
car and a track on iPad or Apple TV, race locally or with nearby iPads, with
characters, worlds, tunnels, ghost pieces and a cockpit radio. What's left is
polish and hardware validation; the live list is `Documents/OPEN-THREADS.md`.

## Asset credits

- [Kenney](https://kenney.nl) Toy Car Kit & Car Kit (CC0)
- [Quaternius](https://quaternius.com) rigged human (CC0)
- OpenGameArt racetrack extras (CC0)
