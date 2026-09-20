#!/usr/bin/env bash
# Renders the app icon from one SVG. Drawn rather than bundled as bitmaps so the
# 1024 and the 16 come from the same geometry and stay sharp on every display.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/../app/Resources/Assets.xcassets/AppIcon.appiconset"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

cat > "$TMP/icon.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
  <defs>
    <!-- the stone itself: obsidian, lit from inside rather than from a lamp -->
    <radialGradient id="stone" cx="42%" cy="36%" r="72%">
      <stop offset="0%"  stop-color="#4A2A12"/>
      <stop offset="45%" stop-color="#1C1116"/>
      <stop offset="100%" stop-color="#07070A"/>
    </radialGradient>
    <!-- what is burning in there -->
    <radialGradient id="fire" cx="50%" cy="58%" r="50%">
      <stop offset="0%"   stop-color="#FFD9A8" stop-opacity="0.95"/>
      <stop offset="35%"  stop-color="#FF7A1A" stop-opacity="0.85"/>
      <stop offset="70%"  stop-color="#E8420E" stop-opacity="0.45"/>
      <stop offset="100%" stop-color="#8C1D05" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="sheen" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%"   stop-color="#FFFFFF" stop-opacity="0.26"/>
      <stop offset="100%" stop-color="#FFFFFF" stop-opacity="0"/>
    </linearGradient>
  </defs>
  <rect width="1024" height="1024" rx="228" fill="#0B0B0C"/>
  <circle cx="512" cy="512" r="352" fill="url(#stone)"/>
  <ellipse cx="512" cy="556" rx="212" ry="212" fill="url(#fire)"/>
  <!-- the rim: a sphere reads as a sphere only if the edge catches light -->
  <circle cx="512" cy="512" r="352" fill="none" stroke="#FFB067" stroke-width="10" opacity="0.55"/>
  <!-- specular cap, top-left, the one cue that says glass and not a hole -->
  <ellipse cx="416" cy="372" rx="132" ry="82" fill="url(#sheen)" transform="rotate(-22 416 372)"/>
</svg>
SVG

mkdir -p "$OUT"

# Rendered once at full size, then downsampled. Headless Chrome clamps its window
# to a few hundred pixels, so asking it for a 16x16 screenshot silently returns a
# blank square rather than a small icon -- the file is written, the build passes,
# and the menu bar shows nothing. Downsampling from the 1024 keeps every size on
# the same geometry and cannot fail quietly.
"$CHROME" --headless --disable-gpu --hide-scrollbars --default-background-color=00000000 \
  --force-device-scale-factor=1 --window-size=1024,1024 \
  --screenshot="$OUT/icon_1024.png" "file://$TMP/icon.svg" >/dev/null 2>&1

for s in 16 32 64 128 256 512; do
  sips -s format png -z "$s" "$s" "$OUT/icon_1024.png" --out "$OUT/icon_${s}.png" >/dev/null
done

cat > "$OUT/Contents.json" <<'J'
{
  "images" : [
    { "idiom":"mac", "scale":"1x", "size":"16x16",   "filename":"icon_16.png" },
    { "idiom":"mac", "scale":"2x", "size":"16x16",   "filename":"icon_32.png" },
    { "idiom":"mac", "scale":"1x", "size":"32x32",   "filename":"icon_32.png" },
    { "idiom":"mac", "scale":"2x", "size":"32x32",   "filename":"icon_64.png" },
    { "idiom":"mac", "scale":"1x", "size":"128x128", "filename":"icon_128.png" },
    { "idiom":"mac", "scale":"2x", "size":"128x128", "filename":"icon_256.png" },
    { "idiom":"mac", "scale":"1x", "size":"256x256", "filename":"icon_256.png" },
    { "idiom":"mac", "scale":"2x", "size":"256x256", "filename":"icon_512.png" },
    { "idiom":"mac", "scale":"1x", "size":"512x512", "filename":"icon_512.png" },
    { "idiom":"mac", "scale":"2x", "size":"512x512", "filename":"icon_1024.png" }
  ],
  "info" : { "author":"xcode", "version":1 }
}
J
echo "  icon set rendered to $OUT"
