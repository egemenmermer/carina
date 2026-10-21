/// Pure option → mpv property mapping. No media_kit imports here, so everything
/// is unit-testable.
library;

import 'package:flutter/painting.dart';

import '../../core/user_agent.dart';

import 'playback_engine.dart';
import 'track_language.dart';

const int _mib = 1024 * 1024;

/// VOD cache.
const int kVodCacheSeconds = 30;
const int kVodDemuxerMaxBytes = 150 * _mib;
const int kVodDemuxerMaxBackBytes = 50 * _mib;

/// Live cache limits (seconds come from the buffer policy).
const int kLiveDemuxerMaxBytes = 64 * _mib;
const int kLiveDemuxerMaxBackBytes = 16 * _mib;

/// Low-latency profile.
const int kLowLatencyCacheSeconds = 2;
const int kLowLatencyReadaheadSeconds = 1;
const int kLowLatencyDemuxerMaxBytes = 32 * _mib;

/// Codecs mpv may decode in hardware. mpv's default list leaves out
/// MPEG-2; it is added because the media_kit libmpv builds ship no
/// yadif/bwdif filter, so interlaced MPEG-2 can only be deinterlaced by the
/// GPU deinterlacer (`d3d11vpp` on Windows), which needs hardware frames.
const String kHwdecCodecs = 'h264,hevc,vc1,vp8,vp9,av1,prores,mpeg2video';

/// FFmpeg reconnect options for live HTTP streams.
const String kLiveReconnectOptions =
    'reconnect=1,reconnect_streamed=1,reconnect_on_network_error=1,'
    'reconnect_delay_max=5';

/// mpv's built-in low-latency profile. Every key it touches is listed in
/// [kLowLatencyValues] and [kNormalLatencyValues] so switching profiles at
/// runtime always restores a known state.
const String kMpvLowLatencyProfile = 'low-latency';

/// Values set by mpv's `[low-latency]` profile (libmpv 0.36).
const Map<String, String> kLowLatencyValues = {
  'audio-buffer': '0',
  'cache-pause': 'no',
  'demuxer-lavf-probe-info': 'nostreams',
  'demuxer-lavf-analyzeduration': '0.1',
  'interpolation': 'no',
  'video-latency-hacks': 'yes',
  'stream-buffer-size': '4096',
};

/// mpv defaults for the same keys.
const Map<String, String> kNormalLatencyValues = {
  'audio-buffer': '0.2',
  'cache-pause': 'yes',
  'demuxer-lavf-probe-info': 'auto',
  'demuxer-lavf-analyzeduration': '0',
  'interpolation': 'no',
  'video-latency-hacks': 'no',
  'stream-buffer-size': '131072',
};

/// Keys the engine must not set with `setProperty`:
/// `http-header-fields` is owned by media_kit's on_load/on_unload hooks and
/// is passed through `Media(httpHeaders:)` instead.
const Set<String> kMediaKitManagedProperties = {'http-header-fields'};

/// mpv list-option suffixes; the engine turns `name-op` keys into
/// `change-list name op value` commands (needed for `demuxer-lavf-o`, which
/// also carries media_kit's protocol whitelist and must not be replaced).
final RegExp kListOptionSuffix = RegExp(
  r'^(.+)-(add|append|remove|del|clr|set|pre)$',
);

/// The full, ordered set of mpv properties for one `open()`.
///
/// [profile] is the profile in use (defaults to [EngineOptions.profile]);
/// [forceSoftware] is set after an auto-profile hardware failure;
/// [deinterlaceAutoSupported] tells whether this libmpv accepts
/// `deinterlace=auto` (0.36 does not; the engine then detects interlaced
/// frames itself); [deinterlaceFilters] are the filters this libmpv build
/// has (the media_kit builds have none); [liveStallCount] drives the
/// adaptive live buffer.
///
/// Order matters: `profile` comes before the explicit overrides.
Map<String, String> mpvPropertiesFor(
  EngineOptions options,
  PlaybackSource source, {
  EngineProfile? profile,
  bool forceSoftware = false,
  bool deinterlaceAutoSupported = false,
  Set<DeinterlaceMethod> deinterlaceFilters = const {},
  int liveStallCount = 0,
}) {
  final effective = profile ?? options.profile;
  final lowLatency = effective == EngineProfile.lowLatency;
  final hwdec = hwdecFor(
    profile: effective,
    hardwareAcceleration: options.hardwareAcceleration,
    forceSoftware: forceSoftware,
  );
  final headers = httpHeadersFor(source);
  final props = <String, String>{
    // Decode audio even when the machine has no audio device (CI runners),
    // so audio-codec-name and audio-params are populated.
    'audio-fallback-to-null': 'yes',
    'hwdec': hwdec,
    'hwdec-codecs': kHwdecCodecs,
    // Network.
    'user-agent': userAgentFor(options, source),
    'http-header-fields': formatHeaderFields(headers),
    'network-timeout': '${options.networkTimeoutSeconds}',
    'stream-lavf-o': usesLiveReconnect(source) ? kLiveReconnectOptions : '',
    // Latency profile first, then explicit values (so the result is the same
    // whether or not `apply-profile` works on this libmpv).
    if (lowLatency) 'profile': kMpvLowLatencyProfile,
    ...(lowLatency ? kLowLatencyValues : kNormalLatencyValues),
    // Live MPEG-TS: libavformat analyzes 5 s of stream before the first
    // frame by default; 1 s keeps zapping inside the 1.2 s budget while
    // still detecting AC-3/E-AC-3 audio parameters.
    if (source.isLive && !lowLatency) 'demuxer-lavf-analyzeduration': '1',
    'vd-lavc-threads': lowLatency && hwdec != 'no' ? '1' : '0',
    'video-sync': 'audio',
    'untimed': 'no',
    'demuxer-lavf-o-remove': 'fflags',
    if (lowLatency) 'demuxer-lavf-o-add': 'fflags=+nobuffer',
    // Buffers. media_kit enables cache-on-disk, but libmpv has no cache
    // directory here ("Failed to create file cache" on every open).
    'cache-on-disk': 'no',
    ...bufferPropertiesFor(
      options,
      source,
      lowLatency: lowLatency,
      liveStallCount: liveStallCount,
    ),
    // Picture.
    ...deinterlacePropertiesFor(
      options.deinterlaceMode,
      options.deinterlaceMethod,
      autoSupported: deinterlaceAutoSupported,
      availableFilters: deinterlaceFilters,
    ),
    ...aspectPropertiesFor(options.aspect),
    // Tracks: reset the previous file's manual choice, then let mpv pick by
    // language; the engine refines the choice after the track list loads.
    ...trackPropertiesFor(options),
    // Delays and subtitle size.
    'audio-delay': formatSeconds(options.audioDelay),
    'sub-delay': formatSeconds(options.subtitleDelay),
    'sub-scale': formatScale(options.subtitleScale),
  };
  return props;
}

/// `auto-safe` for hardware / auto / low latency, `no` for software, when
/// hardware acceleration is disabled, or after a forced fallback.
String hwdecFor({
  required EngineProfile profile,
  required bool hardwareAcceleration,
  bool forceSoftware = false,
}) {
  if (!hardwareAcceleration || forceSoftware) return 'no';
  return profile == EngineProfile.software ? 'no' : 'auto-safe';
}

/// The concrete profile shown in stats: auto resolves to hardware, or to
/// software when decoding fell back or acceleration is off.
EngineProfile concreteProfile(
  EngineProfile requested, {
  required bool hardwareAcceleration,
  bool forceSoftware = false,
}) {
  if (requested == EngineProfile.lowLatency) return requested;
  if (requested == EngineProfile.software) return requested;
  if (!hardwareAcceleration || forceSoftware) return EngineProfile.software;
  return EngineProfile.hardware;
}

/// Source User-Agent, then a `User-Agent` entry in the source headers, then
/// the playlist setting.
String userAgentFor(EngineOptions options, PlaybackSource source) {
  final fromSource = source.userAgent?.trim();
  if (fromSource != null && fromSource.isNotEmpty) return fromSource;
  for (final entry in source.headers.entries) {
    if (entry.key.trim().toLowerCase() == 'user-agent' &&
        entry.value.trim().isNotEmpty) {
      return entry.value.trim();
    }
  }
  final fromOptions = options.userAgent.trim();
  // The Carina default names the OS the app is running on.
  if (fromOptions.isEmpty || fromOptions == kCarinaUserAgent) {
    return defaultUserAgent();
  }
  return fromOptions;
}

/// Referer plus per-entry headers (User-Agent excluded: it goes to mpv's
/// `user-agent`). Per-entry headers win over [PlaybackSource.referer];
/// header names are matched case-insensitively.
Map<String, String> httpHeadersFor(PlaybackSource source) {
  final out = <String, String>{};
  final lowerToKey = <String, String>{};
  void put(String name, String value) {
    final key = name.trim();
    final v = value.trim();
    if (key.isEmpty || v.isEmpty) return;
    final lower = key.toLowerCase();
    if (lower == 'user-agent') return;
    final existing = lowerToKey[lower];
    if (existing != null) out.remove(existing);
    lowerToKey[lower] = key;
    out[key] = v;
  }

  final referer = source.referer;
  if (referer != null) put('Referer', referer);
  source.headers.forEach(put);
  return out;
}

/// mpv string-list form of [headers] (`Name: value`, comma-separated,
/// commas and backslashes escaped).
String formatHeaderFields(Map<String, String> headers) {
  String escape(String s) => s.replaceAll(r'\', r'\\').replaceAll(',', r'\,');
  return headers.entries.map((e) => escape('${e.key}: ${e.value}')).join(',');
}

/// Live HTTP(S) streams other than HLS get FFmpeg's reconnect options.
bool usesLiveReconnect(PlaybackSource source) {
  if (!source.isLive) return false;
  final url = source.url.trim().toLowerCase();
  if (!(url.startsWith('http://') || url.startsWith('https://'))) return false;
  return !isHlsUrl(url);
}

/// `.m3u8` playlists (query strings ignored).
bool isHlsUrl(String url) {
  final path = url.split('?').first.split('#').first.toLowerCase();
  return path.endsWith('.m3u8') || path.endsWith('.m3u');
}

/// Live cache seconds for a policy. Auto adapts: 5 s, 10 s after one
/// rebuffering stall, 20 s after two or more.
int liveCacheSecondsFor(
  BufferPolicy policy, {
  int customSeconds = 10,
  int stallCount = 0,
}) {
  return switch (policy) {
    BufferPolicy.small => 3,
    BufferPolicy.medium => 8,
    BufferPolicy.large => 20,
    BufferPolicy.custom => customSeconds.clamp(1, 60),
    BufferPolicy.auto =>
      stallCount <= 0
          ? 5
          : stallCount == 1
          ? 10
          : 20,
  };
}

/// Cache properties: VOD 30 s / 150 MiB / 50 MiB back; live per policy;
/// low latency 2 s with 1 s readahead.
Map<String, String> bufferPropertiesFor(
  EngineOptions options,
  PlaybackSource source, {
  bool lowLatency = false,
  int liveStallCount = 0,
}) {
  if (lowLatency) {
    return {
      'cache': 'yes',
      'cache-secs': '$kLowLatencyCacheSeconds',
      'demuxer-readahead-secs': '$kLowLatencyReadaheadSeconds',
      'demuxer-max-bytes': '$kLowLatencyDemuxerMaxBytes',
      'demuxer-max-back-bytes': '0',
    };
  }
  if (source.isLive) {
    final seconds = liveCacheSecondsFor(
      options.bufferPolicy,
      customSeconds: options.customBufferSeconds,
      stallCount: liveStallCount,
    );
    return {
      'cache': 'yes',
      'cache-secs': '$seconds',
      'demuxer-readahead-secs': '1',
      'demuxer-max-bytes': '$kLiveDemuxerMaxBytes',
      'demuxer-max-back-bytes': '$kLiveDemuxerMaxBackBytes',
    };
  }
  return {
    'cache': 'yes',
    'cache-secs': '$kVodCacheSeconds',
    'demuxer-readahead-secs': '1',
    'demuxer-max-bytes': '$kVodDemuxerMaxBytes',
    'demuxer-max-back-bytes': '$kVodDemuxerMaxBackBytes',
  };
}

/// `deinterlace` + `vf`.
///
/// - auto: `deinterlace=auto` when supported, otherwise `deinterlace=no`
///   and the engine switches to `deinterlace=yes` when it sees interlaced
///   frames (`video-frame-info/interlaced`).
/// - on: the chosen filter (`bwdif` / `yadif`, field rate) when this libmpv
///   build has it (else the other one); without either, mpv's own
///   `deinterlace=yes`, which uses the GPU deinterlacer for hardware frames
///   (`d3d11vpp` on Windows).
/// - off: nothing.
Map<String, String> deinterlacePropertiesFor(
  DeinterlaceMode mode,
  DeinterlaceMethod method, {
  bool autoSupported = false,
  Set<DeinterlaceMethod> availableFilters = const {},
}) {
  switch (mode) {
    case DeinterlaceMode.auto:
      return {'deinterlace': autoSupported ? 'auto' : 'no', 'vf': ''};
    case DeinterlaceMode.off:
      return {'deinterlace': 'no', 'vf': ''};
    case DeinterlaceMode.on:
      final filter = availableFilters.contains(method)
          ? method
          : availableFilters.firstOrNull;
      if (filter == null) return {'deinterlace': 'yes', 'vf': ''};
      return {'deinterlace': 'no', 'vf': deinterlaceFilterFor(filter)};
  }
}

/// `bwdif=mode=send_field` / `yadif=mode=send_field`.
String deinterlaceFilterFor(DeinterlaceMethod method) =>
    '${method.name}=mode=send_field';

/// Aspect properties.
Map<String, String> aspectPropertiesFor(AspectMode mode) {
  return switch (mode) {
    AspectMode.auto => {
      'video-aspect-override': '-1',
      'panscan': '0.0',
      'keepaspect': 'yes',
    },
    AspectMode.fill => {
      'video-aspect-override': '-1',
      'panscan': '0.0',
      'keepaspect': 'no',
    },
    AspectMode.crop => {
      'video-aspect-override': '-1',
      'panscan': '1.0',
      'keepaspect': 'yes',
    },
    AspectMode.r16x9 => {
      'video-aspect-override': '16:9',
      'panscan': '0.0',
      'keepaspect': 'yes',
    },
    AspectMode.r4x3 => {
      'video-aspect-override': '4:3',
      'panscan': '0.0',
      'keepaspect': 'yes',
    },
  };
}

/// media_kit renders into a texture of the video's own size, so `keepaspect`
/// and `panscan` cannot fill or crop the widget; the Flutter fit does it.
/// 16:9 and 4:3 change the texture size through `video-aspect-override`.
BoxFit boxFitForAspect(AspectMode mode, {BoxFit base = BoxFit.contain}) {
  return switch (mode) {
    AspectMode.fill => BoxFit.fill,
    AspectMode.crop => BoxFit.cover,
    AspectMode.auto || AspectMode.r16x9 || AspectMode.r4x3 => base,
  };
}

/// Track reset + language lists + subtitle fallback.
Map<String, String> trackPropertiesFor(EngineOptions options) {
  final disabled = options.subtitlesDisabled;
  return {
    'aid': 'auto',
    'sid': disabled ? 'no' : 'auto',
    'alang': mpvLanguageList(options.preferredAudioLanguage).join(','),
    'slang': disabled
        ? ''
        : mpvLanguageList(options.preferredSubtitleLanguage).join(','),
    'subs-fallback': switch (options.subtitleFallback) {
      SubtitleFallback.streamDefault => 'default',
      SubtitleFallback.off => 'no',
    },
  };
}

/// Seconds with millisecond precision: `0.300`, `-1.250`.
String formatSeconds(Duration d) =>
    (d.inMicroseconds / Duration.microsecondsPerSecond).toStringAsFixed(3);

/// `sub-scale` value (clamped to 0.3–3.0).
String formatScale(double scale) => scale.clamp(0.3, 3.0).toStringAsFixed(2);
