# Features/ — SwiftUI screens (each folder = one feature, communicates only via AppModel + transport)

| Folder | Screen | Platform | Phase |
|---|---|---|---|
| `Home/` | Workshop menu (iPad) / Arena lobby (TV) | both | 0 (stub), 3 (lobby) |
| `Customizer/` | Car + driver design, split-screen 2P | iPad | 4 |
| `TrackBuilder/` | 2D drag-and-snap grid editor | iPad | 5 |
| `Dashboard/` | In-race controller (boost, garage, progress) | iPad | 3 |
| `Arena/` | RealityView race scene | TV + iPad (Solo Arena, Test Mode) | 1–2 |
| `ReactionCam/` | Driver PiP overlay | TV + iPad solo | 6 |

Conventions: one `<Feature>View.swift` entry per folder; view models are `@Observable` classes named `<Feature>Model`; previews use `LoopbackTransport` + fixture data so every screen previews without a network or second device.
