/// The Settings tree: sections and the table of every row that
/// edits a typed setting key. Section widgets place these rows; tests
/// iterate over [LibrarySettingSpecs.all] to check that each row writes its
/// key.
library;

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../core/core.dart';
import '../../data/settings/settings_store.dart';
import '../../l10n/gen/app_localizations.dart';

/// Sections of the settings page. Playlist sections exist only inside a
/// playlist (`/p/<pid>/settings/<id>`); app sections everywhere. [name] is
/// the route id.
enum SettingsSection {
  // Playlist
  playlist,
  management,
  live,
  player,
  parental,
  // App
  general,
  tmdb,
  reminders,
  cache,
  diagnostics,
  about;

  static const List<SettingsSection> playlistSections = [
    playlist,
    management,
    live,
    player,
    parental,
  ];

  static const List<SettingsSection> appSections = [
    general,
    tmdb,
    reminders,
    cache,
    diagnostics,
    about,
  ];

  /// The route id (`/settings/<id>`).
  String get id => name;

  bool get isPlaylist => playlistSections.contains(this);

  static SettingsSection? fromId(String? id) =>
      values.firstWhereOrNull((s) => s.name == id);

  String label(L10n l) => switch (this) {
    playlist => l.librarySectionPlaylistGeneral,
    management => l.librarySectionManagement,
    live => l.librarySectionLive,
    player => l.librarySectionPlayer,
    parental => l.librarySectionParental,
    general => l.librarySectionGeneral,
    tmdb => l.librarySectionTmdb,
    reminders => l.librarySectionReminders,
    cache => l.librarySectionCache,
    diagnostics => l.librarySectionDiagnostics,
    about => l.librarySectionAbout,
  };

  IconData get icon => switch (this) {
    playlist => PhosphorIconsFill.slidersHorizontal,
    management => PhosphorIconsFill.listBullets,
    live => PhosphorIconsFill.television,
    player => PhosphorIconsFill.play,
    parental => PhosphorIconsFill.lockSimple,
    general => PhosphorIconsFill.gearSix,
    tmdb => PhosphorIconsFill.filmSlate,
    reminders => PhosphorIconsFill.bellSimple,
    cache => PhosphorIconsFill.database,
    diagnostics => PhosphorIconsFill.stethoscope,
    about => PhosphorIconsFill.info,
  };
}

/// One value of a chooser row.
@immutable
class SettingOption<T> {
  const SettingOption(this.value, this.label);

  final T value;
  final String label;
}

/// A settings row bound to a [SettingKey]: title, one-line description
/// (shown in the chooser) and the allowed values.
@immutable
class SettingSpec<T> {
  const SettingSpec({
    required this.section,
    required this.key,
    required this.title,
    required this.description,
    required this.options,
    this.formatOther,
    this.visibleWhen,
  });

  final SettingsSection section;
  final SettingKey<T> key;
  final String Function(L10n l) title;
  final String Function(L10n l) description;
  final List<SettingOption<T>> Function(L10n l) options;

  /// Label of a stored value that is not one of [options].
  final String Function(L10n l, T value)? formatOther;

  /// The row shows only when this is true (e.g. Custom buffer needs the
  /// Custom buffer policy).
  final bool Function(SettingsStore store, int? playlistId)? visibleWhen;

  /// Widget key of the row (`setting:<key id>`).
  ValueKey<String> get rowKey => ValueKey('setting:${key.id}');

  String valueLabel(L10n l, T value) =>
      options(l).firstWhereOrNull((o) => o.value == value)?.label ??
      formatOther?.call(l, value) ??
      '$value';

  bool isVisible(SettingsStore store, int? playlistId) =>
      visibleWhen?.call(store, playlistId) ?? true;
}

// ---------------------------------------------------------------------------
// Option helpers
// ---------------------------------------------------------------------------

List<SettingOption<bool>> _yesNo(L10n l) => [
  SettingOption(true, l.yes),
  SettingOption(false, l.no),
];

List<SettingOption<bool>> _showHide(L10n l) => [
  SettingOption(true, l.libraryShow),
  SettingOption(false, l.libraryHide),
];

List<SettingOption<bool>> _onOff(L10n l) => [
  SettingOption(true, l.on),
  SettingOption(false, l.off),
];

List<SettingOption<bool>> _enabledDisabled(L10n l) => [
  SettingOption(true, l.libraryEnabled),
  SettingOption(false, l.libraryDisabled),
];

List<SettingOption<String>> _engines(L10n l) => [
  SettingOption('auto', l.libraryAutomatic),
  SettingOption('hardware', l.libraryEngineHardware),
  SettingOption('software', l.libraryEngineSoftware),
  SettingOption('lowLatency', l.libraryEngineLowLatency),
];

/// `1.5 s` / `1,5 sn`.
String librarySecondsLabel(L10n l, num seconds) =>
    l.librarySecondsShort(NumberFormat('0.#', l.localeName).format(seconds));

/// ISO 639-2 codes offered for the default audio / subtitle language.
const List<String> libraryTrackLanguages = [
  'tur',
  'eng',
  'deu',
  'fra',
  'spa',
  'ita',
  'por',
  'nld',
  'rus',
  'ara',
  'fas',
  'kur',
  'aze',
  'ell',
  'pol',
  'jpn',
];

/// Name of an ISO 639-2 / 639-1 language code in the UI language.
String libraryLanguageName(L10n l, String code) => switch (code) {
  'tur' || 'tr' => l.libraryLangTurkish,
  'eng' || 'en' => l.libraryLangEnglish,
  'deu' || 'ger' || 'de' => l.libraryLangGerman,
  'fra' || 'fre' || 'fr' => l.libraryLangFrench,
  'spa' || 'es' => l.libraryLangSpanish,
  'ita' || 'it' => l.libraryLangItalian,
  'por' || 'pt' => l.libraryLangPortuguese,
  'nld' || 'dut' || 'nl' => l.libraryLangDutch,
  'rus' || 'ru' => l.libraryLangRussian,
  'ara' || 'ar' => l.libraryLangArabic,
  'fas' || 'per' || 'fa' => l.libraryLangPersian,
  'kur' || 'ku' => l.libraryLangKurdish,
  'aze' || 'az' => l.libraryLangAzerbaijani,
  'ell' || 'gre' || 'el' => l.libraryLangGreek,
  'pol' || 'pl' => l.libraryLangPolish,
  'jpn' || 'ja' => l.libraryLangJapanese,
  _ => code,
};

/// ISO 639-1 codes offered for the TMDb metadata language.
const List<String> libraryTmdbLanguages = [
  'en',
  'tr',
  'de',
  'fr',
  'es',
  'it',
  'pt',
  'nl',
  'ru',
  'ar',
];

/// Regions offered for age ratings.
const List<String> libraryTmdbRegions = [
  'TR',
  'US',
  'GB',
  'DE',
  'FR',
  'NL',
  'ES',
  'IT',
];

String libraryRegionName(L10n l, String code) => switch (code) {
  'TR' => l.libraryRegionTurkiye,
  'US' => l.libraryRegionUnitedStates,
  'GB' => l.libraryRegionUnitedKingdom,
  'DE' => l.libraryRegionGermany,
  'FR' => l.libraryRegionFrance,
  'NL' => l.libraryRegionNetherlands,
  'ES' => l.libraryRegionSpain,
  'IT' => l.libraryRegionItaly,
  _ => code,
};

String _signedMs(L10n l, int ms) {
  if (ms == 0) return l.libraryNoDelay;
  final sign = ms > 0 ? '+' : '−';
  return l.libraryMilliseconds('$sign${ms.abs()}');
}

// ---------------------------------------------------------------------------
// The table
// ---------------------------------------------------------------------------

/// Every settings row bound to a typed key, by section.
abstract final class LibrarySettingSpecs {
  // ----------------------------------------------------------- App · General
  static final language = SettingSpec<String>(
    section: SettingsSection.general,
    key: AppSettings.language,
    title: (l) => l.librarySetLanguage,
    description: (l) => l.librarySetLanguageHint,
    options: (l) => [
      SettingOption('system', l.librarySystemDefault),
      const SettingOption('en', 'English'),
      const SettingOption('tr', 'Türkçe'),
    ],
  );

  static final autoOpenLastPlaylist = SettingSpec<bool>(
    section: SettingsSection.general,
    key: AppSettings.autoOpenLastPlaylist,
    title: (l) => l.librarySetAutoOpen,
    description: (l) => l.librarySetAutoOpenHint,
    options: _yesNo,
  );

  static final startFullscreen = SettingSpec<bool>(
    section: SettingsSection.general,
    key: AppSettings.startFullscreen,
    title: (l) => l.librarySetStartFullscreen,
    description: (l) => l.librarySetStartFullscreenHint,
    options: _yesNo,
  );

  static final showClock = SettingSpec<bool>(
    section: SettingsSection.general,
    key: AppSettings.showClock,
    title: (l) => l.librarySetShowClock,
    description: (l) => l.librarySetShowClockHint,
    options: _showHide,
  );

  static final timeFormat = SettingSpec<String>(
    section: SettingsSection.general,
    key: AppSettings.timeFormat,
    title: (l) => l.librarySetTimeFormat,
    description: (l) => l.librarySetTimeFormatHint,
    options: (l) => [
      SettingOption('auto', l.libraryAutomatic),
      SettingOption('h12', l.libraryTime12h),
      SettingOption('h24', l.libraryTime24h),
    ],
  );

  // -------------------------------------------------------------- App · TMDb
  static final tmdbEnabled = SettingSpec<bool>(
    section: SettingsSection.tmdb,
    key: AppSettings.tmdbEnabled,
    title: (l) => l.librarySetTmdbEnabled,
    description: (l) => l.librarySetTmdbEnabledHint,
    options: _enabledDisabled,
  );

  static final tmdbLanguage = SettingSpec<String>(
    section: SettingsSection.tmdb,
    key: AppSettings.tmdbLanguage,
    title: (l) => l.librarySetTmdbLanguage,
    description: (l) => l.librarySetTmdbLanguageHint,
    options: (l) => [
      SettingOption('auto', l.libraryAutomaticAppLanguage),
      for (final code in libraryTmdbLanguages)
        SettingOption(code, libraryLanguageName(l, code)),
    ],
  );

  static final tmdbRegion = SettingSpec<String>(
    section: SettingsSection.tmdb,
    key: AppSettings.tmdbRegion,
    title: (l) => l.librarySetTmdbRegion,
    description: (l) => l.librarySetTmdbRegionHint,
    options: (l) => [
      for (final code in libraryTmdbRegions)
        SettingOption(code, libraryRegionName(l, code)),
    ],
  );

  // --------------------------------------------------------- App · Reminders
  static final reminderLead = SettingSpec<int>(
    section: SettingsSection.reminders,
    key: AppSettings.reminderLeadMinutes,
    title: (l) => l.librarySetReminderLead,
    description: (l) => l.librarySetReminderLeadHint,
    options: (l) => [
      for (final m in const [0, 1, 5, 10])
        SettingOption(m, l.libraryMinutesBefore(m)),
    ],
    formatOther: (l, m) => l.libraryMinutesBefore(m),
  );

  // -------------------------------------------------- Playlist · General
  static final initialTab = SettingSpec<String>(
    section: SettingsSection.playlist,
    key: PlaylistSettings.initialTab,
    title: (l) => l.librarySetInitialTab,
    description: (l) => l.librarySetInitialTabHint,
    options: (l) => [
      SettingOption('last', l.libraryLastUsed),
      SettingOption('movies', l.shellMovies),
      SettingOption('shows', l.shellShows),
      SettingOption('live', l.shellLive),
      SettingOption('guide', l.shellGuide),
    ],
  );

  static final continueWatchingOpensPlayer = SettingSpec<bool>(
    section: SettingsSection.playlist,
    key: PlaylistSettings.continueWatchingOpensPlayer,
    title: (l) => l.librarySetContinueOpensPlayer,
    description: (l) => l.librarySetContinueOpensPlayerHint,
    options: _yesNo,
  );

  static final showMovies = SettingSpec<bool>(
    section: SettingsSection.playlist,
    key: PlaylistSettings.showMovies,
    title: (l) => l.shellMovies,
    description: (l) => l.librarySetShowSectionHint(l.shellMovies),
    options: _showHide,
  );

  static final showShows = SettingSpec<bool>(
    section: SettingsSection.playlist,
    key: PlaylistSettings.showShows,
    title: (l) => l.shellShows,
    description: (l) => l.librarySetShowSectionHint(l.shellShows),
    options: _showHide,
  );

  static final showLive = SettingSpec<bool>(
    section: SettingsSection.playlist,
    key: PlaylistSettings.showLive,
    title: (l) => l.shellLive,
    description: (l) => l.librarySetShowSectionHint(l.shellLive),
    options: _showHide,
  );

  static final showGuide = SettingSpec<bool>(
    section: SettingsSection.playlist,
    key: PlaylistSettings.showGuide,
    title: (l) => l.shellGuide,
    description: (l) => l.librarySetShowSectionHint(l.shellGuide),
    options: _showHide,
  );

  // ------------------------------------------ Playlist · Playlist Management
  static final showLastWatched = SettingSpec<bool>(
    section: SettingsSection.management,
    key: PlaylistSettings.showLastWatched,
    title: (l) => l.librarySetShowLastWatched,
    description: (l) => l.librarySetShowLastWatchedHint,
    options: _yesNo,
  );

  static final showRecentlyAdded = SettingSpec<bool>(
    section: SettingsSection.management,
    key: PlaylistSettings.showRecentlyAdded,
    title: (l) => l.librarySetShowRecentlyAdded,
    description: (l) => l.librarySetShowRecentlyAddedHint,
    options: _yesNo,
  );

  static final showTrending = SettingSpec<bool>(
    section: SettingsSection.management,
    key: PlaylistSettings.showTrending,
    title: (l) => l.librarySetShowTrending,
    description: (l) => l.librarySetShowTrendingHint,
    options: _yesNo,
  );

  static final categoriesOrder = SettingSpec<String>(
    section: SettingsSection.management,
    key: PlaylistSettings.categoriesOrder,
    title: (l) => l.librarySetCategoriesOrder,
    description: (l) => l.librarySetCategoriesOrderHint,
    options: (l) => [
      SettingOption('playlist', l.libraryOrderPlaylist),
      SettingOption('name', l.libraryOrderName),
      SettingOption('custom', l.libraryOrderCustom),
    ],
  );

  static final channelsOrder = SettingSpec<String>(
    section: SettingsSection.management,
    key: PlaylistSettings.channelsOrder,
    title: (l) => l.librarySetChannelsOrder,
    description: (l) => l.librarySetChannelsOrderHint,
    options: (l) => [
      SettingOption('playlist', l.libraryOrderPlaylist),
      SettingOption('name', l.libraryOrderName),
      SettingOption('number', l.libraryOrderNumber),
      SettingOption('date', l.libraryOrderDateAdded),
    ],
  );

  static final favoritesOrder = SettingSpec<String>(
    section: SettingsSection.management,
    key: PlaylistSettings.favoritesOrder,
    title: (l) => l.librarySetFavoritesOrder,
    description: (l) => l.librarySetFavoritesOrderHint,
    options: (l) => [
      SettingOption('lastAdded', l.libraryOrderLastAdded),
      SettingOption('name', l.libraryOrderName),
      SettingOption('leastRecent', l.libraryOrderLeastRecent),
      SettingOption('custom', l.libraryOrderCustom),
    ],
  );

  static final continueWatchingOrder = SettingSpec<String>(
    section: SettingsSection.management,
    key: PlaylistSettings.continueWatchingOrder,
    title: (l) => l.librarySetContinueWatchingOrder,
    description: (l) => l.librarySetContinueWatchingOrderHint,
    options: (l) => [
      SettingOption('lastUpdated', l.libraryOrderLastWatched),
      SettingOption('lastAdded', l.libraryOrderLastAdded),
      SettingOption('name', l.libraryOrderName),
    ],
  );

  // -------------------------------------------- Playlist · TV Live & Guide
  static final liveLayout = SettingSpec<String>(
    section: SettingsSection.live,
    key: PlaylistSettings.liveLayout,
    title: (l) => l.librarySetLiveLayout,
    description: (l) => l.librarySetLiveLayoutHint,
    options: (l) => [
      SettingOption('horizontal', l.libraryLayoutHorizontal),
      SettingOption('vertical', l.libraryLayoutVertical),
    ],
  );

  static final livePreview = SettingSpec<bool>(
    section: SettingsSection.live,
    key: PlaylistSettings.livePreview,
    title: (l) => l.librarySetLivePreview,
    description: (l) => l.librarySetLivePreviewHint,
    options: _showHide,
  );

  static final previewStartsOn = SettingSpec<String>(
    section: SettingsSection.live,
    key: PlaylistSettings.previewStartsOn,
    title: (l) => l.librarySetPreviewStartsOn,
    description: (l) => l.librarySetPreviewStartsOnHint,
    options: (l) => [
      SettingOption('focus', l.libraryPreviewOnFocus),
      SettingOption('select', l.libraryPreviewOnSelect),
    ],
  );

  static final previewFocusDelay = SettingSpec<int>(
    section: SettingsSection.live,
    key: PlaylistSettings.previewFocusDelayMs,
    title: (l) => l.librarySetFocusDelay,
    description: (l) => l.librarySetFocusDelayHint,
    options: (l) => [
      SettingOption(0, l.libraryNoDelay),
      for (final ms in const [300, 500, 800, 1000, 1500, 2000, 3000])
        SettingOption(ms, librarySecondsLabel(l, ms / 1000)),
    ],
    formatOther: (l, ms) => librarySecondsLabel(l, ms / 1000),
  );

  static final previewAudio = SettingSpec<bool>(
    section: SettingsSection.live,
    key: PlaylistSettings.previewAudio,
    title: (l) => l.librarySetPreviewAudio,
    description: (l) => l.librarySetPreviewAudioHint,
    options: _onOff,
  );

  static final numberZapping = SettingSpec<bool>(
    section: SettingsSection.live,
    key: PlaylistSettings.numberZapping,
    title: (l) => l.librarySetNumberZapping,
    description: (l) => l.librarySetNumberZappingHint,
    options: _onOff,
  );

  static final wheelZaps = SettingSpec<bool>(
    section: SettingsSection.live,
    key: PlaylistSettings.wheelZaps,
    title: (l) => l.librarySetWheelZaps,
    description: (l) => l.librarySetWheelZapsHint,
    options: _onOff,
  );

  static final liveOutputFormat = SettingSpec<String>(
    section: SettingsSection.live,
    key: PlaylistSettings.liveOutputFormat,
    title: (l) => l.librarySetLiveFormat,
    description: (l) => l.librarySetLiveFormatHint,
    options: (l) => const [
      SettingOption('ts', 'MPEG-TS (.ts)'),
      SettingOption('m3u8', 'HLS (.m3u8)'),
    ],
  );

  static final guideZoom = SettingSpec<int>(
    section: SettingsSection.live,
    key: PlaylistSettings.guideZoomMinutes,
    title: (l) => l.librarySetGuideZoom,
    description: (l) => l.librarySetGuideZoomHint,
    options: (l) => [
      for (final m in const [30, 60, 90, 120])
        SettingOption(m, l.libraryGuideZoomMinutes(m)),
    ],
    formatOther: (l, m) => l.libraryGuideZoomMinutes(m),
  );

  // --------------------------------------------------------- Playlist · Player
  static final playerVod = SettingSpec<String>(
    section: SettingsSection.player,
    key: PlaylistSettings.playerVod,
    title: (l) => l.librarySetPlayerVod,
    description: (l) => l.librarySetPlayerVodHint,
    options: _engines,
  );

  static final playerLive = SettingSpec<String>(
    section: SettingsSection.player,
    key: PlaylistSettings.playerLive,
    title: (l) => l.librarySetPlayerLive,
    description: (l) => l.librarySetPlayerLiveHint,
    options: _engines,
  );

  static final playerArchive = SettingSpec<String>(
    section: SettingsSection.player,
    key: PlaylistSettings.playerArchive,
    title: (l) => l.librarySetPlayerArchive,
    description: (l) => l.librarySetPlayerArchiveHint,
    options: _engines,
  );

  static final hardwareAcceleration = SettingSpec<bool>(
    section: SettingsSection.player,
    key: PlaylistSettings.hardwareAcceleration,
    title: (l) => l.librarySetHardwareAcceleration,
    description: (l) => l.librarySetHardwareAccelerationHint,
    options: _enabledDisabled,
  );

  static final bufferPolicy = SettingSpec<String>(
    section: SettingsSection.player,
    key: PlaylistSettings.bufferPolicy,
    title: (l) => l.librarySetBuffer,
    description: (l) => l.librarySetBufferHint,
    options: (l) => [
      SettingOption('auto', l.libraryAutomatic),
      SettingOption('small', l.librarySizeSmall),
      SettingOption('medium', l.librarySizeMedium),
      SettingOption('large', l.librarySizeLarge),
      SettingOption('custom', l.libraryCustom),
    ],
  );

  static final bufferCustomSeconds = SettingSpec<int>(
    section: SettingsSection.player,
    key: PlaylistSettings.bufferCustomSeconds,
    title: (l) => l.librarySetBufferCustom,
    description: (l) => l.librarySetBufferCustomHint,
    options: (l) => [
      for (final s in const [1, 2, 3, 5, 8, 10, 15, 20, 30, 45, 60])
        SettingOption(s, librarySecondsLabel(l, s)),
    ],
    formatOther: (l, s) => librarySecondsLabel(l, s),
    visibleWhen: (store, pid) =>
        store.get(PlaylistSettings.bufferPolicy, playlistId: pid) == 'custom',
  );

  static final liveReconnectAttempts = SettingSpec<int>(
    section: SettingsSection.player,
    key: PlaylistSettings.liveReconnectAttempts,
    title: (l) => l.librarySetReconnect,
    description: (l) => l.librarySetReconnectHint,
    options: (l) => [
      for (final n in const [0, 1, 2, 3, 5, 10])
        SettingOption(n, l.libraryTimes(n)),
    ],
    formatOther: (l, n) => l.libraryTimes(n),
  );

  static final aspect = SettingSpec<String>(
    section: SettingsSection.player,
    key: PlaylistSettings.aspect,
    title: (l) => l.librarySetAspect,
    description: (l) => l.librarySetAspectHint,
    options: (l) => [
      SettingOption('auto', l.libraryAutomatic),
      SettingOption('fill', l.libraryAspectFill),
      SettingOption('crop', l.libraryAspectCrop),
      const SettingOption('r16x9', '16:9'),
      const SettingOption('r4x3', '4:3'),
    ],
  );

  static final deinterlace = SettingSpec<String>(
    section: SettingsSection.player,
    key: PlaylistSettings.deinterlace,
    title: (l) => l.librarySetDeinterlace,
    description: (l) => l.librarySetDeinterlaceHint,
    options: (l) => [
      SettingOption('auto', l.libraryAutomatic),
      SettingOption('on', l.on),
      SettingOption('off', l.off),
    ],
  );

  static final deinterlaceMethod = SettingSpec<String>(
    section: SettingsSection.player,
    key: PlaylistSettings.deinterlaceMethod,
    title: (l) => l.librarySetDeinterlaceMethod,
    description: (l) => l.librarySetDeinterlaceMethodHint,
    options: (l) => const [
      SettingOption('yadif', 'yadif'),
      SettingOption('bwdif', 'bwdif'),
    ],
  );

  static final resolutionIndicator = SettingSpec<String>(
    section: SettingsSection.player,
    key: PlaylistSettings.resolutionIndicator,
    title: (l) => l.librarySetResolutionIndicator,
    description: (l) => l.librarySetResolutionIndicatorHint,
    options: (l) => [
      SettingOption('label', l.libraryResolutionLabel),
      SettingOption('size', l.libraryResolutionSize),
    ],
  );

  static final audioLanguage = SettingSpec<String>(
    section: SettingsSection.player,
    key: PlaylistSettings.audioLanguage,
    title: (l) => l.librarySetAudioLanguage,
    description: (l) => l.librarySetAudioLanguageHint,
    options: (l) => [
      SettingOption('default', l.libraryDefaultTrack),
      for (final code in libraryTrackLanguages)
        SettingOption(code, libraryLanguageName(l, code)),
    ],
    formatOther: libraryLanguageName,
  );

  static final subtitleLanguage = SettingSpec<String>(
    section: SettingsSection.player,
    key: PlaylistSettings.subtitleLanguage,
    title: (l) => l.librarySetSubtitleLanguage,
    description: (l) => l.librarySetSubtitleLanguageHint,
    options: (l) => [
      SettingOption('default', l.libraryDefaultTrack),
      SettingOption('disabled', l.libraryDisabled),
      for (final code in libraryTrackLanguages)
        SettingOption(code, libraryLanguageName(l, code)),
    ],
    formatOther: libraryLanguageName,
  );

  static final subtitleSize = SettingSpec<String>(
    section: SettingsSection.player,
    key: PlaylistSettings.subtitleSize,
    title: (l) => l.librarySetSubtitleSize,
    description: (l) => l.librarySetSubtitleSizeHint,
    options: (l) => [
      SettingOption('small', l.librarySizeSmall),
      SettingOption('medium', l.librarySizeMedium),
      SettingOption('large', l.librarySizeLarge),
    ],
  );

  static final audioDelay = SettingSpec<int>(
    section: SettingsSection.player,
    key: PlaylistSettings.audioDelayMs,
    title: (l) => l.librarySetAudioDelay,
    description: (l) => l.librarySetAudioDelayHint,
    options: (l) => [
      for (final ms in const [-1000, -500, -250, -100, 0, 100, 250, 500, 1000])
        SettingOption(ms, _signedMs(l, ms)),
    ],
    formatOther: _signedMs,
  );

  static final autoPlayOnCloseProgress = SettingSpec<bool>(
    section: SettingsSection.player,
    key: PlaylistSettings.autoPlayOnCloseProgress,
    title: (l) => l.librarySetAutoPlayOnClose,
    description: (l) => l.librarySetAutoPlayOnCloseHint,
    options: _yesNo,
  );

  static final alwaysResume = SettingSpec<bool>(
    section: SettingsSection.player,
    key: PlaylistSettings.alwaysResume,
    title: (l) => l.librarySetAlwaysResume,
    description: (l) => l.librarySetAlwaysResumeHint,
    options: _yesNo,
  );

  static final autoplayNextEpisode = SettingSpec<bool>(
    section: SettingsSection.player,
    key: PlaylistSettings.autoplayNextEpisode,
    title: (l) => l.librarySetAutoplayNext,
    description: (l) => l.librarySetAutoplayNextHint,
    options: _yesNo,
  );

  static final userAgentMode = SettingSpec<String>(
    section: SettingsSection.player,
    key: PlaylistSettings.userAgentMode,
    title: (l) => l.librarySetUserAgent,
    description: (l) => l.librarySetUserAgentHint,
    options: (l) => [
      SettingOption('default', l.libraryDefault),
      const SettingOption('vlc', 'VLC'),
      SettingOption('custom', l.libraryCustom),
    ],
  );

  // ------------------------------------------------- Playlist · Parental
  static final parentalMode = SettingSpec<String>(
    section: SettingsSection.parental,
    key: PlaylistSettings.parentalMode,
    title: (l) => l.librarySetParentalMode,
    description: (l) => l.librarySetParentalModeHint,
    options: (l) => [
      SettingOption('ask', l.libraryParentalModeAsk),
      SettingOption('hide', l.libraryParentalModeHide),
    ],
  );

  /// Every keyed chooser row.
  static final List<SettingSpec<Object?>> all = [
    language,
    autoOpenLastPlaylist,
    startFullscreen,
    showClock,
    timeFormat,
    tmdbEnabled,
    tmdbLanguage,
    tmdbRegion,
    reminderLead,
    initialTab,
    continueWatchingOpensPlayer,
    showMovies,
    showShows,
    showLive,
    showGuide,
    showLastWatched,
    showRecentlyAdded,
    showTrending,
    categoriesOrder,
    channelsOrder,
    favoritesOrder,
    continueWatchingOrder,
    liveLayout,
    livePreview,
    previewStartsOn,
    previewFocusDelay,
    previewAudio,
    numberZapping,
    wheelZaps,
    liveOutputFormat,
    guideZoom,
    playerVod,
    playerLive,
    playerArchive,
    hardwareAcceleration,
    bufferPolicy,
    bufferCustomSeconds,
    liveReconnectAttempts,
    aspect,
    deinterlace,
    deinterlaceMethod,
    resolutionIndicator,
    audioLanguage,
    subtitleLanguage,
    subtitleSize,
    audioDelay,
    autoPlayOnCloseProgress,
    alwaysResume,
    autoplayNextEpisode,
    userAgentMode,
    parentalMode,
  ];
}
