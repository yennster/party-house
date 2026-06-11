#!/usr/bin/env bash
# Pulls named screenshot attachments out of an .xcresult bundle.
# Usage: extract-screenshots.sh <result.xcresult> <output-dir>
set -euo pipefail

RESULT="$1"
OUT="$2"
mkdir -p "$OUT"

TMP=$(mktemp -d)
xcrun xcresulttool export attachments --path "$RESULT" --output-path "$TMP" >/dev/null

# The manifest maps exported file names back to the attachment names we set in
# the tests (01-home, 02-zone, ...).
python3 - "$TMP" "$OUT" <<'EOF'
import json, pathlib, re, shutil, sys

tmp, out = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
manifest_path = tmp / "manifest.json"
if not manifest_path.exists():
    sys.exit("No manifest.json in exported attachments — did the tests attach screenshots?")

manifest = json.loads(manifest_path.read_text())
count = 0
for test in manifest:
    for attachment in test.get("attachments", []):
        name = attachment.get("suggestedHumanReadableName") or attachment["exportedFileName"]
        source = tmp / attachment["exportedFileName"]
        if not source.exists():
            continue
        suffix = source.suffix or ".png"
        stem = pathlib.Path(name).stem
        # xcresulttool appends `_<n>_<UUID>` to attachment names — strip it.
        stem = re.sub(r"_\d+_[0-9A-Fa-f-]{36}$", "", stem)
        target = out / (stem + suffix)
        shutil.copy(source, target)
        print(f"  {target}")
        count += 1
print(f"{count} screenshot(s) extracted")
EOF

rm -rf "$TMP"
