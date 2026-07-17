# Hot Wheels vs. Human

A toy-racing game for iPad + Apple TV, designed by a kid and built as a family project. You build tracks and cars on the iPad, race them with real physics on the TV, and the iPad becomes your boost button and reaction cam.

> "Hot Wheels vs. Human" is a working title (see PRD §1.1 — a rename is planned before any public release). This is a hobby project with no affiliation to Mattel.

## How it plays

- **iPad = Workshop.** Build a car (chassis, tires, paint), draw a track (straights, curves, a loop), customize your driver.
- **Apple TV = Arena.** The track assembles on the big screen and the race runs there with physics — heavy cars clear the loop, light ones get flung.
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

**Status:** Phase 0 complete — builds and runs on both platforms with a spinning pilot car. Next up: core models + track kit (Phase 1).

## Asset credits

- [Kenney](https://kenney.nl) Toy Car Kit & Car Kit (CC0)
- [Quaternius](https://quaternius.com) rigged human (CC0)
- OpenGameArt racetrack extras (CC0)
