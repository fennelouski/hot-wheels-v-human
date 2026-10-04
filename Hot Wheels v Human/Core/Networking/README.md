# Core/Networking/ — transport layer (Loopback in Phase 2, Multipeer in Phase 3)

Files to create
- `GameTransport.swift` — protocol (see ARCHITECTURE.md): `events: AsyncStream<TransportEvent>`, `send(_:reliably:)`, `start(role:)`, `stop()`. `TransportEvent = .peerConnected(PlayerInfo) | .peerDropped | .message(GameMessage) | .stateChanged(TransportState)`.
- `LoopbackTransport.swift` — in-process host+player pair for Solo Arena, previews, and integration tests. Build this FIRST; all features develop against it.
- `MultipeerTransport.swift` — `MCSession` wrapper. Service type `hwvh-race` (must match Info.plist `NSBonjourServices`). TV/solo-host = `MCNearbyServiceAdvertiser`, iPad = `MCNearbyServiceBrowser` with auto-invite to first found host (v1: no pairing UI beyond a confirm sheet listing host name). JSON-encode `GameMessage` → `session.send(_:toPeers:with: .reliable/.unreliable)`.
- `MessageCodec.swift` — JSONEncoder/Decoder pair, single place for wire format; unreliable sends get a monotonic sequence number so stale `RaceSnapshot`s are dropped.
- `ReliabilityHelpers.swift` — token-dedupe set for boost retries (send ×3 @100 ms; host executes once).

Gotchas (hard-won, do not skip)
- Info.plist keys (`NSLocalNetworkUsageDescription`, `NSBonjourServices`) are mandatory — without them discovery silently fails.
- Multipeer between two Simulators is flaky; use LoopbackTransport for automated tests and a real device for network testing.
- Keep payloads < 10 KB for `.unreliable` (message-size limits); `RaceSnapshot` at 10 Hz is tiny — never stream per-frame transforms to iPads, they don't render the 3D scene.
- Reconnect: on `.notConnected`, browser restarts and re-`hello`s; host keeps race paused ≤5 s (RaceCoordinator owns that policy, not the transport).

Tests: LoopbackTransport full-flow (hello→blueprint→ready→snapshot); codec seq-number dropping; dedupe.

### Finished image handoff, 2026-10-04 candidate

The additive reliable messages are `requestRaceShare` and `raceShare(RaceSharePayload)`. Existing race messages keep their wire shapes. Old peers drop unknown share messages; both devices need updated apps to share the image. A result image is a single bounded payload, never unreliable telemetry. Decode rejects share-image envelopes above 3 MB while preserving existing large drawing/photo messages, images above 2 MB, invalid image metadata, excessive dimensions and nonfinite result statistics.

`RaceShareHandoff` opens a temporary host on the existing `hwvh-race` service only while standalone TV Share is presented. A dashboard can receive an image without inventing a car or race telemetry. Networked arenas reuse the coordinator's existing encrypted session. Closing a panel or dashboard cancels its stream consumer and releases the temporary host. Automated tests use actual codec/loopback messages; physical TV-to-iPad discovery and delivery remain a separate required check.
