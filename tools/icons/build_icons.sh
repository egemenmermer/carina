#!/usr/bin/env bash
# Regenerates every Carina app icon from the painter in
# lib/core/brand/carina_mark.dart (geometry: docs/ARCHITECTURE.md section 5).
#
#   bash tools/icons/build_icons.sh
#
# Needs: flutter (the project SDK on PATH) and ImageMagick 7 (`magick`).
# Writes:
#   tools/icons/png/carina_icon_<size>.png        16 20 24 32 40 48 64 128 256 512 1024
#   windows/runner/resources/app_icon.ico        16 24 32 48 64 128 256
#   macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_<size>.png
#   assets/brand/carina_icon_1024.png
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

MAGICK="${MAGICK:-magick}"
PNG_DIR="tools/icons/png"
ICO="windows/runner/resources/app_icon.ico"
MAC_SET="macos/Runner/Assets.xcassets/AppIcon.appiconset"
ICO_SIZES=(16 24 32 48 64 128 256)
MAC_SIZES=(16 32 64 128 256 512 1024)

command -v flutter >/dev/null || { echo "flutter not on PATH" >&2; exit 1; }
command -v "$MAGICK" >/dev/null || { echo "ImageMagick ($MAGICK) not found" >&2; exit 1; }

echo "==> Rendering PNGs with CarinaMarkPainter"
CARINA_ICON_OUT="$PNG_DIR" flutter test tools/icons/render_icons_test.dart

echo "==> Building $ICO"
ico_inputs=()
for s in "${ICO_SIZES[@]}"; do ico_inputs+=("$PNG_DIR/carina_icon_$s.png"); done
# Frames below 256 px are stored as 32-bit BMP (alpha), the 256 px frame as PNG.
"$MAGICK" "${ico_inputs[@]}" "$ICO"

echo "==> Copying macOS AppIcon set"
for s in "${MAC_SIZES[@]}"; do
  cp "$PNG_DIR/carina_icon_$s.png" "$MAC_SET/app_icon_$s.png"
done

echo "==> Copying brand assets"
cp "$PNG_DIR/carina_icon_1024.png" assets/brand/carina_icon_1024.png

echo "==> Verifying"
"$MAGICK" identify "$ICO"
frames=$("$MAGICK" identify -format '%w\n' "$ICO" | sort -n | tr '\n' ' ')
expected="$(printf '%s\n' "${ICO_SIZES[@]}" | sort -n | tr '\n' ' ')"
if [[ "$frames" != "$expected" ]]; then
  echo "unexpected .ico frames: $frames (expected $expected)" >&2
  exit 1
fi
for i in "${!ICO_SIZES[@]}"; do
  s="${ICO_SIZES[$i]}"
  diff=$("$MAGICK" compare -metric AE "${ICO}[$i]" "$PNG_DIR/carina_icon_$s.png" null: 2>&1 || true)
  if [[ "${diff%% *}" != "0" ]]; then
    echo ".ico frame $s px differs from the PNG ($diff pixels)" >&2
    exit 1
  fi
done
echo "Icons regenerated."
