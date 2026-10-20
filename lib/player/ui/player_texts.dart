/// Localized labels for engine values (profiles, tracks, errors, delays).
library;

import 'package:flutter/foundation.dart';

import '../../l10n/gen/app_localizations.dart';
import '../engine/playback_engine.dart';
import '../engine/track_language.dart';
import 'player_controller.dart';
import 'player_options.dart';

/// `D3D11` on Windows, `VideoToolbox` on macOS.
String hardwareApiName([TargetPlatform? platform]) =>
    (platform ?? defaultTargetPlatform) == TargetPlatform.macOS
    ? 'VideoToolbox'
    : 'D3D11';

/// SWITCH PLAYER labels.
String profileLabel(L10n l10n, EngineProfile profile) => switch (profile) {
  EngineProfile.auto => l10n.playerProfileAuto,
  EngineProfile.hardware => l10n.playerProfileHardware(hardwareApiName()),
  EngineProfile.software => l10n.playerProfileSoftware,
  EngineProfile.lowLatency => l10n.playerProfileLowLatency,
};

const Map<String, (String, String)> _languageNames = {
  'tr': ('Turkish', 'Türkçe'),
  'en': ('English', 'İngilizce'),
  'de': ('German', 'Almanca'),
  'fr': ('French', 'Fransızca'),
  'es': ('Spanish', 'İspanyolca'),
  'it': ('Italian', 'İtalyanca'),
  'pt': ('Portuguese', 'Portekizce'),
  'nl': ('Dutch', 'Felemenkçe'),
  'ru': ('Russian', 'Rusça'),
  'ar': ('Arabic', 'Arapça'),
  'el': ('Greek', 'Yunanca'),
  'pl': ('Polish', 'Lehçe'),
  'ja': ('Japanese', 'Japonca'),
  'zh': ('Chinese', 'Çince'),
  'ko': ('Korean', 'Korece'),
  'ku': ('Kurdish', 'Kürtçe'),
  'az': ('Azerbaijani', 'Azerice'),
};

/// The language name of a track tag in the UI language (`tur` → `Turkish`
/// / `Türkçe`), the tag itself when unknown, or null without a tag.
String? languageName(L10n l10n, String? tag) {
  final code = canonicalLanguage(tag);
  if (code == null) {
    final t = tag?.trim();
    return t == null || t.isEmpty || t == 'und' ? null : t.toUpperCase();
  }
  final names = _languageNames[code];
  if (names == null) return code.toUpperCase();
  return l10n.localeName.startsWith('tr') ? names.$2 : names.$1;
}

/// Row label of an audio / subtitle track: its title, else the language,
/// else `Track 2`.
String trackLabel(L10n l10n, EngineTrack track) {
  final title = track.title?.trim();
  if (title != null && title.isNotEmpty) return title;
  return languageName(l10n, track.language) ?? l10n.playerTrackNumber(track.id);
}

/// Right-hand detail of a track row: `AC3 5.1`, `SRT · External`.
String? trackDetail(L10n l10n, EngineTrack track) {
  final parts = <String>[
    if (track.technicalLabel.isNotEmpty) track.technicalLabel,
    if (track.isExternal) l10n.playerExternalTrack,
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// `+0.3 s`, `−1.2 s`, `0.0 s` (Turkish: `+0,3 sn`).
String delayLabel(L10n l10n, Duration d) {
  final seconds = d.inMilliseconds / 1000;
  final sign = seconds > 0.04 ? '+' : (seconds < -0.04 ? '−' : '');
  var number = seconds.abs().toStringAsFixed(1);
  if (l10n.localeName.startsWith('tr')) number = number.replaceAll('.', ',');
  return l10n.playerSeconds('$sign$number');
}

String subtitleSizeLabel(L10n l10n, SubtitleSize size) => switch (size) {
  SubtitleSize.small => l10n.playerSizeSmall,
  SubtitleSize.medium => l10n.playerSizeMedium,
  SubtitleSize.large => l10n.playerSizeLarge,
};

String aspectLabel(L10n l10n, AspectMode mode) => switch (mode) {
  AspectMode.auto => l10n.playerAspectAuto,
  AspectMode.fill => l10n.playerAspectFill,
  AspectMode.crop => l10n.playerAspectCrop,
  AspectMode.r16x9 => '16:9',
  AspectMode.r4x3 => '4:3',
};

String deinterlaceLabel(L10n l10n, DeinterlaceMode mode) => switch (mode) {
  DeinterlaceMode.auto => l10n.playerDeinterlaceAuto,
  DeinterlaceMode.on => l10n.playerDeinterlaceOn,
  DeinterlaceMode.off => l10n.playerDeinterlaceOff,
};

/// `0.5×`, `1.25×`; 1.0 is "Normal".
String rateLabel(L10n l10n, double rate) {
  if ((rate - 1.0).abs() < 0.001) return l10n.playerSpeedNormal;
  final text = rate == rate.roundToDouble()
      ? rate.toStringAsFixed(0)
      : rate.toString();
  return '$text×';
}

/// The readable message of the error overlay.
String failureMessage(L10n l10n, PlayerFailure failure) {
  switch (failure.kind) {
    case PlayerFailureKind.notFound:
      return l10n.playerErrorNotFound;
    case PlayerFailureKind.noCatchup:
      return l10n.playerErrorNoCatchup;
    case PlayerFailureKind.unsupported:
      return l10n.playerErrorUnsupported;
    case PlayerFailureKind.missingCredentials:
      return l10n.playerErrorCredentials;
    case PlayerFailureKind.noStreamUrl:
      return l10n.playerErrorNoUrl;
    case PlayerFailureKind.playlistNotFound:
      return l10n.playerErrorPlaylistGone;
    case PlayerFailureKind.engine:
      final e = failure.engineError;
      if (e == null) return l10n.playerErrorUnknown;
      return switch (e.kind) {
        EngineErrorKind.http => switch (e.statusCode) {
          401 => l10n.playerErrorHttp401,
          403 => l10n.playerErrorHttp403,
          404 => l10n.playerErrorHttp404,
          null => l10n.playerErrorHttp,
          final s when s >= 500 => l10n.playerErrorHttpServer(s),
          final s => l10n.playerErrorHttpStatus(s),
        },
        EngineErrorKind.network => l10n.playerErrorNetwork,
        EngineErrorKind.timeout => l10n.playerErrorTimeout,
        EngineErrorKind.ended => l10n.playerErrorEnded,
        EngineErrorKind.codec => l10n.playerErrorCodec,
        EngineErrorKind.unknown => l10n.playerErrorUnknown,
      };
  }
}

/// `42m`, `1h 49m`.
String shortRuntime(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h == 0) return '${d.inMinutes < 1 ? 1 : m}m';
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

/// Technical chips of the info panel: `HD`, `stereo`, `H.264`, `25 fps`
/// from the live stats, else from the provider metadata.
List<String> technicalChips(
  EngineStats stats, {
  List<String> fallback = const [],
}) {
  final chips = <String>[
    ?stats.qualityLabel,
    ?channelLayoutLabel(stats.audioChannels),
    if (stats.videoCodec != null && stats.videoCodec!.isNotEmpty)
      codecDisplayName(stats.videoCodec!),
    if (stats.fps > 0) '${stats.fps.round()} fps',
  ];
  return chips.isEmpty ? fallback : chips;
}
