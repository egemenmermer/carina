/// Values are stored JSON-encoded in the `settings` table. Enums are stored by
/// name as strings, so the key type is `String` and the allowed values are
/// listed in the doc comment.
library;

enum SettingScope { app, playlist }

class SettingKey<T> {
  const SettingKey(this.id, this.defaultValue, this.scope);

  final String id;
  final T defaultValue;
  final SettingScope scope;

  @override
  String toString() => 'SettingKey(${scope.name}.$id)';
}

/// App-level settings (scope `app`).
abstract final class AppSettings {
  /// `system` | `en` | `tr`
  static const language = SettingKey<String>(
    'language',
    'system',
    SettingScope.app,
  );
  static const autoOpenLastPlaylist = SettingKey<bool>(
    'autoOpenLastPlaylist',
    false,
    SettingScope.app,
  );
  static const lastPlaylistId = SettingKey<int?>(
    'lastPlaylistId',
    null,
    SettingScope.app,
  );
  static const startFullscreen = SettingKey<bool>(
    'startFullscreen',
    false,
    SettingScope.app,
  );
  static const showClock = SettingKey<bool>(
    'showClock',
    true,
    SettingScope.app,
  );

  /// `auto` (from locale; Turkish = 24h) | `h12` | `h24`
  static const timeFormat = SettingKey<String>(
    'timeFormat',
    'auto',
    SettingScope.app,
  );

  /// Metadata language for TMDb (`auto` = app language).
  static const tmdbLanguage = SettingKey<String>(
    'tmdbLanguage',
    'auto',
    SettingScope.app,
  );

  /// Region for age ratings (fallback US).
  static const tmdbRegion = SettingKey<String>(
    'tmdbRegion',
    'TR',
    SettingScope.app,
  );
  static const tmdbEnabled = SettingKey<bool>(
    'tmdbEnabled',
    false,
    SettingScope.app,
  );

  /// Comma-separated ISO 639 codes, e.g. `tur,eng`.
  static const openSubtitlesLanguages = SettingKey<String>(
    'openSubtitlesLanguages',
    'tur,eng',
    SettingScope.app,
  );
  static const downloadFolder = SettingKey<String?>(
    'downloadFolder',
    null,
    SettingScope.app,
  );

  /// `one` | `multiple`
  static const concurrentDownloads = SettingKey<String>(
    'concurrentDownloads',
    'one',
    SettingScope.app,
  );

  /// Minutes before the programme start: 0 / 1 / 5 / 10.
  static const reminderLeadMinutes = SettingKey<int>(
    'reminderLeadMinutes',
    1,
    SettingScope.app,
  );

  /// Saved window bounds `{x,y,w,h,maximized}`.
  static const windowBounds = SettingKey<Map<String, Object?>?>(
    'windowBounds',
    null,
    SettingScope.app,
  );
}

/// Playlist-scoped settings (scope `playlist:<id>`).
abstract final class PlaylistSettings {
  /// `movies` | `shows` | `live` | `guide` | `last`
  static const initialTab = SettingKey<String>(
    'initialTab',
    'last',
    SettingScope.playlist,
  );
  static const lastTab = SettingKey<String?>(
    'lastTab',
    null,
    SettingScope.playlist,
  );
  static const continueWatchingOpensPlayer = SettingKey<bool>(
    'continueWatchingOpensPlayer',
    true,
    SettingScope.playlist,
  );
  static const showMovies = SettingKey<bool>(
    'showMovies',
    true,
    SettingScope.playlist,
  );
  static const showShows = SettingKey<bool>(
    'showShows',
    true,
    SettingScope.playlist,
  );
  static const showLive = SettingKey<bool>(
    'showLive',
    true,
    SettingScope.playlist,
  );
  static const showGuide = SettingKey<bool>(
    'showGuide',
    true,
    SettingScope.playlist,
  );

  // Playlist management
  static const showLastWatched = SettingKey<bool>(
    'showLastWatched',
    true,
    SettingScope.playlist,
  );
  static const showRecentlyAdded = SettingKey<bool>(
    'showRecentlyAdded',
    true,
    SettingScope.playlist,
  );
  static const showTrending = SettingKey<bool>(
    'showTrending',
    true,
    SettingScope.playlist,
  );

  /// `playlist` | `name` | `custom`
  static const categoriesOrder = SettingKey<String>(
    'categoriesOrder',
    'playlist',
    SettingScope.playlist,
  );

  /// `playlist` | `name` | `number` | `date`
  static const channelsOrder = SettingKey<String>(
    'channelsOrder',
    'playlist',
    SettingScope.playlist,
  );

  /// `lastAdded` | `name` | `leastRecent` | `custom`
  static const favoritesOrder = SettingKey<String>(
    'favoritesOrder',
    'lastAdded',
    SettingScope.playlist,
  );

  /// `lastUpdated` | `lastAdded` | `name`
  static const continueWatchingOrder = SettingKey<String>(
    'continueWatchingOrder',
    'lastUpdated',
    SettingScope.playlist,
  );

  // TV Live & TV Guide
  /// `horizontal` | `vertical`
  static const liveLayout = SettingKey<String>(
    'liveLayout',
    'horizontal',
    SettingScope.playlist,
  );
  static const livePreview = SettingKey<bool>(
    'livePreview',
    true,
    SettingScope.playlist,
  );

  /// `focus` | `select`
  static const previewStartsOn = SettingKey<String>(
    'previewStartsOn',
    'focus',
    SettingScope.playlist,
  );

  /// Milliseconds, 0–3000.
  static const previewFocusDelayMs = SettingKey<int>(
    'previewFocusDelayMs',
    800,
    SettingScope.playlist,
  );
  static const previewAudio = SettingKey<bool>(
    'previewAudio',
    false,
    SettingScope.playlist,
  );

  /// Minutes visible per screen width: 30 / 60 / 90 / 120.
  static const guideZoomMinutes = SettingKey<int>(
    'guideZoomMinutes',
    120,
    SettingScope.playlist,
  );
  static const numberZapping = SettingKey<bool>(
    'numberZapping',
    true,
    SettingScope.playlist,
  );
  static const wheelZaps = SettingKey<bool>(
    'wheelZaps',
    true,
    SettingScope.playlist,
  );

  /// `ts` | `m3u8` for Xtream live URLs.
  static const liveOutputFormat = SettingKey<String>(
    'liveOutputFormat',
    'ts',
    SettingScope.playlist,
  );

  // Player
  /// `auto` | `hardware` | `software` | `lowLatency`
  static const playerVod = SettingKey<String>(
    'playerVod',
    'auto',
    SettingScope.playlist,
  );
  static const playerLive = SettingKey<String>(
    'playerLive',
    'auto',
    SettingScope.playlist,
  );
  static const playerArchive = SettingKey<String>(
    'playerArchive',
    'auto',
    SettingScope.playlist,
  );

  /// `auto` | `small` | `medium` | `large` | `custom`
  static const bufferPolicy = SettingKey<String>(
    'bufferPolicy',
    'auto',
    SettingScope.playlist,
  );
  static const bufferCustomSeconds = SettingKey<int>(
    'bufferCustomSeconds',
    10,
    SettingScope.playlist,
  );
  static const hardwareAcceleration = SettingKey<bool>(
    'hardwareAcceleration',
    true,
    SettingScope.playlist,
  );

  /// `auto` | `on` | `off`
  static const deinterlace = SettingKey<String>(
    'deinterlace',
    'auto',
    SettingScope.playlist,
  );

  /// `yadif` | `bwdif`
  static const deinterlaceMethod = SettingKey<String>(
    'deinterlaceMethod',
    'bwdif',
    SettingScope.playlist,
  );

  /// `auto` | `fill` | `crop` | `r16x9` | `r4x3`
  static const aspect = SettingKey<String>(
    'aspect',
    'auto',
    SettingScope.playlist,
  );

  /// `label` (HD/FHD/4K) | `size` (1920×1080)
  static const resolutionIndicator = SettingKey<String>(
    'resolutionIndicator',
    'label',
    SettingScope.playlist,
  );
  static const autoPlayOnCloseProgress = SettingKey<bool>(
    'autoPlayOnCloseProgress',
    true,
    SettingScope.playlist,
  );

  /// ISO 639-2 code or `default`.
  static const audioLanguage = SettingKey<String>(
    'audioLanguage',
    'default',
    SettingScope.playlist,
  );

  /// ISO 639-2 code, `default` or `disabled`.
  static const subtitleLanguage = SettingKey<String>(
    'subtitleLanguage',
    'default',
    SettingScope.playlist,
  );

  /// `small` | `medium` | `large`
  static const subtitleSize = SettingKey<String>(
    'subtitleSize',
    'medium',
    SettingScope.playlist,
  );

  /// Milliseconds, −5000…5000.
  static const audioDelayMs = SettingKey<int>(
    'audioDelayMs',
    0,
    SettingScope.playlist,
  );

  /// `default` | `vlc` | `custom`
  static const userAgentMode = SettingKey<String>(
    'userAgentMode',
    'default',
    SettingScope.playlist,
  );
  static const userAgentCustom = SettingKey<String>(
    'userAgentCustom',
    '',
    SettingScope.playlist,
  );
  static const referer = SettingKey<String>(
    'referer',
    '',
    SettingScope.playlist,
  );
  static const liveReconnectAttempts = SettingKey<int>(
    'liveReconnectAttempts',
    3,
    SettingScope.playlist,
  );
  static const alwaysResume = SettingKey<bool>(
    'alwaysResume',
    false,
    SettingScope.playlist,
  );
  static const autoplayNextEpisode = SettingKey<bool>(
    'autoplayNextEpisode',
    true,
    SettingScope.playlist,
  );

  // Parental control
  /// `ask` (ask PIN on open) | `hide` (hide locked content entirely)
  static const parentalMode = SettingKey<String>(
    'parentalMode',
    'ask',
    SettingScope.playlist,
  );
}
