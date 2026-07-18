#!/bin/bash
# Generate AI-racer catchphrases via ElevenLabs TTS.
# Lines are parsed from the catchphrase table in Audio/SFX-SPEC.md.
#
#   tools/generate_voices.sh                    # every voice_*.wav not yet present
#   tools/generate_voices.sh voice_zapp_boost   # (re)generate one line
set -euo pipefail
cd "$(dirname "$0")/.."

KEY="${ELEVENLABS_API_KEY:-$(grep -m1 '^ELEVENLABS_API_KEY=' ~/.env.local 2>/dev/null | cut -d= -f2-)}"
[ -n "$KEY" ] || { echo "No ELEVENLABS_API_KEY in env or ~/.env.local"; exit 1; }

voice_id() {
    case "$1" in
        Jessica) echo cgSgspJ2msm6clMCkdW9 ;;   # playful, bright — Oobi-Bot
        Laura)   echo FGY2WhTYpPnrIDTdsKH5 ;;   # quirky, energetic — Zapp
        Brian)   echo nPczCjzI2devNBz1zQrb ;;   # deep, resonant — Crusher
        *) echo "unknown voice $1" >&2; return 1 ;;
    esac
}

OUT="Hot Wheels v Human/Resources/Audio"
ONLY="${1:-}"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Rows look like: | `voice_oobi_intro.wav` | Jessica | Beep boop! ... |
grep -E '^\| `voice_[a-z_]+\.wav`' Audio/SFX-SPEC.md | while IFS='|' read -r _ file voice line _; do
    name=$(echo "$file" | tr -d ' `' | sed 's/\.wav$//')
    voice=$(echo "$voice" | tr -d ' ')
    line=$(echo "$line" | sed 's/^ *//;s/ *$//')
    [ -n "$ONLY" ] && [ "$name" != "$ONLY" ] && continue
    [ -z "$ONLY" ] && [ -f "$OUT/$name.wav" ] && continue

    echo "speaking $name ($voice): $line"
    code=$(curl -s -w '%{http_code}' -o "$TMP/$name.mp3" \
        -X POST "https://api.elevenlabs.io/v1/text-to-speech/$(voice_id "$voice")" \
        -H "xi-api-key: $KEY" -H "Content-Type: application/json" \
        -d "{\"text\": \"$line\", \"model_id\": \"eleven_multilingual_v2\"}")
    if [ "$code" != 200 ]; then
        echo "FAIL $name (HTTP $code): $(head -c 300 "$TMP/$name.mp3")"
        continue
    fi
    afconvert "$TMP/$name.mp3" -d LEI16 -f WAVE -c 1 "$OUT/$name.wav"
    echo "wrote $OUT/$name.wav"
done
echo "done."
