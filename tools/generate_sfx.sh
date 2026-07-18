#!/bin/bash
# Generate the game's SFX via the ElevenLabs sound-generation API.
# Prompts are parsed from Audio/SFX-SPEC.md (single source of truth).
#
#   tools/generate_sfx.sh          # generate every .wav not yet present
#   tools/generate_sfx.sh ui_tap   # (re)generate one sound by name
#
# Needs ELEVENLABS_API_KEY exported, or ELEVENLABS_API_KEY=... in ~/.env.local.
set -euo pipefail
cd "$(dirname "$0")/.."

KEY="${ELEVENLABS_API_KEY:-$(grep -m1 '^ELEVENLABS_API_KEY=' ~/.env.local 2>/dev/null | cut -d= -f2-)}"
[ -n "$KEY" ] || { echo "No ELEVENLABS_API_KEY in env or ~/.env.local"; exit 1; }

OUT="Hot Wheels v Human/Resources/Audio"
ONLY="${1:-}"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Rows look like: | `name.wav` | 1.5 s | prompt text |
grep -E '^\| `[a-z_]+\.wav`' Audio/SFX-SPEC.md | while IFS='|' read -r _ file len prompt _; do
    name=$(echo "$file" | tr -d ' `' | sed 's/\.wav$//')
    secs=$(echo "$len" | tr -dc '0-9.')
    prompt=$(echo "$prompt" | sed 's/^ *//;s/ *$//')
    [ -n "$ONLY" ] && [ "$name" != "$ONLY" ] && continue
    [ -z "$ONLY" ] && [ -f "$OUT/$name.wav" ] && continue

    echo "generating $name (${secs}s): $prompt"
    code=$(curl -s -w '%{http_code}' -o "$TMP/$name.mp3" \
        -X POST https://api.elevenlabs.io/v1/sound-generation \
        -H "xi-api-key: $KEY" -H "Content-Type: application/json" \
        -d "{\"text\": \"$prompt\", \"duration_seconds\": $secs, \"prompt_influence\": 0.4}")
    if [ "$code" != 200 ]; then
        echo "FAIL $name (HTTP $code): $(head -c 300 "$TMP/$name.mp3")"
        continue
    fi
    afconvert "$TMP/$name.mp3" -d LEI16 -f WAVE -c 1 "$OUT/$name.wav"
    echo "wrote $OUT/$name.wav"
done
echo "done."
