# Carina app icons

All icons come from one source: `CarinaMarkPainter` in
`lib/core/brand/carina_mark.dart` (geometry in `docs/ARCHITECTURE.md`, section 5:
the hull, play button and star in the brand gradient on a black rounded-square
tile, radius 14, 64×64 grid).
Each size is rasterized natively by Flutter, so small sizes are anti-aliased at
their own pixel grid instead of being downscaled.

## Regenerate

From the project root:

```sh
bash tools/icons/build_icons.sh
```

Requirements: the project Flutter SDK (on `PATH`, or `FLUTTER=/path/to/flutter`) and ImageMagick 7 (`magick`; override with
`MAGICK=/path/to/magick`). The script fails if the `.ico` frames do not match the
rendered PNGs pixel for pixel.

## Outputs

| File | Contents |
|---|---|
| `tools/icons/png/carina_icon_<size>.png` | 16, 20, 24, 32, 40, 48, 64, 72, 96, 128, 144, 192, 256, 512, 1024 px masters |
| `windows/runner/resources/app_icon.ico` | 16, 24, 32, 48, 64, 128 (32-bit BMP) and 256 (PNG) frames; used by `Runner.rc` and the installer |
| `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_<size>.png` | 16, 32, 64, 128, 256, 512, 1024 (names match `Contents.json`) |
| `android/app/src/main/res/mipmap-<density>/ic_launcher.png` | legacy launcher icon (tile), 48 / 72 / 96 / 144 / 192 px for mdpi to xxxhdpi |
| `android/app/src/main/res/mipmap-<density>/ic_launcher_foreground.png` | adaptive-icon foreground (mark on transparent, centred inside the 66/108 dp safe zone), 108 / 162 / 216 / 324 / 432 px; `mipmap-anydpi-v26/ic_launcher.xml` (hand-written) pairs it with a black background and reuses it as the themed monochrome layer |
| `android/app/src/main/res/drawable-xhdpi/tv_banner.png` | Android TV banner, exactly 320×180 px: black, the mark and the Inter SemiBold "Carina" wordmark centred as one group; rendered by the same test (loads the app fonts) |
| `assets/brand/carina_icon_1024.png` | 1024 px icon bundled with the app |
| `assets/brand/carina_mark.svg` | the mark alone (no tile), hand-written vector with the same geometry |

`tools/icons/render_icons_test.dart` lives outside `test/`, so the normal
`flutter test` run does not touch these files. Check the icon `.ico` with
`magick identify windows/runner/resources/app_icon.ico`.
