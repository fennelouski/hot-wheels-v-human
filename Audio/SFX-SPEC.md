# Sound Effects Spec — ElevenLabs generation

Every SFX the game needs, with a ready-to-paste ElevenLabs sound-generation prompt.
Generate all of them in one shot with `tools/generate_sfx.sh` (needs `ELEVENLABS_API_KEY`
exported or in `~/.env.local`). The script writes WAVs straight into
`Hot Wheels v Human/Resources/Audio/` at the filenames below — no manual steps.

Style north star (from CLAUDE.md): kid-first toy racing. Sounds are chunky, playful,
cartoonish — think toy garage, not Le Mans. Failures are funny, never harsh.
No screeching realism, nothing startling, nothing over ~3 s except loops.

## Core SFX (required by Phase 6)

| File | Len | ElevenLabs prompt |
|---|---|---|
| `car_engine_loop.wav` | 10 s | Small toy race car engine idle-to-rev loop, cartoonish putt-putt buzz, steady rhythm, seamless loop, no background noise |
| `speed_boost_fire.wav` | 1.5 s | Cartoon rocket boost whoosh with a playful rising zip, toy-like, punchy start, quick fade |
| `track_snap_connect.wav` | 0.6 s | Plastic toy track piece clicking firmly into place, satisfying chunky snap, single click |
| `car_crash_metal.wav` | 2 s | Comedic toy car crash, plastic parts clattering and bouncing on a wooden floor, springy boing undertone, funny not scary |
| `race_countdown.wav` | 3.5 s | Race start countdown: three short rising beeps then one long higher happy beep, arcade style, bright and clean |
| `finish_fanfare.wav` | 3 s | Short triumphant toy trumpet fanfare with party feel, cheerful arcade victory jingle |
| `respawn_pop.wav` | 0.8 s | Cartoon pop with a springy bounce, toy appearing back on track, light and bouncy |
| `ui_tap.wav` | 0.5 s | Soft rounded plastic button tap, friendly UI click, single note |

## Nice-to-have (generate in same batch, wire up if Phase 6 has slots)

| File | Len | ElevenLabs prompt |
|---|---|---|
| `checkpoint_ding.wav` | 0.7 s | Bright single xylophone ding, checkpoint collected, cheerful |
| `loop_whoosh.wav` | 1.2 s | Fast swirling whoosh of a toy car going around a vertical loop, doppler swoosh, playful |
| `crowd_kids_cheer.wav` | 2.5 s | Small group of kids cheering and laughing happily, short burst, warm and close |
| `boost_ready_chime.wav` | 1 s | Gentle two-note power-up chime, boost recharged, inviting |

## Full library — the "feel alive" pass (one sound per app moment)

### Customizer & Garage

| File | Len | ElevenLabs prompt |
|---|---|---|
| `paint_spray.wav` | 1 s | Spray paint can short burst with a little rattle shake first, playful, clean |
| `wrench_ratchet.wav` | 0.8 s | Quick toy socket wrench ratchet, three fast clicks, changing a part on a toy car |
| `tire_bounce.wav` | 0.8 s | Small rubber tire dropped and bouncing once on a table, rubbery boing |
| `garage_door.wav` | 1.5 s | Small toy garage door rolling up quickly with a light rattle and soft clunk stop |
| `car_select_vroom.wav` | 1 s | Short excited toy car engine rev, vroom-vroom, eager and cute |

### TrackBuilder

| File | Len | ElevenLabs prompt |
|---|---|---|
| `piece_delete_pop.wav` | 0.6 s | Reverse suction pop, toy piece plucked away, quick and comical |
| `shuffle_dice.wav` | 1 s | Handful of plastic dice shaken in cupped hands and rolled on a table, playful rummage |
| `track_save_stamp.wav` | 0.8 s | Big satisfying rubber stamp thump on paper with a little squeak, official and fun |
| `nope_wobble.wav` | 0.6 s | Friendly springy boing wobble, gentle cartoon nope, soft and silly not harsh |

### Lobby & navigation

| File | Len | ElevenLabs prompt |
|---|---|---|
| `player_join_horn.wav` | 1 s | Cheerful little party horn toot with a tiny confetti shake, someone arrived |
| `ready_bell.wav` | 0.7 s | Bright bicycle bell double ring, playful and eager |
| `screen_whoosh.wav` | 0.6 s | Soft quick air whoosh, page sliding, light and smooth |

### Race moments

| File | Len | ElevenLabs prompt |
|---|---|---|
| `lap_bell.wav` | 1 s | Boxing ring style bell single clear ding, final lap announcement, bright |
| `off_track_alarm.wav` | 1 s | Descending slide whistle, comical falling feeling, silly not scary |
| `stuck_wobble.wav` | 1.2 s | Toy car rocking back and forth stuck, rhythmic plastic creak wobble, comical struggle |
| `results_tally.wav` | 2 s | Quick ascending xylophone run with a final happy ding, scores adding up |
| `rematch_ding.wav` | 0.7 s | Game show bell ding with a sparkle, lets go again feeling |
| `camera_shutter.wav` | 0.5 s | Toy camera click with a small motorized winding, single snapshot |

### Driver reactions (ReactionCam)

| File | Len | ElevenLabs prompt |
|---|---|---|
| `driver_woohoo.wav` | 1.2 s | Cartoon character joyful woo-hoo exclamation, high pitched and gleeful, single voice |
| `driver_uh_oh.wav` | 1 s | Cartoon character worried uh-oh, cute and comical, single voice |
| `driver_giggle.wav` | 1.5 s | Cartoon character infectious little giggle fit, bubbly and warm, single voice |
| `driver_dizzy.wav` | 1.5 s | Cartoon dizzy warbling wah-wah-wah with little stars feeling, after a tumble, comical |

## Depth pass — variants & extra moments

**Variant convention:** high-frequency sounds get `_b`/`_c` siblings (base file = the "a").
Code should pick randomly among a base name's variants so nothing repeats back-to-back.

### UI & customization confirmations

| File | Len | ElevenLabs prompt |
|---|---|---|
| `ui_tap_b.wav` | 0.5 s | Soft rounded plastic button tap, slightly higher pitch, friendly UI click, single note |
| `ui_tap_c.wav` | 0.5 s | Soft rounded plastic button tap, slightly lower and shorter, friendly UI click |
| `ui_back.wav` | 0.5 s | Soft descending two-tone plastic tap, going back, gentle |
| `confirm_sparkle.wav` | 0.8 s | Small bright sparkle chime confirming a choice, magical but subtle, happy |
| `customize_confirm_pop.wav` | 0.6 s | Bubbly pop with a tiny bell, item equipped on a toy, satisfying |
| `paint_spray_b.wav` | 1 s | Two short spray paint bursts with can rattle between, playful |
| `wrench_ratchet_b.wav` | 0.8 s | Toy socket wrench ratchet, five quicker clicks ending with a snug squeak |

### Track assembly variants

| File | Len | ElevenLabs prompt |
|---|---|---|
| `track_snap_connect_b.wav` | 0.6 s | Plastic toy track piece clicking into place, slightly deeper chunk, single firm snap |
| `track_snap_connect_c.wav` | 0.6 s | Plastic toy track piece double-click settling into place, light and crisp |
| `piece_delete_pop_b.wav` | 0.6 s | Quick cork-pop pluck, toy piece removed, cheeky |

### Race start

| File | Len | ElevenLabs prompt |
|---|---|---|
| `start_gate_drop.wav` | 0.8 s | Plastic starting gate flap dropping with a springy clack, race begins |
| `grid_rev_anticipation.wav` | 2 s | Two small toy car engines revving eagerly in place, ready to launch, building excitement |

### Boost variants

| File | Len | ElevenLabs prompt |
|---|---|---|
| `speed_boost_fire_b.wav` | 1.5 s | Cartoon rocket boost with a sparkly crackle tail, playful zip upward |
| `speed_boost_fire_c.wav` | 1.5 s | Cartoon turbo whoosh with a wobbly warble, silly fast, quick fade |

### Cars racing around

| File | Len | ElevenLabs prompt |
|---|---|---|
| `engine_loop_light.wav` | 10 s | Tiny toy car engine loop, high buzzy happy hum like an excited bee, steady seamless loop |
| `engine_loop_heavy.wav` | 10 s | Chunky toy monster truck engine loop, low rumbly putt-putt growl, steady seamless loop |
| `skid_drift.wav` | 1 s | Short cartoon tire skid squeak on smooth plastic, playful drift, not harsh |
| `car_passby_whoosh.wav` | 0.8 s | Small toy car zooming past close by, quick doppler whoosh with tiny engine buzz |

### Finish line & results

| File | Len | ElevenLabs prompt |
|---|---|---|
| `finish_tape_snap.wav` | 0.8 s | Paper ribbon tape snapping as a winner bursts through, light flutter after |
| `crowd_gasp.wav` | 1 s | Small group of kids gasping in surprise, quick inhale, playful suspense |
| `crowd_ooh_wow.wav` | 1.2 s | Small group of kids going ooooh and wow amazed, warm and delighted |
| `nice_try_kazoo.wav` | 1.5 s | Gentle silly kazoo wah-wah, better luck next time, funny and warm, never mean |

### Crash / checkpoint / respawn variants

| File | Len | ElevenLabs prompt |
|---|---|---|
| `car_crash_metal_b.wav` | 2 s | Comedic toy car tumble, plastic pieces scattering with a spring sproing and a hubcap wobbling to rest |
| `car_crash_metal_c.wav` | 2 s | Comedic toy car bonk and bounce, single big plastic clonk then small parts raining down, funny |
| `checkpoint_ding_b.wav` | 0.7 s | Bright two-note xylophone ding-dong, checkpoint collected, cheerful |
| `respawn_pop_b.wav` | 0.8 s | Cartoon sproing appear with a tiny twinkle, toy back on track, bouncy |

## Character catchphrases (TTS, not SFX — exact words need text-to-speech)

Generated by `tools/generate_voices.sh` (same key). Robot racers from `AIRoster` in
`Core/RaceCore/AIBoostPolicy.swift`. Files land in `Resources/Audio/` as `voice_<bot>_<moment>.wav`.
Tone rules: funny not mean, losses are cheerful, no taunting that stings.

| File | Voice | Line |
|---|---|---|
| `voice_oobi_intro.wav` | Jessica | Beep boop! Oobi-Bot is ready to race! |
| `voice_oobi_win.wav` | Jessica | Yay! My wheels are so happy right now! |
| `voice_oobi_lose.wav` | Jessica | Aw, my bolts got wobbly. Good race, friend! |
| `voice_oobi_boost.wav` | Jessica | Wheee! Zoom zoom mode! |
| `voice_zapp_intro.wav` | Laura | Zap zap! Try to keep up, slowpokes! |
| `voice_zapp_win.wav` | Laura | Zzzap! Told ya I was fast! |
| `voice_zapp_lose.wav` | Laura | My circuits say... rematch! Rematch! |
| `voice_zapp_boost.wav` | Laura | Lightning time! |
| `voice_crusher_intro.wav` | Brian | I am Crusher. My wheels are very big. |
| `voice_crusher_win.wav` | Brian | Crusher wins! Big happy stomp! |
| `voice_crusher_lose.wav` | Brian | Hmm. Tiny car... big heart. Respect. |
| `voice_crusher_boost.wav` | Brian | Maximum rumble! |

## Music (NOT ElevenLabs SFX — 22 s API limit)

`workshop_ambience.m4a` and `race_intensity.m4a` still come from the sources in
`Audio/README.md` (Kevin MacLeod CC-BY / OGA CC0), or ElevenLabs Music via the web app.
Convert to AAC: `afconvert in.mp3 -d aac -f m4af out.m4a`.

## Regeneration & licensing

- Rerun `tools/generate_sfx.sh <name>` to regenerate one sound; no arg = all missing ones.
- ElevenLabs output is licensed per your ElevenLabs plan (commercial use on paid tiers) —
  log plan/date here when generated, same discipline as Graphics/.
- **Generated 2026-07-18**: all 34 SFX via ElevenLabs sound-generation API (account key from
  PictureGrid, saved in `~/.env.local`). 4.3 MB total, 44.1 kHz **mono** WAV — mono is
  deliberate: RealityKit spatial audio wants mono sources it can place in 3D.
- Keep total audio < 10 MB (WAV SFX at 44.1 kHz mono are ~90 KB/s — fine).
