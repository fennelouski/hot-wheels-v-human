#!/bin/bash
# Generate backdrop art via the Higgsfield Soul API.
# Prompts parsed from Graphics/ART-SPEC.md (single source of truth).
#
#   tools/generate_art.sh          # every image not yet in Graphics/Generated/
#   tools/generate_art.sh <name>   # (re)generate one
#
# Needs HIGGSFIELD_API_KEY ("id:secret") in env or ~/.env.local.
set -euo pipefail
cd "$(dirname "$0")/.."

KEY="${HIGGSFIELD_API_KEY:-$(grep -m1 '^HIGGSFIELD_API_KEY=' ~/.env.local 2>/dev/null | cut -d= -f2-)}"
[ -n "$KEY" ] || { echo "No HIGGSFIELD_API_KEY in env or ~/.env.local"; exit 1; }

BASE=https://platform.higgsfield.ai
MODEL=higgsfield-ai/soul/standard
OUT=Graphics/Generated
SUFFIX=", stylized soft 3D render, warm cozy lighting, muted pastel background palette, low contrast, toy diorama aesthetic, no text, no people"
ONLY="${1:-}"
mkdir -p "$OUT"

# Rows: | `name` | 16:9 | 1080p | usage | prompt |
grep -E '^\| `[a-z_]+` \|' Graphics/ART-SPEC.md | while IFS='|' read -r _ file ar res _usage prompt _; do
    name=$(echo "$file" | tr -d ' `')
    ar=$(echo "$ar" | tr -d ' ')
    res=$(echo "$res" | tr -d ' ')
    prompt=$(echo "$prompt" | sed 's/^ *//;s/ *$//')
    [ -n "$ONLY" ] && [ "$name" != "$ONLY" ] && continue
    [ -z "$ONLY" ] && ls "$OUT/$name".* >/dev/null 2>&1 && continue

    echo "submitting $name ($ar $res)"
    body=$(python3 -c "import json,sys; print(json.dumps({'prompt': sys.argv[1] + sys.argv[2], 'aspect_ratio': sys.argv[3], 'resolution': sys.argv[4]}))" \
        "$prompt" "$SUFFIX" "$ar" "$res")
    resp=$(curl -s -X POST "$BASE/$MODEL" \
        -H "Authorization: Key $KEY" -H "Content-Type: application/json" \
        -H "Accept: application/json" -d "$body")
    request_id=$(echo "$resp" | python3 -c "import json,sys; print(json.load(sys.stdin).get('request_id',''))" 2>/dev/null || true)
    [ -n "$request_id" ] || { echo "FAIL $name — no request_id in: $(echo "$resp" | head -c 300)"; continue; }

    # Poll up to 5 min.
    for _ in $(seq 60); do
        sleep 5
        status_json=$(curl -s -H "Authorization: Key $KEY" "$BASE/requests/$request_id/status")
        status=$(echo "$status_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('status',''))" 2>/dev/null || echo parse_error)
        case "$status" in
            completed|COMPLETED|succeeded)
                # Grab the first image URL anywhere in the payload.
                url=$(echo "$status_json" | python3 -c "
import json, re, sys
urls = re.findall(r'https://[^\"\\s]+\.(?:png|jpe?g|webp)[^\"\\s]*', json.dumps(json.load(sys.stdin)))
print(urls[0] if urls else '')")
                if [ -n "$url" ]; then
                    ext="${url##*.}"; ext="${ext%%\?*}"
                    curl -s -o "$OUT/$name.$ext" "$url"
                    echo "wrote $OUT/$name.$ext"
                else
                    echo "FAIL $name — completed but no image URL: $(echo "$status_json" | head -c 300)"
                fi
                break ;;
            failed|error|nsfw|moderated)
                echo "FAIL $name — status $status: $(echo "$status_json" | head -c 300)"; break ;;
            *) ;;  # queued / in_progress — keep polling
        esac
    done
done
echo "done."
