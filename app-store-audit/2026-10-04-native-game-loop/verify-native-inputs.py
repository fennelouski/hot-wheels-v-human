#!/usr/bin/env python3
"""Read-only hash guard for this bounded candidate; no build/device actions."""
import hashlib
import json
import pathlib
import sys

repository = pathlib.Path(__file__).resolve().parents[2]
proof_path = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else pathlib.Path(__file__).parent / "native-inputs.candidate-6.json"
proof = json.loads(proof_path.read_text())
changed = [item["path"] for item in proof["inputs"]
           if hashlib.sha256((repository / item["path"]).read_bytes()).hexdigest() != item["sha256"]]
print(json.dumps({"inputCount": proof["inputCount"], "aggregateSHA256": proof["aggregateSHA256"], "changed": changed}))
sys.exit(bool(changed))
