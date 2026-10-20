# Assets and licenses

Carina ships no third-party artwork. Everything visual is either bundled under
an open license (fonts, icon glyphs) or drawn by our own code at runtime.

## Carina mark (original)

- Code: `lib/core/brand/carina_mark.dart` (`CarinaMark`, `CarinaMarkPainter`).
- An original mark: a flat-deck hull with a play button cut out of it, under
  a star (Canopus). Geometry on a 64×64 grid, optional black rounded-square
  tile (radius 14) for the app icon. Source SVG: `assets/brand/carina_mark.svg`.
- Brand gradient `#FFB46B → #FF5E57`; `KColors.brand` is the coral end. The
  UI accent (`KColors.accent`, `#FF2500`) is separate.

## Inter (font)

- Files: `assets/fonts/inter/Inter-{Regular,Medium,SemiBold,Bold,ExtraBold}.ttf`
  (weights 400–800), declared as family `Inter` in `pubspec.yaml`.
- License: SIL Open Font License 1.1 — `assets/fonts/inter/OFL.txt`.
  Copyright © 2016 The Inter Project Authors (https://github.com/rsms/inter).
- Use: the only UI typeface (`KText.family`). Times use tabular figures.

## Phosphor icons (glyph font)

- Source: the `phosphor_flutter` 2.1.0 dependency (MIT License, © 2020–2021
  Phosphor Icons, https://phosphoricons.com). Its font files are bundled by
  the package (`packages/phosphor_flutter/Phosphor{Light,Regular,Bold,Fill,…}`).
- `phosphor_flutter`'s Dart classes do not compile with Flutter 3.47
  (`PhosphorIconData extends IconData`, which is now a `final` class), so
  Carina uses `lib/core/icons/phosphor_icons.dart`: a generated table of plain
  `const IconData` values (classes `PhosphorIconsLight`, `PhosphorIconsRegular`,
  `PhosphorIconsBold`, `PhosphorIconsFill`, same member names as the package)
  pointing at the bundled fonts. Icon tree shaking keeps working because the
  values are const.

## Avatars (procedurally generated, original)

- Code: `lib/core/avatars/avatar_catalog.dart` (`AvatarCatalog`, 58 entries)
  and `lib/core/avatars/k_avatar.dart` (`KAvatar`).
- No image files. Every avatar is drawn at runtime: a two-stop gradient
  circle with a soft highlight plus one glyph:
  - Characters, Animals, Cars, Objects: a single Unicode emoji rendered with
    the operating system's emoji font (Apple Color Emoji on macOS, Segoe UI
    Emoji on Windows, Noto Color Emoji on Linux). No emoji images are
    bundled; the glyphs belong to the OS font and differ slightly per OS.
  - Abstract: geometric shapes painted with `CustomPainter` (rings,
    triangles, waves, dots, diamond, crescent, star, stripes, hexagon, orbit).
  - Initials: the playlist name's initials in Inter ExtraBold.
- Counts: Characters 10, Animals 12, Cars 8, Objects 10, Abstract 10,
  Initials 8 (58 total).
- Channel logos that fail to load fall back to `KMonogram` (initials on a
  deterministic dark gradient, `lib/core/widgets/k_logo_tile.dart`).

## Remote artwork

Posters, backdrops and channel logos come from the user's own playlist (or
TMDb when the user configures a key) and are cached only on the user's
machine by `KImageLoader` (`<app support dir>/image_cache/<sha1(url)>.img`).
Nothing is bundled.
