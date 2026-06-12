#!/usr/bin/env bash
# Builds framed marketing screenshots with fastlane frameit for iPhone, iPad, and
# Mac, then refreshes the README showcase images in Docs/marketing/.
#
#   Scripts/marketing-screenshots.sh             # frame existing Screenshots/ output
#   Scripts/marketing-screenshots.sh --capture   # re-capture from demo mode first
#
# Raw input:  Screenshots/ios/<device-slug>/*.png + Screenshots/macos/*.png
# Framed out: Marketing/framed/{iphone,ipad,mac}/*.png   (gitignored)
# Showcase:   Docs/marketing/*.png                       (committed, used by README)
set -euo pipefail
cd "$(dirname "$0")/.."

# fastlane (and its UTF-16 title.strings parsing) requires a UTF-8 locale.
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

IPHONE_DEVICE="${IPHONE_DEVICE:-iPhone 17 Pro}"
IPAD_DEVICE="${IPAD_DEVICE:-iPad Pro 13-inch (M5)}"

if [ "${1:-}" = "--capture" ]; then
  ./Scripts/screenshots-ios.sh "$IPHONE_DEVICE" "$IPAD_DEVICE"
  ./Scripts/screenshots-macos.sh
fi

slug() { echo "$1" | tr -cd '[:alnum:]' | tr '[:upper:]' '[:lower:]'; }
IPHONE_SLUG=$(slug "$IPHONE_DEVICE")
IPAD_SLUG=$(slug "$IPAD_DEVICE")

[ -d "Screenshots/ios/$IPHONE_SLUG" ] || { echo "No raw iPhone shots — run with --capture"; exit 1; }

# Shared background for frameit.
[ -f Marketing/background.png ] || swift Scripts/generate-marketing-bg.swift

# Stage one frameit working dir per device class. frameit frames every PNG in the
# directory; titles come from title.strings (must be UTF-16).
stage() { # stage <source-dir> <work-dir> [WxH resize for frameit compatibility]
  local source="$1" work="$2" resize="${3:-}"
  rm -rf "$work"
  mkdir -p "$work"
  cp "$source"/*.png "$work/" 2>/dev/null || { echo "  (no shots in $source — skipped)"; return 1; }
  if [ -n "$resize" ]; then
    for f in "$work"/*.png; do
      sips -z "${resize#*x}" "${resize%x*}" "$f" >/dev/null
    done
  fi
  cp Marketing/Framefile.json "$work/Framefile.json"
  mkdir -p "$work/fonts"
  cp "/System/Library/Fonts/Supplemental/Arial Bold.ttf" "$work/fonts/Title.ttf"
  iconv -f UTF-8 -t UTF-16 Marketing/titles.txt > "$work/title.strings"
}

title_for() { # title_for <shot-name>
  sed -n "s/^\"$1\" = \"\(.*\)\";\$/\1/p" Marketing/titles.txt | head -1
}

# Fallback compositor for devices frameit can't frame (e.g. Mac windows): puts the
# shot on the marketing background with rounded corners and a title, via ImageMagick
# (already required by frameit).
manual_frame() { # manual_frame <work-dir> <label>
  local work="$1" label="$2"
  command -v magick >/dev/null || { echo "  ⚠️  ImageMagick missing — leaving $label raw"; return 0; }
  echo "  composing $label manually (no frameit frame for this size)"
  for f in "$work"/*.png; do
    local name
    name=$(basename "$f" .png)
    case "$name" in *_framed) continue ;; esac
    local title
    title=$(title_for "$name")
    # 2880x1800 is an accepted Mac App Store size, so framed Mac marketing
    # images can be uploaded directly by deliver.
    local W=2880 H=1800
    # Rounded corners on the shot.
    magick "$f" \
      \( +clone -alpha extract \
         -draw 'fill black polygon 0,0 0,48 48,0 fill white circle 48,48 48,0' \
         \( +clone -flip \) -compose Multiply -composite \
         \( +clone -flop \) -compose Multiply -composite \
      \) -alpha off -compose CopyOpacity -composite "$work/.rounded.png"
    magick Marketing/background.png -resize "${W}x${H}^" -gravity center -extent "${W}x${H}" \
      \( "$work/.rounded.png" -resize $((W - 600))x \) \
      -gravity south -geometry +0+80 -composite \
      \( -background none -fill white -font "$work/fonts/Title.ttf" \
         -size "$((W - 700))x150" -gravity center caption:"$title" \) \
      -gravity north -geometry +0+62 -composite \
      "$work/${name}_framed.png"
  done
  rm -f "$work/.rounded.png"
  echo "  ✅ $(ls "$work"/*_framed.png 2>/dev/null | wc -l | xargs) composed"
}

frame() { # frame <work-dir> <label> [title-pointsize] [title-y-offset]
  local work="$1" label="$2" pointsize="${3:-0}" offset="${4:-0}"
  echo "▶ Framing $label"
  if (cd "$work" && fastlane frameit >/dev/null 2>frameit.log); then
    # frameit writes *_framed.png next to the originals.
    local count
    count=$(ls "$work"/*_framed.png 2>/dev/null | wc -l | xargs)
    if [ "$count" = "0" ]; then
      echo "  ⚠️  frameit produced no output for $label (no frame for this device size?) — using raw shots"
      return 1
    fi
    [ "$pointsize" != "0" ] && add_titles "$work" "$pointsize" "$offset"
    echo "  ✅ $count framed"
  else
    echo "  ⚠️  frameit failed for $label (see $work/frameit.log) — using raw shots"
    return 1
  fi
}

# frameit clamps its own title size, so its titles are rendered invisible
# (Framefile color #FFFFFF00) and the real ones are drawn here at full control.
add_titles() { # add_titles <work-dir> <box-height> <y-offset>
  local work="$1" boxheight="$2" offset="$3"
  command -v magick >/dev/null || { echo "  ⚠️  ImageMagick missing — titles skipped"; return 0; }
  for f in "$work"/*_framed.png; do
    [ -e "$f" ] || continue
    local name title width boxwidth
    name=$(basename "$f" _framed.png)
    title=$(title_for "$name")
    [ -n "$title" ] || continue
    width=$(sips -g pixelWidth "$f" | awk '/pixelWidth/{print $2}')
    boxwidth=$((width * 88 / 100))
    # caption: auto-fits the text to the box — long titles shrink, short titles max out.
    magick "$f" \
      \( -background none -fill white -font "$work/fonts/Title.ttf" \
         -size "${boxwidth}x${boxheight}" -gravity center caption:"$title" \) \
      -gravity north -geometry +0+"$offset" -composite \
      "$f"
  done
}

mkdir -p Marketing/framed
if stage "Screenshots/ios/$IPHONE_SLUG" "Marketing/framed/iphone"; then
  frame "Marketing/framed/iphone" "iPhone" 150 90 || manual_frame "Marketing/framed/iphone" "iPhone"
fi
if [ -d "Screenshots/ios/$IPAD_SLUG" ]; then
  # frameit doesn't know the 13" M5 panel (2064x2752); the 12.9" size (2048x2732)
  # has the same aspect ratio and a frame.
  if stage "Screenshots/ios/$IPAD_SLUG" "Marketing/framed/ipad" "2048x2732"; then
    frame "Marketing/framed/ipad" "iPad" 170 100 || manual_frame "Marketing/framed/ipad" "iPad"
  fi
else
  echo "⚠️  No iPad shots at Screenshots/ios/$IPAD_SLUG — run with --capture to include iPad"
fi
if [ -d "Screenshots/macos" ]; then
  if stage "Screenshots/macos" "Marketing/framed/mac"; then
    frame "Marketing/framed/mac" "Mac" || manual_frame "Marketing/framed/mac" "Mac"
  fi
fi

# Refresh the README showcase (small, committed copies).
pick() { # pick <work-dir> <shot-name> <out-name> <max-px>
  local work="$1" shot="$2" out="$3" max="$4"
  local framed="$work/${shot}_framed.png"
  local raw="$work/${shot}.png"
  local source=""
  [ -f "$framed" ] && source="$framed" || { [ -f "$raw" ] && source="$raw"; }
  [ -n "$source" ] || return 0
  mkdir -p Docs/marketing
  sips -Z "$max" "$source" --out "Docs/marketing/$out" >/dev/null
  echo "  showcase: Docs/marketing/$out"
}

echo "▶ Updating README showcase images"
pick Marketing/framed/iphone 01-home          iphone-home.png      900
pick Marketing/framed/iphone 03-zone-gradient iphone-gradient.png  900
pick Marketing/framed/iphone 04-gradients     iphone-palettes.png  900
pick Marketing/framed/ipad   01-home          ipad-home.png       1200
pick Marketing/framed/mac    01-home          mac-home.png        1400
pick Marketing/framed/mac    02-zone-gradient mac-gradient.png    1400

echo "✅ Done. Framed sets in Marketing/framed/, showcase in Docs/marketing/"
