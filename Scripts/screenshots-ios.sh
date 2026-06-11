#!/usr/bin/env bash
# Generates iOS App Store screenshots from demo mode — no real lights needed.
# Output: Screenshots/ios/<device>/*.png
#
# Devices default to the App Store's required sizes (6.9" iPhone, 13" iPad).
# Override: Scripts/screenshots-ios.sh "iPhone 17 Pro" "iPad Pro 13-inch (M4)"
set -euo pipefail
cd "$(dirname "$0")/.."

DEVICES=("$@")
if [ ${#DEVICES[@]} -eq 0 ]; then
  DEVICES=("iPhone 17 Pro Max" "iPad Pro 13-inch (M4)")
fi

[ -d PartyHouse.xcodeproj ] || ./Scripts/bootstrap.sh

for DEVICE in "${DEVICES[@]}"; do
  if ! xcrun simctl list devices available | grep -q "$DEVICE ("; then
    echo "⚠️  Simulator '$DEVICE' not available — skipping. (xcrun simctl list devicetypes)"
    continue
  fi

  echo "▶ Capturing on $DEVICE"
  SLUG=$(echo "$DEVICE" | tr -cd '[:alnum:]' | tr '[:upper:]' '[:lower:]')
  RESULT="build/screenshots-ios-$SLUG.xcresult"
  rm -rf "$RESULT"

  xcrun simctl boot "$DEVICE" 2>/dev/null || true
  xcrun simctl bootstatus "$DEVICE" -b >/dev/null 2>&1 || true
  # Clean status bar for App Store shots.
  xcrun simctl status_bar "$DEVICE" override \
    --time "9:41" --batteryState charged --batteryLevel 100 \
    --cellularMode active --cellularBars 4 --wifiBars 3 2>/dev/null || true

  xcodebuild test \
    -project PartyHouse.xcodeproj \
    -scheme PartyHouse-iOS \
    -destination "platform=iOS Simulator,name=$DEVICE" \
    -only-testing:PartyHouseUITests-iOS/IOSScreenshotTests \
    -resultBundlePath "$RESULT" \
    CODE_SIGNING_ALLOWED=NO \
    -quiet || { echo "❌ test run failed on $DEVICE"; exit 1; }

  ./Scripts/extract-screenshots.sh "$RESULT" "Screenshots/ios/$SLUG"
  xcrun simctl status_bar "$DEVICE" clear 2>/dev/null || true
done

echo "✅ iOS screenshots in Screenshots/ios/"
