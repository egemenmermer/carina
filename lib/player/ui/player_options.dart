/// Per-playlist Player settings → [EngineOptions].
library;

import '../../data/settings/settings_store.dart';
import '../engine/playback_engine.dart';

/// What the player is playing; picks the "Default player" setting.
enum PlayerKind {
  /// Movies and episodes (`playerVod`).
  vod,

  /// Live TV (`playerLive`).
  live,

  /// TV archive / catch-up (`playerArchive`).
  catchup,
}

/// Subtitle size choices of the SUBTITLES menu and the setting.
enum SubtitleSize {
  small(0.75),
  medium(1.0),
  large(1.3);

  const SubtitleSize(this.scale);

  /// mpv `sub-scale`.
  final double scale;

  static SubtitleSize fromSetting(String value) => switch (value) {
    'small' => SubtitleSize.small,
    'large' => SubtitleSize.large,
    _ => SubtitleSize.medium,
  };

  /// The size whose scale is closest to [scale].
  static SubtitleSize fromScale(double scale) {
    var best = SubtitleSize.medium;
    for (final s in SubtitleSize.values) {
      if ((s.scale - scale).abs() < (best.scale - scale).abs()) best = s;
    }
    return best;
  }
}

/// `auto` | `hardware` | `software` | `lowLatency` → [EngineProfile].
EngineProfile engineProfileFromSetting(String value) => switch (value) {
  'hardware' => EngineProfile.hardware,
  'software' => EngineProfile.software,
  'lowLatency' => EngineProfile.lowLatency,
  _ => EngineProfile.auto,
};

/// `auto` | `small` | `medium` | `large` | `custom` → [BufferPolicy].
BufferPolicy bufferPolicyFromSetting(String value) => switch (value) {
  'small' => BufferPolicy.small,
  'medium' => BufferPolicy.medium,
  'large' => BufferPolicy.large,
  'custom' => BufferPolicy.custom,
  _ => BufferPolicy.auto,
};

/// `auto` | `on` | `off` → [DeinterlaceMode].
DeinterlaceMode deinterlaceFromSetting(String value) => switch (value) {
  'on' => DeinterlaceMode.on,
  'off' => DeinterlaceMode.off,
  _ => DeinterlaceMode.auto,
};

/// `auto` | `fill` | `crop` | `r16x9` | `r4x3` → [AspectMode].
AspectMode aspectFromSetting(String value) => switch (value) {
  'fill' => AspectMode.fill,
  'crop' => AspectMode.crop,
  'r16x9' => AspectMode.r16x9,
  'r4x3' => AspectMode.r4x3,
  _ => AspectMode.auto,
};

/// The setting key of the default player for [kind].
SettingKey<String> defaultPlayerSetting(PlayerKind kind) => switch (kind) {
  PlayerKind.vod => PlaylistSettings.playerVod,
  PlayerKind.live => PlaylistSettings.playerLive,
  PlayerKind.catchup => PlaylistSettings.playerArchive,
};

/// Engine options for a player of [kind] in playlist [playlistId].
///
/// User-Agent and Referer are not set here: the stream URL resolver puts
/// them on each source (entry header > playlist agent > setting), and a
/// null agent falls back to the engine default.
EngineOptions playerEngineOptions(
  SettingsStore settings,
  int playlistId,
  PlayerKind kind,
) {
  T get<T>(SettingKey<T> key) => settings.get(key, playlistId: playlistId);
  final audioLanguage = get(PlaylistSettings.audioLanguage).trim();
  final subtitleLanguage = get(PlaylistSettings.subtitleLanguage).trim();
  final delayMs = get(PlaylistSettings.audioDelayMs).clamp(-5000, 5000);
  return EngineOptions(
    profile: engineProfileFromSetting(get(defaultPlayerSetting(kind))),
    bufferPolicy: bufferPolicyFromSetting(get(PlaylistSettings.bufferPolicy)),
    customBufferSeconds: get(PlaylistSettings.bufferCustomSeconds).clamp(1, 60),
    hardwareAcceleration: get(PlaylistSettings.hardwareAcceleration),
    deinterlaceMode: deinterlaceFromSetting(get(PlaylistSettings.deinterlace)),
    deinterlaceMethod: get(PlaylistSettings.deinterlaceMethod) == 'yadif'
        ? DeinterlaceMethod.yadif
        : DeinterlaceMethod.bwdif,
    aspect: aspectFromSetting(get(PlaylistSettings.aspect)),
    preferredAudioLanguage: audioLanguage.isEmpty || audioLanguage == 'default'
        ? null
        : audioLanguage,
    preferredSubtitleLanguage: switch (subtitleLanguage) {
      '' || 'default' => null,
      'disabled' => kSubtitlesDisabled,
      final code => code,
    },
    audioDelay: Duration(milliseconds: delayMs),
    subtitleScale: SubtitleSize.fromSetting(get(PlaylistSettings.subtitleSize))
        .scale,
    reconnectAttempts: get(PlaylistSettings.liveReconnectAttempts).clamp(0, 10),
  );
}
