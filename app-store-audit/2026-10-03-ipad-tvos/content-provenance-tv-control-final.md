# Bundled audio and model provenance

This read-only review covers the final `44d929c` iPad and TV archives. All 79 audio files and 368 models match the repository bytes in both signed apps. No assets were edited or regenerated. Exact filenames, hashes and source-file evidence are in [content-provenance-tv-control-final.json](content-provenance-tv-control-final.json).

| Content | Bundled files | Evidence | Release implication |
|---|---:|---|---|
| Original synthesized radio/music | 7 M4A | `Audio/README.md` dated music status, `tools/generate_placeholder_music.py`, `RadioStation.swift` | Original procedural synthesis. Earlier downloaded-music rows are fallback plans. |
| Generated sound effects | 60 WAV | All filenames have ElevenLabs prompts in `Audio/SFX-SPEC.md`; generation script | Generation provenance exists. Commercial subscription at generation remains unverified. |
| Generated robot catchphrases | 12 WAV | Exact authored lines, standard Jessica/Laura/Brian voices and TTS script | Same commercial-rights evidence gap. No voice-cloning implementation found in this generation path. |
| Converted models | 368 USDZ | `Graphics/README.md`, conversion scripts, 17 included CC0 license files | Third-party CC0 packs. Individual conversion history was not regenerated. |

Kenney's [Toy Car Kit](https://kenney.nl/assets/toy-car-kit) and [Mini Characters](https://kenney.nl/assets/mini-characters) pages explicitly list CC0. The author's [Fertile Soil racetrack](https://opengameart.org/content/modular-racetrack-3d-models) and [Quaternius human](https://opengameart.org/content/animated-human-low-poly) publications also list CC0. Local pack license files are hashed in the inventory. The [CC0 deed](https://creativecommons.org/publicdomain/zero/1.0/) permits commercial copying, modification and distribution. It does not grant trademark or publicity rights.

The missing evidence is the ElevenLabs subscription used when the 72 WAVs were generated. `SFX-SPEC.md` asks for a plan/date record but records only an older July 18 batch of 34 effects. That note cannot establish the generation dates or paid plan for the current full library. ElevenLabs' [published licensing conditions](https://help.elevenlabs.io/hc/en-us/articles/13313564601361-Can-I-publish-the-content-I-generate-on-the-platform) require a paid subscription at generation and exclude Beta services from commercial production use. A present API key or current subscription is insufficient evidence of those historical conditions.

The Higgsfield art specification has an empty generation log and no generated-art folder. It remains a candidate plan. The home tile script instead renders the actual CC0 models. `Graphics/README.md` also claims an About-screen credit, but the source search found no such screen; that claim is not used as evidence.

The written robot lines contain no explicit language or sexual content. The game depicts cartoon toy-car collisions and playful driver reactions. These observations help the release owner answer age fields; they do not constitute a full audio audition or an automatic age rating. App Store Connect fields were not changed by this review.
