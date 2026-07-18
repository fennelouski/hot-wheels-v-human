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

| File | AR | Res | Usage | Prompt (suffix appended automatically) |
|---|---|---|---|---|
| `arena_backdrop_bedroom` | 16:9 | 1080p | Arena background plane behind the track (TV + Solo Arena) | A kid's bedroom seen from the floor at toy height, wooden floorboards in soft focus, a bed and bookshelf with plush toys in the blurry background, scattered building blocks, morning light through a window |
| `workshop_backdrop_garage` | 16:9 | 1080p | Customizer/workshop screen background (blur further in code) | A cozy toy workshop wall at tabletop height, pegboard with tiny toy tools, shelves of paint pots and toy wheels, soft focus, warm lamp light |
| `topshelf_raceway` | 16:9 | 1080p | tvOS top shelf — crop center band to 2320×720 (`sips -c 720 2320`) | A sweeping orange toy race track with a vertical loop crossing a kid's bedroom floor, tiny toy cars mid-race, checkered flag, dynamic wide angle, floor-level view |

Regeneration: `tools/generate_art.sh` (all missing) or `tools/generate_art.sh <name>`
(force one). ~1 credit (~$0.06) per 1080p image on the first-1000 promo, auto-refund
on failure. Log kept below.

## Generation log
- (none yet — account needs credits: cloud.higgsfield.ai → Billing)
