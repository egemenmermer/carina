#!/usr/bin/env bash
# Renders the DMG window background (640x400 pt, plus @2x): a pale blue
# gradient (Finder draws the icon labels in black) with a navy arrow from the
# app to the Applications folder.
# Needs ImageMagick 7. Output: background.png, background@2x.png (committed).
set -euo pipefail
cd "$(dirname "$0")"
FONT_DIR="../../../assets/fonts/inter"
magick -size 1280x800 -define gradient:angle=225 gradient:'#FFFFFF-#D3E3F9' \
  -fill none -stroke 'rgba(15,31,73,0.45)' -strokewidth 6 \
  -draw "path 'M 500,370 Q 640,300 780,370'" \
  -fill 'rgba(15,31,73,0.45)' -stroke none \
  -draw "polygon 800,382 760,388 772,352" \
  -fill '#0F1F49' -font "$FONT_DIR/Inter-SemiBold.ttf" -pointsize 40 \
  -gravity north -annotate +0+600 "Carina'yı Uygulamalar klasörüne sürükleyin" \
  -fill '#4A5C86' -font "$FONT_DIR/Inter-Regular.ttf" -pointsize 30 \
  -annotate +0+665 'Drag Carina to the Applications folder' \
  background@2x.png
magick background@2x.png -resize 640x400 background.png
