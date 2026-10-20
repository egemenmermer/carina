import 'package:drift/drift.dart';

/// Source kind of a playlist.
enum PlaylistType { xtream, m3u, m3uFile }

/// Category / item section.
enum SectionKind { live, movie, series }

/// Item types that can be favorited or tracked.
enum ItemType { channel, movie, series, episode }

/// A configured IPTV source. Passwords and PINs never live here: they are in
/// secure storage under `playlist.<id>.password` / `playlist.<id>.pin`.
@DataClassName('PlaylistRow')
class Playlists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get type => intEnum<PlaylistType>()();

  /// Xtream: `https://host:port` exactly as entered (no trailing slash).
  TextColumn get server => text().nullable()();
  TextColumn get username => text().nullable()();

  /// M3U: playlist URL, or the absolute file path for [PlaylistType.m3uFile].
  TextColumn get m3uUrl => text().nullable()();
  TextColumn get epgUrl => text().nullable()();
  IntColumn get epgShiftHours => integer().withDefault(const Constant(0))();

  /// 0 = never. Defaults to 3 days.
  IntColumn get reloadFrequencyHours =>
      integer().withDefault(const Constant(72))();
  TextColumn get userAgent => text().nullable()();

  /// Avatar id from the generated avatar catalog (see core/avatars).
  TextColumn get avatarId => text().nullable()();
  BoolColumn get hasAccessPin => boolean().withDefault(const Constant(false))();
  IntColumn get sortIndex => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastReloadAt => dateTime().nullable()();
  DateTimeColumn get lastEpgReloadAt => dateTime().nullable()();

  /// Raw Xtream `user_info` + `server_info` JSON from the last auth call.
  TextColumn get accountJson => text().nullable()();

  /// Header defaults from `#EXTM3U` (url-tvg, catchup…) as JSON.
  TextColumn get m3uHeaderJson => text().nullable()();
  IntColumn get liveCount => integer().withDefault(const Constant(0))();
  IntColumn get movieCount => integer().withDefault(const Constant(0))();
  IntColumn get seriesCount => integer().withDefault(const Constant(0))();
  IntColumn get programmeCount => integer().withDefault(const Constant(0))();
}

@DataClassName('CategoryRow')
@TableIndex(name: 'idx_categories_pl_kind', columns: {#playlistId, #kind})
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get playlistId =>
      integer().references(Playlists, #id, onDelete: KeyAction.cascade)();
  IntColumn get kind => intEnum<SectionKind>()();
  TextColumn get providerId => text()();
  TextColumn get name => text()();

  /// Local rename (survives reloads). Null = use [name].
  TextColumn get localName => text().nullable()();
  TextColumn get parentId => text().nullable()();

  /// Provider order.
  IntColumn get sortIndex => integer().withDefault(const Constant(0))();

  /// Custom order (null = not customized).
  IntColumn get customIndex => integer().nullable()();
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();
  BoolColumn get locked => boolean().withDefault(const Constant(false))();

  /// Set during an incremental import when the item disappeared upstream.
  BoolColumn get removed => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {playlistId, kind, providerId},
  ];
}

@DataClassName('ChannelRow')
@TableIndex(name: 'idx_channels_pl_cat', columns: {#playlistId, #categoryId})
@TableIndex(name: 'idx_channels_pl_num', columns: {#playlistId, #num})
class Channels extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get playlistId =>
      integer().references(Playlists, #id, onDelete: KeyAction.cascade)();

  /// Xtream stream_id, or a stable hash for M3U entries.
  TextColumn get providerId => text()();
  IntColumn get num => integer().nullable()();

  /// Name as delivered by the provider.
  TextColumn get name => text()();

  /// Name with quality tokens stripped (what the UI shows).
  TextColumn get displayName => text()();

  /// Quality badge parsed from the name: SD, HD, FHD, 4K, H265, HEVC, 50FPS.
  TextColumn get quality => text().nullable()();
  TextColumn get logo => text().nullable()();

  /// Provider category id (matches [Categories.providerId] with kind live).
  TextColumn get categoryId => text().nullable()();

  /// tvg-id / epg_channel_id from the provider.
  TextColumn get epgId => text().nullable()();

  /// Result of the EPG matcher (xmltv channel id), refreshed on EPG import.
  TextColumn get matchedEpgId => text().nullable()();

  /// Manual Custom EPG assignment (survives reloads, wins over matching).
  TextColumn get customEpgId => text().nullable()();

  /// Catch-up window in days (0 = no archive).
  IntColumn get archiveDays => integer().withDefault(const Constant(0))();

  /// M3U catch-up mode (default/append/shift/flussonic/xc) and source.
  TextColumn get catchupType => text().nullable()();
  TextColumn get catchupSource => text().nullable()();

  /// Full stream URL (M3U) — null for Xtream (built from providerId).
  TextColumn get streamUrl => text().nullable()();
  TextColumn get directSource => text().nullable()();

  /// Per-entry HTTP headers JSON ({"User-Agent":…,"Referer":…}).
  TextColumn get headersJson => text().nullable()();

  /// Entry needs DRM (KODIPROP license) — shown but not playable.
  BoolColumn get unsupported => boolean().withDefault(const Constant(false))();
  DateTimeColumn get added => dateTime().nullable()();
  IntColumn get sortIndex => integer().withDefault(const Constant(0))();
  IntColumn get customIndex => integer().nullable()();
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();
  BoolColumn get locked => boolean().withDefault(const Constant(false))();
  BoolColumn get removed => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {playlistId, providerId},
  ];
}

@DataClassName('MovieRow')
@TableIndex(name: 'idx_movies_pl_cat', columns: {#playlistId, #categoryId})
@TableIndex(name: 'idx_movies_pl_added', columns: {#playlistId, #added})
class Movies extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get playlistId =>
      integer().references(Playlists, #id, onDelete: KeyAction.cascade)();
  TextColumn get providerId => text()();
  TextColumn get name => text()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get poster => text().nullable()();

  /// Provider rating on a 0–10 scale.
  RealColumn get rating => real().nullable()();
  DateTimeColumn get added => dateTime().nullable()();
  TextColumn get containerExt => text().nullable()();
  IntColumn get tmdbId => integer().nullable()();
  IntColumn get year => integer().nullable()();
  TextColumn get streamUrl => text().nullable()();
  TextColumn get directSource => text().nullable()();
  TextColumn get headersJson => text().nullable()();
  IntColumn get sortIndex => integer().withDefault(const Constant(0))();
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();
  BoolColumn get removed => boolean().withDefault(const Constant(false))();

  /// Cached `get_vod_info` response (lazy, on detail open).
  TextColumn get infoJson => text().nullable()();
  DateTimeColumn get infoFetchedAt => dateTime().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {playlistId, providerId},
  ];
}

@DataClassName('SeriesRow')
@TableIndex(name: 'idx_series_pl_cat', columns: {#playlistId, #categoryId})
class Series extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get playlistId =>
      integer().references(Playlists, #id, onDelete: KeyAction.cascade)();
  TextColumn get providerId => text()();
  TextColumn get name => text()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get cover => text().nullable()();
  TextColumn get plot => text().nullable()();
  TextColumn get cast => text().nullable()();
  TextColumn get director => text().nullable()();
  TextColumn get genre => text().nullable()();
  TextColumn get releaseDate => text().nullable()();
  DateTimeColumn get lastModified => dateTime().nullable()();
  RealColumn get rating => real().nullable()();

  /// JSON list of backdrop URLs.
  TextColumn get backdropsJson => text().nullable()();
  TextColumn get youtubeTrailer => text().nullable()();
  IntColumn get tmdbId => integer().nullable()();
  IntColumn get year => integer().nullable()();
  IntColumn get sortIndex => integer().withDefault(const Constant(0))();
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();
  BoolColumn get removed => boolean().withDefault(const Constant(false))();

  /// Raw `get_series_info.info` JSON (lazy).
  TextColumn get infoJson => text().nullable()();
  DateTimeColumn get infoFetchedAt => dateTime().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {playlistId, providerId},
  ];
}

@DataClassName('SeasonRow')
class Seasons extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get playlistId =>
      integer().references(Playlists, #id, onDelete: KeyAction.cascade)();

  /// Provider series id.
  TextColumn get seriesId => text()();
  IntColumn get seasonNumber => integer()();
  TextColumn get name => text().nullable()();
  TextColumn get cover => text().nullable()();
  TextColumn get airDate => text().nullable()();
  IntColumn get episodeCount => integer().nullable()();
  TextColumn get overview => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {playlistId, seriesId, seasonNumber},
  ];
}

@DataClassName('EpisodeRow')
@TableIndex(name: 'idx_episodes_series', columns: {#playlistId, #seriesId})
class Episodes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get playlistId =>
      integer().references(Playlists, #id, onDelete: KeyAction.cascade)();

  /// Provider episode id.
  TextColumn get providerId => text()();

  /// Provider series id.
  TextColumn get seriesId => text()();
  IntColumn get season => integer()();
  IntColumn get episodeNum => integer()();
  TextColumn get title => text()();
  TextColumn get containerExt => text().nullable()();
  TextColumn get plot => text().nullable()();
  IntColumn get durationSecs => integer().nullable()();
  TextColumn get releaseDate => text().nullable()();
  TextColumn get image => text().nullable()();
  RealColumn get rating => real().nullable()();
  TextColumn get streamUrl => text().nullable()();
  TextColumn get directSource => text().nullable()();
  DateTimeColumn get added => dateTime().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {playlistId, providerId},
  ];
}

/// Channels declared in the XMLTV source.
@DataClassName('EpgChannelRow')
class EpgChannels extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get playlistId =>
      integer().references(Playlists, #id, onDelete: KeyAction.cascade)();
  TextColumn get epgId => text()();
  TextColumn get displayName => text()();

  /// Normalized display name (see data/text/normalize.dart).
  TextColumn get normalized => text()();
  TextColumn get icon => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {playlistId, epgId},
  ];
}

/// EPG programmes. Times are UTC epoch milliseconds with the playlist EPG
/// time shift already applied.
@DataClassName('ProgrammeRow')
@TableIndex(
  name: 'idx_programmes_channel_start',
  columns: {#playlistId, #epgChannelId, #start},
)
@TableIndex(name: 'idx_programmes_stop', columns: {#playlistId, #stop})
class Programmes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get playlistId =>
      integer().references(Playlists, #id, onDelete: KeyAction.cascade)();
  TextColumn get epgChannelId => text()();
  IntColumn get start => integer()();
  IntColumn get stop => integer()();
  TextColumn get title => text()();
  TextColumn get subTitle => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get category => text().nullable()();
  TextColumn get episodeNum => text().nullable()();
  TextColumn get icon => text().nullable()();
  TextColumn get rating => text().nullable()();
}

@DataClassName('FavoriteRow')
class Favorites extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get playlistId =>
      integer().references(Playlists, #id, onDelete: KeyAction.cascade)();
  IntColumn get itemType => intEnum<ItemType>()();
  TextColumn get providerId => text()();
  DateTimeColumn get addedAt => dateTime()();
  IntColumn get customIndex => integer().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {playlistId, itemType, providerId},
  ];
}

@DataClassName('FavoriteTagRow')
class FavoriteTags extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get playlistId =>
      integer().references(Playlists, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  IntColumn get sortIndex => integer().withDefault(const Constant(0))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {playlistId, name},
  ];
}

@DataClassName('FavoriteTagLinkRow')
class FavoriteTagLinks extends Table {
  IntColumn get favoriteId =>
      integer().references(Favorites, #id, onDelete: KeyAction.cascade)();
  IntColumn get tagId =>
      integer().references(FavoriteTags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {favoriteId, tagId};
}

/// Resume position / watched flag for movies and episodes.
@DataClassName('WatchStateRow')
class WatchStates extends Table {
  IntColumn get playlistId =>
      integer().references(Playlists, #id, onDelete: KeyAction.cascade)();
  IntColumn get itemType => intEnum<ItemType>()();
  TextColumn get providerId => text()();

  /// For episodes: the provider series id (drives Shows "Continue watching").
  TextColumn get seriesId => text().nullable()();
  IntColumn get positionMs => integer().withDefault(const Constant(0))();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  BoolColumn get watched => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {playlistId, itemType, providerId};
}

@DataClassName('LastWatchedLiveRow')
class LastWatchedLive extends Table {
  IntColumn get playlistId =>
      integer().references(Playlists, #id, onDelete: KeyAction.cascade)();
  TextColumn get channelId => text()();
  DateTimeColumn get watchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {playlistId, channelId};
}

@DataClassName('ReminderRow')
class Reminders extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get playlistId =>
      integer().references(Playlists, #id, onDelete: KeyAction.cascade)();

  /// Provider channel id.
  TextColumn get channelId => text()();
  TextColumn get channelName => text()();
  TextColumn get epgChannelId => text().nullable()();
  TextColumn get title => text()();

  /// UTC epoch ms.
  IntColumn get start => integer()();
  IntColumn get stop => integer()();
  BoolColumn get fired => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {playlistId, channelId, start},
  ];
}

enum DownloadStatus { queued, running, paused, done, failed }

@DataClassName('DownloadRow')
class Downloads extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get playlistId => integer().nullable()();
  IntColumn get itemType => intEnum<ItemType>()();
  TextColumn get providerId => text()();
  TextColumn get title => text()();
  TextColumn get url => text()();
  TextColumn get filePath => text()();
  IntColumn get status => intEnum<DownloadStatus>()();
  IntColumn get bytesTotal => integer().withDefault(const Constant(0))();
  IntColumn get bytesDone => integer().withDefault(const Constant(0))();
  TextColumn get error => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

@DataClassName('RecordingRow')
class Recordings extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get playlistId => integer().nullable()();
  TextColumn get channelId => text()();
  TextColumn get channelName => text()();
  TextColumn get title => text()();
  TextColumn get filePath => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endsAt => dateTime().nullable()();
  IntColumn get status => intEnum<DownloadStatus>()();
}

@DataClassName('TmdbCacheRow')
class TmdbCache extends Table {
  TextColumn get cacheKey => text()();
  TextColumn get json => text()();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {cacheKey};
}

/// Key/value settings. scope is `app` or `playlist:<id>`.
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get scope => text()();
  TextColumn get key => text()();
  TextColumn get json => text()();

  @override
  Set<Column> get primaryKey => {scope, key};
}
