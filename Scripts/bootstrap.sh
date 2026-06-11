#!/usr/bin/env bash
# Regenerates the Xcode project (gitignored) and resolves package dependencies.
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen is required: brew install xcodegen" >&2
  exit 1
fi

xcodegen generate
echo "Generated PartyHouse.xcodeproj"

xcodebuild -resolvePackageDependencies -project PartyHouse.xcodeproj -scheme PartyHouse-iOS -quiet || true
echo "Done. Open PartyHouse.xcodeproj or build with xcodebuild."
