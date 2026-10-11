#!/usr/bin/env python3
"""Hash normal HWvH files only; never print their contents or modify them."""
import datetime
import hashlib
import json
import pathlib
import plistlib
import subprocess
import sys

udid, output = sys.argv[1:]
bundle = "com.nathanfennel.Hot-Wheels-v-Human"
devices = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "--json"]))
device = next(item for items in devices["devices"].values() for item in items if item["udid"] == udid)
data = pathlib.Path(device["dataPath"])
files = []
containers = []
for folder in (data / "Containers/Data/Application").glob("*"):
    metadata = folder / ".com.apple.mobile_container_manager.metadata.plist"
    if not metadata.exists():
        continue
    try:
        identifier = plistlib.loads(metadata.read_bytes()).get("MCMMetadataIdentifier")
    except Exception:
        continue
    if identifier != bundle:
        continue
    containers.append(folder.name)
    candidates = [folder / "Library/Preferences" / (bundle + ".plist")]
    for normal in [folder / "Documents", folder / "Library/Application Support"]:
        candidates.extend(path for path in normal.rglob("*") if path.is_file())
    for path in sorted(set(candidates)):
        if path.is_file():
            files.append({"path": str(path.relative_to(data)), "bytes": path.stat().st_size,
                          "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
record = {"recordedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(), "udid": udid,
          "state": device["state"], "bundleID": bundle, "matchingContainers": containers,
          "normalFiles": files,
          "excluded": "private HWvH.QA UUID preference suites and tmp/HWvH-QA session storage"}
pathlib.Path(output).write_text(json.dumps(record, indent=2) + "\n")
print(json.dumps({"udid": udid, "state": device["state"], "normalFileCount": len(files)}))
