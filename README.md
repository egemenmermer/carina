<div align="center">

<img src="assets/brand/carina_icon_1024.png" width="112" alt="Carina">

# Carina

**A fast, keyboard-friendly TV player for your own playlists.**
Windows and macOS, one Flutter codebase. English and Turkish.

</div>

Carina is a player only. It ships with no channels, no content and no
provider. You add your own Xtream Codes account or M3U playlist (with an
optional XMLTV guide), and Carina turns it into live TV, a TV guide, movies
and shows.

Carina is the sibling of [Vela](https://github.com/egemenmermer/vela): in the
old Argo Navis constellation Vela is the sails and Carina the hull.

## Features

- **Playlists:** Xtream Codes, M3U URL or local M3U file; live checks while
  you type, an import stepper, incremental reloads that keep favorites, watch
  state and renames; several playlists with avatars and an optional access PIN.
- **TV Live:** horizontal and vertical layouts, an in-place live preview,
  NOW ON AIR and UPCOMING panels, number zapping, last watched, custom EPG
  matching, hidden and locked channels.
- **TV Guide:** a custom-painted, virtualized grid (1,000 channels × 7 days
  scrolls at 60 fps), programme details, catch-up / TV archive.
- **Movies and Shows:** hero, Continue watching, Favorites, Recently added,
  category rows, See All grids, detail sheets with seasons and episodes.
  Optional TMDb artwork with your own API key.
- **Player:** libmpv through media_kit, so AC-3, E-AC-3, HEVC, MPEG-2 and
  interlaced streams all play; audio, subtitle and picture menus, resume,
  next episode, stats overlay and full keyboard control.
- **Multi-channel:** up to four live channels at once (1+1, 2×2, 1+3).
- **Search:** SQLite FTS5 across channels, movies, shows, programmes and
  people, Turkish-insensitive.
- **Parental control:** channel and category locks, hide mode, session unlock.
- **Reminders:** for upcoming programmes.

## Install (Windows)

The Windows workflow builds an installer
(`Carina-Setup-<version>-x64.exe`, per user, no admin rights) and a portable
zip on every push; download them from the run's artifacts. The builds are not
code-signed, so Windows SmartScreen asks once: choose **More info → Run
anyway**.

Carina keeps its data in `%APPDATA%\Carina`.

## Build from source

Requirements: Flutter 3.47.7 (Dart 3.13.5). On Windows: Visual Studio 2022
with "Desktop development with C++".

```sh
flutter pub get
dart run build_runner build -d   # drift database code
flutter gen-l10n                 # translations
flutter run -d windows           # or: -d macos
```

Tests:

```sh
flutter test
```

The tests run against a deterministic local mock IPTV server
(`tools/mock_server`: Xtream API, M3U, XMLTV, live TS and HLS, VOD with Range
requests and failure endpoints) and generated media (`tools/gen_media.sh`,
needs ffmpeg). Start the server by hand with
`dart run tools/mock_server/bin/mock_server.dart`.

More: [architecture](docs/ARCHITECTURE.md) · [assets and licenses](docs/ASSETS.md) ·
[app icons](tools/icons/README.md).

## Stack

Flutter · media_kit (libmpv / FFmpeg) · Riverpod · go_router · drift + SQLite
FTS5 · dio · package:xml (streaming) · window_manager · Inno Setup.

## Legal

Carina does not provide, sell or link to any TV channels or content. Use it
only with playlists you have the right to watch. When you add a TMDb key,
Carina uses the TMDB API but is not endorsed or certified by TMDB.

## License

[GPL-3.0](LICENSE). Bundled fonts and libraries keep their own licenses; see
[docs/ASSETS.md](docs/ASSETS.md).
