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

Requirements: the project Flutter SDK and ImageMagick 7 (`magick`; override with
`MAGICK=/path/to/magick`). The script fails if the `.ico` frames do not match the
rendered PNGs pixel for pixel.

## Outputs

| File | Contents |
|---|---|
| `tools/icons/png/carina_icon_<size>.png` | 16, 20, 24, 32, 40, 48, 64, 128, 256, 512, 1024 px masters |
| `windows/runner/resources/app_icon.ico` | 16, 24, 32, 48, 64, 128 (32-bit BMP) and 256 (PNG) frames; used by `Runner.rc` and the installer |
| `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_<size>.png` | 16, 32, 64, 128, 256, 512, 1024 (names match `Contents.json`) |
| `assets/brand/carina_icon_1024.png` | 1024 px icon bundled with the app |
| `assets/brand/carina_mark.svg` | the mark alone (no tile), hand-written vector with the same geometry |

`tools/icons/render_icons_test.dart` lives outside `test/`, so the normal
`flutter test` run does not touch these files. Check the icon `.ico` with
`magick identify windows/runner/resources/app_icon.ico`.
