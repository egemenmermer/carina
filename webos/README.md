# Carina for webOS

A lightweight IPTV player web app for LG TVs on webOS 4.x and later (2019+,
Chromium 53, ~1.5 GB RAM, Magic Remote and D-pad). It is the webOS sibling of
the Flutter app Carina (Android TV / Windows / macOS), which cannot run on webOS.

- TypeScript with no UI framework. esbuild bundles it for `chrome53`.
- Xtream Codes (`player_api.php`) and M3U playlists. Playlists are stored in localStorage.
- Live TV: categories, channel rows with logos, and now/next from `get_short_epg`.
  M3U playlists use XMLTV `url-tvg` when it is plain XML of 12 MB or less.
- Movies and series: poster grids, details, seasons and episodes.
- Favourites, last-channel resume, and search in the current section.
- Settings: language (follows the TV by default, or English / Türkçe) and playlist removal.
- Playback uses the TV's native `<video>` pipeline. Xtream live tries `.m3u8`
  first and falls back to `.ts`. VOD uses the container extension from the API.

## Layout

```
webos/
  static/          appinfo.json, index.html, icons (copied into dist/)
  src/data/        Xtream, M3U and XMLTV parsing, plus the Source interface (pure, unit-tested)
  src/ui/          DOM helpers, focus zones, and the virtualised list/grid
  src/screens/     playlists, add playlist, browse, details, player, settings
  scripts/         build.mjs, build-tests.mjs, serve.mjs (local proxy server)
  test/            node:test unit tests
```

## Build

Requires Node 22.

```sh
cd webos
npm ci
npm run typecheck   # tsc, lib ES2016 + DOM (keeps out APIs newer than Chrome 53)
npm test            # parser unit tests (node --test)
npm run build       # -> dist/ (app.js, app.css, fonts, appinfo.json, icons)
npm run package     # build + ares-package -> out/app.carina.webos_<version>_all.ipk
```

The version comes from `package.json` and is written into `dist/appinfo.json`.
The build fails if the bundle contains regex lookbehind or named groups,
because Chrome 53 cannot parse them. Fonts (Inter, OFL) are copied from the
Flutter app's `assets/fonts/inter`.

CI: `.github/workflows/webos.yml` type-checks, tests, builds the IPK and
uploads it as the `carina-webos` artifact.

## Testing in a desktop browser

Run the Flutter repo's mock server, then the local server. The local server
serves `dist/` and reverse-proxies every other path to the mock server, so
the app talks to its own origin and needs no CORS headers:

```sh
# from the repo root (media: run tools/gen_media.sh once, or pass another --media dir)
dart run tools/mock_server/bin/mock_server.dart --port 8787 --media tools/mock_server/media

# in webos/
npm run build:dev          # unminified, inline source maps
npm run serve              # http://localhost:8080  (PORT=… TARGET=http://127.0.0.1:8787)
```

Open http://localhost:8080 and add one of these playlists:

- Xtream: server `http://localhost:8080`, user `carina`, password `test123`
- M3U: `http://localhost:8080/get.php?username=carina&password=test123&type=m3u_plus`

Keys in a desktop browser:

| Key | Action |
|---|---|
| Arrow keys | Move focus |
| Enter | OK (hold for about 0.7 s to toggle a favourite) |
| Esc / Backspace | Back |
| PageUp / PageDown | CH+ / CH− |
| F1–F4 | Red, green, yellow, blue |
| Space | Play/pause |

Desktop Chrome cannot play `.ts` or HLS natively, so live channels show the
playback error there. Only MP4 VOD plays in a desktop browser. Live playback
has to be checked on a TV.

## Remote keys on webOS

Back = 461, OK = 13, arrows = 37–40, CH+/CH− = 33/34, colour keys = 403–406,
play/pause/stop = 415/19/413. Back on the first screen asks before exiting,
using `webOS.platformBack()` when available and `window.close()` otherwise.
The Magic Remote pointer works too: hovering focuses an item, a click is OK,
and the wheel scrolls lists.

---

## Test kurulumu (LG TV, Türkçe)

1. **LG hesabı:** https://webostv.developer.lge.com adresinde ücretsiz bir LG geliştirici hesabı aç.
2. **Developer Mode uygulaması:** TV'de LG Content Store'dan **Developer Mode**
   uygulamasını kur. Uygulamayı aç ve LG hesabınla giriş yap.
3. **Dev Mode'u aç:** *Dev Mode Status* anahtarını **ON** yap. TV yeniden başlar.
   Ardından *Key Server*'ı da **ON** yap. Ekranda TV'nin IP adresi ve passphrase görünür.
4. **IPK'yı kur.** Bilgisayar ile TV aynı ağda olmalı. İki yol var:
   - **webOS Dev Manager** (en kolayı, https://github.com/webosbrew/dev-manager-desktop):
     *Add device* ile TV'yi ekle, sonra *Apps → Install* ile `.ipk` dosyasını seç.
   - **CLI** (`npm i -g @webos-tools/cli`):
     ```sh
     ares-setup-device            # add: name tv, IP <TV IP>, port 9922, user prisoner
     ares-novacom --device tv --getkey   # passphrase'i gir
     ares-install --device tv Carina-x.y.z-N-webos.ipk
     ares-launch --device tv app.carina.webos
     ```
5. **50 saat kuralı:** Dev Mode oturumu 50 saat sürer. Süre dolunca yüklü test
   uygulamaları silinir. Bunu önlemek için Developer Mode uygulamasını açıp
   **Extend** düğmesine bas. webOS Dev Manager da oturumu uzatabilir.

IPK dosyası GitHub Actions'taki `webos` iş akışının `carina-webos` artifact'ında bulunur.
