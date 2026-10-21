# Carina architecture

This file says where code goes and which interfaces connect the pieces.

## 0. Environment

- Flutter 3.47.7 / Dart 3.13.5 (the version CI uses; see `.github/workflows/windows.yml`).
- Generated code: `dart run build_runner build` (drift) and `flutter gen-l10n`. Translations live in `lib/l10n/parts/<feature>.<locale>.json`; `dart run tools/l10n_merge.dart` merges them into `lib/l10n/app_<locale>.arb`.
- Never put credentials, playlist URLs or tokens in code, tests, logs or docs. Mock-server credentials (`carina` / `test123`) are fine.

## 1. Layout

```
lib/
  main.dart                  bootstrap + CLI flags (lead)
  app/                       app widget, router, shell, providers (lead)
    platform/                form factor (desktop/tv), screen-awake (wakelock)
  core/                      design system: tokens, theme, widgets (design agent)
    brand/carina_mark.dart    the Carina mark (shared, do not change geometry)
  data/
    db/                      drift schema (lead) — tables.dart, database.dart, search.drift
    text/                    normalize.dart, quality.dart, flags.dart
    net/                     dio factory, URL masking
    sources/source_exception.dart   shared error type
    sources/xtream/          Xtream API client + DTOs + URL builders
    sources/m3u/             M3U parser
    sources/catchup/         catch-up URL builders (M3U modes + Xtream)
    sources/xmltv/           streaming XMLTV parser
    epg/                     EPG channel matcher
    import/                  import pipeline, progress events, reload scheduler
    repositories/            query/mutation APIs used by the UI
  player/
    engine/                  PlaybackEngine interface + MpvEngine + FakeEngine
    ui/                      player screens and overlays
  features/<name>/           one folder per feature (playlists, live, guide, home_movies,
                             home_shows, details, search, favorites, settings, parental,
                             reminders, downloads, multiview)
  l10n/parts/<feature>.<en|tr>.json   strings per feature (see section 6)
tools/
  gen_media.sh               ffmpeg test media generator
  mock_server/               bin/mock_server.dart (CLI) + src/ (library)
  capture/                   compare.sh and helpers
test/                        mirrors lib/ (test/data/m3u/…, test/core/…)
test/support/                shared test helpers (screenshot harness, fixtures)
integration_test/
installer/carina.iss
```

## 2. Data contracts

### 2.1 Errors
All source failures throw `SourceException(kind, statusCode, message, url)` from `lib/data/sources/source_exception.dart`. `url` must be masked.

### 2.2 URL masking — `lib/data/net/mask.dart`
`String maskUrl(String url)` hides credentials: `http://dom***:8080/live/ka***/***/1001.ts`; username/password query parameters become `***`; host is cut after 3 characters. `String maskServer(String server)` → `https://dom***:8080`. Use these in every log line and every UI that shows a URL.

### 2.3 Text — `lib/data/text/`
- `normalize.dart`
  - `String normalizeForSearch(String s)`: lowercase (Turkish-aware: `İ`,`I`,`ı` → `i`), fold diacritics (`ş→s ç→c ğ→g ö→o ü→u é→e â→a`…), drop quality tokens (SD, HD, FHD, UHD, 4K, 8K, H265, H.265, HEVC, 50FPS, 60FPS, HDR), punctuation → space, collapse spaces, trim.
  - `String normalizeChannelName(String s)`: `normalizeForSearch` + strip country prefixes (`TR:`, `TR |`, `|TR|`, `[TR]`, `TR -`, `TR.`), then remove every non-alphanumeric character. Used for EPG name matching.
  - `String ftsQuery(String userInput)`: builds an FTS5 MATCH expression with prefix matching (`sicak kafa` → `"sicak"* "kafa"*`), escaping quotes.
- `quality.dart`
  - `QualityParse parseQuality(String rawName)` → `({String displayName, List<String> badges})`. Badges in display order, normalized to `SD HD FHD 4K H265 50FPS`. `UHD`→`4K`, `HEVC`/`H.265`→`H265`. Tokens are matched as whole words (`HDTV` is not `HD`; `Show TV HD` → `Show TV` + `[HD]`). Stored in `channels.quality` as comma-joined badges.
- `flags.dart`
  - `String? flagForCategory(String name)`: country flag emoji when the name starts with a code or country name (`TR`, `TR |`, `Türkiye`, `IT`, `Italy`, `UK`, `DE`…). `String flagged(String name)` → `🇹🇷 Ulusal` style label.

### 2.4 Xtream — `lib/data/sources/xtream/`
- `XtreamCredentials(server, username, password)`; `server` is used exactly as entered (no trailing slash).
- `XtreamClient(Dio dio, XtreamCredentials creds)`:
  - `Future<XtreamAccount> authenticate()` (user_info + server_info; throws `unauthorized`/`accountInactive`).
  - `liveCategories()`, `liveStreams({String? categoryId})` (all at once; caller falls back per category), `vodCategories()`, `vodStreams({String? categoryId})`, `seriesCategories()`, `seriesList({String? categoryId})`, `vodInfo(String vodId)`, `seriesInfo(String seriesId)`, `shortEpg(String streamId, {int limit = 10})`, `simpleDataTable(String streamId)`, `Uri xmltvUri()`.
  - DTOs normalize "1" vs 1 vs null vs "" (`lib/data/sources/xtream/json_utils.dart`: `asInt`, `asDouble`, `asString`, `asBool`, `asList`, `asDateFromEpoch`).
  - Bodies over ~50 KB are decoded off the UI isolate.
- `XtreamUrls(server, username, password)`: `live(streamId, ext)`, `movie(streamId, ext)`, `episode(episodeId, ext)`, `timeshift(streamId, startUtc, durationMinutes, serverOffset)`, `timeshiftFallback(...)`. `XtreamAccount.serverUtcOffset` is computed from `server_info.time_now` − `timestamp_now` (no tz database). `direct_source` wins when non-empty.

### 2.5 M3U — `lib/data/sources/m3u/`
- `M3uHeader` (tvgUrls, tvgShift, catchup, catchupDays, catchupSource, userAgent).
- `M3uEntry` (duration, name, url, attrs map, tvgId, tvgName, tvgLogo, tvgChno, group, tvgShift, catchup, catchupDays, catchupSource, timeshift, userAgent, referrer, headers map, unsupported, kind `M3uKind {live, movie, episode}`, seriesName, season, episode).
- `M3uParseResult parseM3u(String text)`; `Stream<M3uEntry>`-based `parseM3uStream(Stream<List<int>> bytes)` that also exposes the header; `Future<M3uParseResult> parseM3uInIsolate(String text)`.
- `XtreamExportInfo? detectXtreamExport(String url)` → server/username/password from `get.php?username=…&password=…`.

### 2.6 Catch-up — `lib/data/sources/catchup/`
- `String? buildCatchupUrl({required String streamUrl, required String mode, String? source, required DateTime startUtc, required DateTime endUtc, DateTime? nowUtc, String? channelName, Duration serverOffset = Duration.zero})` implementing Kodi IPTV Simple conventions (default/append/shift/timeshift/flussonic/fs/xc) and every placeholder in BRIEF 8.2.
- `bool isReplayable({required DateTime startUtc, required DateTime endUtc, required int archiveDays, DateTime? nowUtc})`.

### 2.7 XMLTV — `lib/data/sources/xmltv/`
- Events: `XmltvChannel(id, displayNames, icon)`, `XmltvProgramme(channelId, start, stop, title, subTitle, description, category, episodeNum, icon, rating)` with UTC `DateTime`s.
- `Stream<XmltvEvent> parseXmltv(Stream<List<int>> bytes)` — sniffs gzip magic bytes, streams through `package:xml` events, never builds a DOM.
- `DateTime parseXmltvTime(String)` handles `YYYYMMDDhhmmss ±hhmm`, missing offset (UTC), short forms.
- An isolate runner that parses a file or byte stream and delivers batches of 5,000 programmes through a callback/stream.

### 2.8 EPG matching — `lib/data/epg/epg_matcher.dart`
`EpgMatcher(Iterable<EpgChannelRef> channels)` with `String? match({String? customEpgId, String? tvgId, required String name})`; order: custom → exact id → case-insensitive id → normalized display name → null.

### 2.9 Database
`lib/data/db/database.dart` (`AppDatabase`), tables in `tables.dart`, FTS5 in `search.drift`. Tests: `AppDatabase.forTesting(NativeDatabase.memory())`. Generated code is committed (`database.g.dart`). Times in `programmes` / `reminders` are UTC epoch milliseconds. Stable item keys = `playlistId + itemType + providerId`.

### 2.10 Repositories (wave 2) — `lib/data/repositories/`
Riverpod providers expose them; UI reads only through repositories, never through `AppDatabase` directly. Names: `PlaylistRepository`, `LiveRepository`, `EpgRepository`, `VodRepository`, `FavoritesRepository`, `WatchStateRepository`, `RemindersRepository`, `SearchRepository`, `ParentalService`, `StreamUrlResolver`. Settings use `SettingsStore` (`lib/data/settings/settings_store.dart`, typed keys in `setting_keys.dart`; widgets call `ref.watchSetting(PlaylistSettings.liveLayout, playlistId: pid)`). Secrets use `SecretStore` (`lib/data/secrets/secret_store.dart`). App folders: `AppPaths` (`lib/data/app_paths.dart`). Core providers `appDatabaseProvider`, `appPathsProvider`, `settingsStoreProvider`, `secretStoreProvider` are overridden at bootstrap; tests override them with an in-memory DB, a temp dir, a loaded store and `MemorySecretStore`.

Each repository file owns its own providers (e.g. `liveRepositoryProvider` in `live_repository.dart`). If a feature needs an extra query, it adds an `extension` on the repository inside its own feature folder (`lib/features/<x>/data/`) instead of editing shared repository files.

### 2.11 Stored-data semantics (import ⇄ repositories)
- Provider ids: Xtream ids as strings (`stream_id`, `series_id`, episode `id`, category `category_id`); M3U entries use `m3uEntryId()`; M3U series id = sha1 of the normalized series name (16 hex chars); M3U categories: provider id = group title (per section).
- Channels: `name` = raw provider name; `displayName`/`quality` from `parseQuality` (`quality` is comma-joined badges, e.g. `FHD` or `HD,H265`); `epgId` = provider tvg-id; `matchedEpgId` written by the EPG import using `EpgMatcher`; `customEpgId` is local (never overwritten by imports); `archiveDays` from `tv_archive_duration` (Xtream, when `tv_archive==1`) or `catchup-days` (M3U; header default applies; default 7 if catchup set without days).
- Local fields an import must never overwrite: `localName`, `customIndex`, `hidden`, `locked`, `customEpgId`, plus `infoJson`/`infoFetchedAt` unless the item changed. Upserts target the `(playlistId, providerId)` unique key (categories: `(playlistId, kind, providerId)`).
- Incremental reload: mark the section's rows `removed = true`, upsert (sets `removed = false`), delete rows still `removed` only after the whole import succeeds. Favorites, watch state, last-watched and reminders reference provider ids, so they survive.
- `search_index` is rebuilt per playlist after each content import: kinds `channel` (displayName), `movie`, `series`, `person` (each cast name from series `cast` and cached movie info; `ref_id` = person name, `title` = display name). `programme_search` is rebuilt after each EPG import for programmes with `stop > now` and `start < now + 48h`.
- Programmes: UTC epoch ms, EPG time shift already applied; window `now − max(maxArchiveDays, 1) days … now + 7 days`; pruned before each EPG reload ("Cleaning programs").
- `playlists.liveCount/movieCount/seriesCount/programmeCount` are updated at the end of each import; `lastReloadAt` / `lastEpgReloadAt` too.

### 2.12 Import pipeline — `lib/data/import/`
`ImportService` (provider `importServiceProvider`): `Stream<ImportProgress> start(int playlistId, {ImportScope scope = ImportScope.all})` (`all` | `content` | `epg`), `void cancel(int playlistId)`, `Stream<ImportProgress?> watch(int playlistId)` (latest progress for the top-bar chip; null when idle), `bool isRunning(int playlistId)`, plus `ReloadScheduler.checkOnOpen(playlistId)` (reload in the background when `now − lastReloadAt > reloadFrequencyHours`). `ImportProgress {ImportStep step; Map<ImportStep,int> counts; int? receivedBytes; int? totalBytes; SourceException? error; List<ImportWarning> warnings; bool done}`; `ImportStep { connecting, liveCategories, liveChannels, movies, series, epgCleaning, epgDownloading, epgParsing, completed, failed, cancelled }`. A section that imports zero items yields an `ImportWarning(SourceErrorKind.sectionEmpty, section)` (the wizard shows an "imported but section empty" dialog). Heavy parsing runs in isolates; DB writes are batched (≤ 5,000 rows per transaction).

## 3. Player engine — `lib/player/engine/`

```dart
enum EngineProfile { auto, hardware, software, lowLatency }
enum AspectMode { auto, fill, crop, r16x9, r4x3 }
enum DeinterlaceMode { auto, on, off }

abstract class PlaybackEngine {
  Stream<EngineState> get stateStream;   // position, duration, playing, buffering,
  EngineState get state;                 // bufferingPercent, completed, error, width, height
  Stream<EngineStats> get statsStream;   // 1 Hz: resolution, fps, codecs, channels, hwdec, cache
  Future<void> open(PlaybackSource source, {Duration? start, bool autoplay = true});
  Future<void> play(); Future<void> pause(); Future<void> playOrPause();
  Future<void> seek(Duration position); Future<void> stop();
  Future<void> setVolume(double v0to100); Future<void> setMuted(bool m);
  Future<void> setRate(double rate);
  List<EngineTrack> get audioTracks; List<EngineTrack> get subtitleTracks;
  Future<void> selectAudio(EngineTrack t); Future<void> selectSubtitle(EngineTrack? t);
  Future<void> addExternalSubtitle(String pathOrUri);
  Future<void> setAudioDelay(Duration d); Future<void> setSubtitleDelay(Duration d);
  Future<void> setSubtitleScale(double s);
  Future<void> setAspect(AspectMode m); Future<void> setDeinterlace(DeinterlaceMode m);
  Future<void> switchProfile(EngineProfile p);   // reopen same source at same position
  EngineProfile get profile;
  Future<String?> getProperty(String mpvName);
  Widget buildVideo({Key? key, BoxFit fit = BoxFit.contain});  // no built-in controls
  Future<void> dispose();
}
```
`PlaybackSource(url, headers, userAgent, referer, isLive, title)`; `EngineOptions` carries profile, buffer policy, hwdec on/off, deinterlace mode/method, default aspect, preferred audio/subtitle languages, default audio delay, subtitle scale, reconnect attempts. `MpvEngine` (media_kit) is the default; `FakeEngine` is used in widget/screenshot tests. The UI never imports `package:media_kit*` outside `lib/player/engine/`.

## 4. Mock server — `tools/mock_server/`

- CLI: `dart run tools/mock_server/bin/mock_server.dart --port 8787 --scale small|large --media tools/mock_server/media`.
- Library: `MockServer.start({int port = 8787, MockScale scale = MockScale.small, required String mediaDir})` → `.baseUrl`, `.stop()`, `.requestLog`; `MockCatalog.generate(scale)` is deterministic and exposes known fixtures (`MockFixtures`).
- Credentials: `carina` / `test123` (active, expires 2027-03-01, max_connections 2); `expired` / `test123` (Expired); anything else → HTTP 401 with `{"user_info":{"auth":0}}`.
- Failure endpoints under `/fail/<kind>/…` (empty, html, slow, 401, notm3u, badxml) and stream failures (drop after 10 s, 404).
- Known fixtures (stable ids, used by integration tests):

| What | Provider id | Notes |
|---|---|---|
| `TRT 1 HD` | live 1001 | H.264/AAC TS, archive 3 days, category `TR \| Ulusal` |
| `Show TV FHD` | live 1002 | H.264/AC-3 5.1 TS |
| `UHD Test 4K` | live 1003 | HEVC/E-AC-3 2160p TS |
| `Kanal D SD` | live 1004 | MPEG-2/MP2 576i TS |
| `Haber Canlı HLS` | live 1005 | live HLS |
| `Çocuk Kilitli` | live 1006 | intended parental-lock test channel |
| `Sıcak Kafa` | series 5001 | 2 seasons; episodes use vod_tracks.mkv / h264_aac_720p50.mp4 |
| `Kış Uykusu` | movie 3001 | vod_tracks.mkv (2 audio + 2 subtitle tracks) |

## 5. Design system — `lib/core/`
Tokens in `lib/core/tokens.dart` (`KColors`, `KRadii`, `KDurations`, `KText`), theme in `lib/core/theme.dart`, widgets in `lib/core/widgets/`. Feature code uses these, never raw hex colors or ad-hoc text styles. Icons: `phosphor_flutter` (Light weight by default, Regular/Bold for emphasis). Font family `Inter`; times use `FontFeature.tabularFigures()`.

Carina mark (do not change): 64×64 grid, black rounded-square tile (radius 14) for the app icon; a flat-deck hull with a play button cut out of it and a star dot (Canopus) at `(47,18)` r 3.4, filled with the brand gradient `#FFB46B → #FF5E57` (`KColors.brand` is the coral end). Source: `assets/brand/carina_mark.svg`. Widget: `lib/core/brand/carina_mark.dart`.

## 6. Localization
Strings live in per-feature part files: `lib/l10n/parts/<feature>.en.json` and `<feature>.tr.json` (flat ARB entries, `@key` metadata allowed in the en file). Keys are camelCase and prefixed with the feature (`liveNowOnAir`, `guideToday`). After editing: `dart run tools/l10n_merge.dart && flutter gen-l10n`. Access with `L10n.of(context).liveNowOnAir` (`package:carina/l10n/gen/app_localizations.dart`). Turkish must read naturally (not literal). Turkish times are 24h.

## 7. Testing
- Unit tests next to the code's mirror path under `test/`.
- Screenshot harness: `test/support/screenshot.dart` (`loadAppFonts()`, `captureScreen(tester, widget, 'name', size: Size(1440, 900))` → `build/screens/<name>.png`). Use it to look at the UI.
- Integration tests in `integration_test/` start the mock server in-process.

## 8. Routing (lead owns `lib/app/router.dart`)
`/` Playlist Manager · `/playlists/new` · `/playlists/:pid/edit` · `/playlists/:pid/import` · `/playlists/:pid/avatar` · `/p/:pid/movies` · `/p/:pid/shows` · `/p/:pid/live` · `/p/:pid/guide` · `/p/:pid/search` · `/p/:pid/settings[/:section]` · `/p/:pid/movies/category/:cid` · `/p/:pid/shows/category/:cid` · `/p/:pid/multiview` · `/settings[/:section]` (app-level) · `/downloads`. The player opens as a root-navigator full-screen route via `openPlayer(context, PlayRequest)` in `lib/player/player_api.dart`.

## 8.1 App layer (lead) — `lib/app/`
- `launch_options.dart` (`launchOptionsProvider`), `bootstrap.dart` (`AppContext`, `postLaunchHooks`), `app.dart` (`CarinaApp`: theme, l10n, `KToastHost`, `ReminderListener`, F11).
- `time_format.dart`: `timeFormatProvider` → `CarinaTimeFormat` (`time`, `range`, `navDateTime`, `dayHeader`, `date`, `monthYear`, `minutes`, `runtime`, static `clock`). Always format times through it (Turkish = 24 h). `appLocaleCodeProvider` gives `en`/`tr`.
- `clock.dart`: `minuteClockProvider` (ticks every minute; override with `Stream.value(fixedTime)` in tests), `clockSourceProvider`.
- `shell/`: `PlaylistShell`, `shellPlaylistProvider(pid)`, `categorySidebarOpenProvider`, and (after R1) `selectedCategoryProvider`.
- Riverpod 3 notes: `Override` comes from `package:flutter_riverpod/misc.dart`; legacy `StateProvider`/`ChangeNotifierProvider` from `package:flutter_riverpod/legacy.dart`. Prefer `Notifier`/`AsyncNotifier`.

## 8.2 Cross-feature APIs
| File | Functions / widgets | Owner |
|---|---|---|
| `lib/player/player_api.dart` | `PlayRequest` (`LivePlayRequest`, `VodPlayRequest`, `CatchupPlayRequest`), `openPlayer(context, request)` | Player UI |
| `lib/features/live/live_api.dart` | `showChannelActions(context, playlistId, channelId, position, categoryId)`, `showCustomEpgPicker(...)` | TV Live |
| `lib/features/guide/guide_api.dart` | `showProgrammeDetails(context, playlistId, channelId, startUtc)`, `showArchiveSheet(...)`, `GuideOverlay` widget | TV Guide |
| `lib/features/details/details_api.dart` | `showMovieDetails`, `showSeriesDetails`, `showVodActions` | Movies & Shows |
| `lib/features/favorites/favorites_api.dart` | `showFavoriteTagsSheet(...)` | Search/Settings/Favorites |
| `lib/features/parental/parental_api.dart` | `ensureChannelUnlocked` | Search/Settings/Favorites |
| `lib/features/playlists/playlist_access.dart` | `ensurePlaylistUnlocked`, `openPlaylist` | Playlists |
| `lib/features/reminders/reminders_api.dart` | `toggleReminder(...)`, `ReminderListener` (wraps the router) | TV Guide |
| `lib/features/search/search_api.dart` | `openPersonSearch(...)` | Search/Settings/Favorites |
| `lib/features/multiview/multiview_api.dart` | `addToMultiview(...)` (P2) | Player UI |

All take plain ids so features never depend on each other's widgets. The functions load whatever they need through repositories.
