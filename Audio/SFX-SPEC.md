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
