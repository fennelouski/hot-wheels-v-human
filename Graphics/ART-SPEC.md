# Generated Art Spec — Higgsfield Soul

Environment/backdrop art the app needs, generated via the Higgsfield API
(`tools/generate_art.sh`, needs `HIGGSFIELD_API_KEY` in `~/.env.local` — value is
`id:secret`, sent as `Authorization: Key id:secret`). Output lands in
`Graphics/Generated/` (source folder, NOT bundled); crop/convert into
`Hot Wheels v Human/Resources/` per the Usage column when adopting one.

Style rules (every prompt inherits these — keep the suffix intact):
- Stylized soft 3D render, toy-box look. NEVER photoreal — it must sit behind
  low-poly Kenney cars without clashing.
- Soft warm lighting, gentle contrast, slightly desaturated background colors
  (the cars/track are the stars; backdrops recede).
- No text, no logos, no people, no recognizable brands.

Common prompt suffix: ", stylized soft 3D render, warm cozy lighting, muted
pastel background palette, low contrast, toy diorama aesthetic, no text, no people"

Variant convention: `_b`/`_c` rows are alternates of the same subject — generate all,
adopt the best, keep the rest as candidates.

| File | AR | Res | Usage | Prompt (suffix appended automatically) |
|---|---|---|---|---|
| `arena_bedroom_day` | 16:9 | 1080p | Arena backdrop — default room | A kid's bedroom seen from the floor at toy height, wooden floorboards in soft focus, a bed and bookshelf with plush toys in the blurry background, scattered building blocks, morning light through a window |
| `arena_bedroom_day_b` | 16:9 | 1080p | Arena backdrop variant | A sunny kid's bedroom from a toy car's point of view on the floor, striped rug, toy chest and teddy bear blurred in the background, warm morning glow |
| `arena_bedroom_night` | 16:9 | 1080p | Night race mode backdrop | A kid's bedroom at night from the floor, glowing star nightlight, moonlight through curtains, soft blue shadows, toys as silhouettes, cozy and magical not scary |
| `arena_bedroom_night_b` | 16:9 | 1080p | Night race variant | A dark cozy kid's bedroom at toy height, fairy lights strung over a bed, soft teal and purple glow, plush toys watching from the shadows, gentle dreamlike mood |
| `arena_playroom` | 16:9 | 1080p | Arena backdrop — playroom | A bright playroom from the floor at toy height, colorful foam mats, building block towers, a toy bin overflowing, crayon drawings pinned on the wall, cheerful daylight |
| `arena_playroom_b` | 16:9 | 1080p | Playroom variant | A playroom floor scene at toy car height, giant soft dice and stacking rings blurred behind, pastel wall with animal posters, scattered crayons |
| `arena_livingroom` | 16:9 | 1080p | Arena backdrop — living room | A cozy living room from the floor at toy height, sofa and coffee table towering above in soft focus, warm lamp light, a sleeping cat silhouette on the sofa |
| `arena_kitchen` | 16:9 | 1080p | Arena backdrop — kitchen floor | A kitchen floor from toy car height, checkered tiles, table and chair legs like a forest in soft focus, a fruit bowl glimpsed far above, bright clean daylight |
| `arena_backyard` | 16:9 | 1080p | Arena backdrop — outdoors | A backyard wooden deck at toy car height, potted plants like giant trees in soft focus, string lights, golden hour sunshine, grass beyond the deck edge |
| `arena_treehouse` | 16:9 | 1080p | Arena backdrop — special | Inside a kids treehouse at toy height, wooden plank walls, rope and bucket in a corner, leafy branches through the window, dappled warm sunlight |
| `workshop_garage` | 16:9 | 1080p | Customizer background | A cozy toy workshop wall at tabletop height, pegboard with tiny toy tools, shelves of paint pots and toy wheels, soft focus, warm lamp light |
| `workshop_garage_b` | 16:9 | 1080p | Customizer variant | A tiny toy garage interior at toy car height, rolling tool cabinet, tire stacks and paint cans on shelves, hanging cage lamp glow, soft focus |
| `garage_hall` | 16:9 | 1080p | GarageView background | A miniature toy car showroom at toy height, glossy floor with soft reflections, empty display pedestals, gentle spotlights, soft focus |
| `builder_desk` | 16:9 | 1080p | TrackBuilder background | A kids desk surface from above at a shallow angle, graph paper with pencil sketch lines, scattered orange track pieces at the edges, eraser and pencil stubs, bright desk lamp |
| `builder_desk_b` | 16:9 | 1080p | TrackBuilder variant | A carpet floor from directly above, faint chalk-style road doodles, a few orange toy track pieces waiting in a corner, soft even light |
| `lobby_tv` | 16:9 | 1080p | TV lobby background | A living room TV wall at dusk from low on the floor, warm glow, shelf of tiny toy car trophies beside the screen, cozy ambient light, soft focus |
| `results_confetti` | 16:9 | 1080p | Results screen background | A shower of paper confetti and streamers falling over a toy racetrack finish line, checkered flag blur, celebratory, bright and happy |
| `results_confetti_b` | 16:9 | 1080p | Results variant | Colorful balloons and confetti drifting across a soft-focus kids bedroom, party mood, gentle warm light |
| `testmode_lab` | 16:9 | 1080p | Test Mode background | A tiny toy science bench at toy car height, cardboard ramp with tape measure, stopwatch and clipboard, pencil marks on paper, curious workshop mood |
| `versus_split` | 16:9 | 1080p | 2P split-screen divider art | Two toy car garages side by side facing off, one warm orange lit and one cool blue lit, symmetrical composition, dramatic but friendly |
| `hero_loop` | 16:9 | 1080p | Home hero / marketing | A tiny toy car mid-loop on a giant orange vertical loop track in a kids bedroom, motion blur streaks, dynamic low angle, morning light |
| `hero_loop_b` | 16:9 | 1080p | Hero variant | An orange toy race track soaring over bedroom furniture like a rollercoaster, a tiny car catching air off a ramp, playful epic scale |
| `hero_boost` | 16:9 | 1080p | Boost feature art | Extreme close-up of a tiny toy race car with cartoon rocket flames from its exhaust, sparkles and speed lines, bedroom floor bokeh background |
| `topshelf_raceway` | 16:9 | 1080p | tvOS top shelf — crop center band to 2320×720 | A sweeping orange toy race track with a vertical loop crossing a kid's bedroom floor, tiny toy cars mid-race, checkered flag, dynamic wide angle, floor-level view |
| `topshelf_raceway_b` | 16:9 | 1080p | Top shelf variant | A panoramic toy race track winding across a bedroom floor between building blocks and plush toys, two tiny cars neck and neck, wide cinematic angle at floor level |
| `texture_wood_floor` | 1:1 | 1080p | Tiling floor texture (arena ground plane) | Seamless top-down wooden floorboard texture, warm honey tones, soft even light, subtle toy-scale wood grain |
| `texture_carpet` | 1:1 | 1080p | Tiling carpet texture (playroom ground) | Seamless top-down pale blue-gray carpet texture, soft fibers, even light, subtle weave |
| `texture_grass` | 1:1 | 1080p | Tiling texture (backyard ground) | Seamless top-down stylized short grass texture, soft green, even light, gentle cartoon look |
| `texture_corkboard` | 1:1 | 1080p | UI panel texture (builder/results cards) | Seamless corkboard texture with a few tiny pushpin holes, warm tan, soft even light |

Regeneration: `tools/generate_art.sh` (all missing) or `tools/generate_art.sh <name>`
(force one). ~1 credit (~$0.06) per 1080p image on the first-1000 promo, auto-refund
on failure. Log kept below.

## Generation log
- (none yet — account needs credits: cloud.higgsfield.ai → Billing)
