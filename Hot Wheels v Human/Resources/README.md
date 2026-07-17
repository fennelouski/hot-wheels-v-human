# Resources/ — app-bundled assets (auto-included: this folder is inside the synced target folder)

- `Models3D/` — converted USDZ files only. Naming = source model name (`track-wide-straight.usdz`). Load with `Entity(named: "track-wide-straight", in: .main)`. Source GLBs live in `/Graphics` (not bundled). Phase 0: 3 pilot files; Phase 1: full track set + 9 chassis + wheels + debris; Phase 6: driver avatar + pose clips.
- `Audio/` — WAV SFX + m4a music per `/Audio/README.md`. Keep total < 10 MB.

Rules: nothing lands here without (a) an entry in the source folder's README with URL + license, and (b) passing Quick Look (USDZ) or playback (audio). Never edit files here by hand — re-run the conversion from `/Graphics` sources.
