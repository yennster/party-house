#!/usr/bin/env bash
# Generates Mac App Store screenshots from demo mode.
# The app pins its window to 1440x900 points under -ScreenshotMode, so Retina
# captures land on Apple's accepted 2880x1800 pixel size.
# Output: Screenshots/macos/*.png
set -euo pipefail
cd "$(dirname "$0")/.."

[ -d PartyHouse.xcodeproj ] || ./Scripts/bootstrap.sh

RESULT="build/screenshots-macos.xcresult"
rm -rf "$RESULT"

xcodebuild test \
  -project PartyHouse.xcodeproj \
  -scheme PartyHouse-macOS \
  -destination "platform=macOS" \
  -only-testing:PartyHouseUITests-macOS/MacScreenshotTests \
  -resultBundlePath "$RESULT" \
  -allowProvisioningUpdates \
  -quiet || { echo "❌ macOS screenshot test run failed"; exit 1; }

./Scripts/extract-screenshots.sh "$RESULT" "Screenshots/macos"

# Window captures come out a hair off the exact size (shadow/chrome insets), so
# normalize to the App Store's 2880x1800. The <1% scale is invisible.
for file in Screenshots/macos/*.png; do
  [ -e "$file" ] || continue
  sips -z 1800 2880 "$file" >/dev/null
  sips -g pixelWidth -g pixelHeight "$file" | awk -v f="$file" '/pixelWidth/{w=$2} /pixelHeight/{h=$2} END{printf "  %s — %sx%s\n", f, w, h}'
done

echo "✅ macOS screenshots in Screenshots/macos/"
