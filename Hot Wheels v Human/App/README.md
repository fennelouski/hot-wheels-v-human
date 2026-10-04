# App routing and shared controls

`Hot_Wheels_v_HumanApp` installs the same local SwiftData schema on iPad and Apple TV. `AppModel` holds the selected player, racer, car and next track. Each platform opens the profile picker, then its workshop home.

The iPad home retains its picture tiles and touch layout. `TVWorkshopHome` offers Quick Play, Build a Car, Build a Track, Race a Robot, Garage, 2-Player Build, My Racers and Race with iPad. Local network hosting starts when Race with iPad opens, rather than blocking standalone TV play behind the lobby.

`TVWorkshopButtonStyle` distinguishes persistent selection, yellow, from remote focus, a white outline. Controls have a minimum 60-point target and honor Reduce Motion. `ChipRow` keeps its touch capsule presentation on iPad and uses the same focus treatment on TV.

The production display name is HWvH. Debug builds retain the development name. Existing launch arguments open individual workshops and race drills for native testing. They do not change the normal profile and home flow.

`AppModel.stampedRaceDesign(car:driver:)` stamps the current draft for race previews. Unsaved edits can be tested without losing the workshop when the preview closes.

The 2026-10-04 game-loop candidate adds a first-viewport Play action to the optional profile picker and Settings to the picker/workshop. `GamePreferences` persists independent animation and haptic choices. `GamePresentationPolicy` combines the app choice with the read-only Reduce Motion environment and updates the thread-safe decorative RealityKit policy. Physics does not use that policy.

`HWTestSession` is DEBUG-only isolation. A UUID launch argument selects a scratch SwiftData URL and preference suite, suppresses local-network discovery/advertising, sound and haptic output, and chooses existing deterministic starter content. The unit host displays an empty scene and uses memory-only data. Release launches always retain production behavior and cannot activate this fixture.
