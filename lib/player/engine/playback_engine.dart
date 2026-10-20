/// Playback engine contract (docs/ARCHITECTURE.md section 3).
///
/// The UI talks to video playback only through [PlaybackEngine]. The default
/// implementation is `MpvEngine` (media_kit / libmpv); widget and screenshot
/// tests use `FakeEngine` by overriding [playbackEngineFactoryProvider].
library;

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mpv_engine.dart';

/// Player profiles offered in the SWITCH PLAYER menu.
enum EngineProfile {
  /// Hardware decoding with an automatic fallback to software decoding.
  auto,

  /// `hwdec=auto-safe` (D3D11VA on Windows, VideoToolbox on macOS).
  hardware,

  /// `hwdec=no`.
  software,

  /// Small buffers for live TV, previews and multi-channel tiles.
  lowLatency,
}

/// Picture aspect handling.
enum AspectMode { auto, fill, crop, r16x9, r4x3 }

/// Deinterlacing: automatic (only interlaced frames), forced on, or off.
enum DeinterlaceMode { auto, on, off }

/// Filter used when deinterlacing is forced on.
enum DeinterlaceMethod { yadif, bwdif }

/// Live buffer size. VOD always uses a 30 s cache.
enum BufferPolicy { auto, small, medium, large, custom }

/// What happens when the preferred subtitle language is not available.
enum SubtitleFallback {
  /// Select the track the stream marks as default (if any).
  streamDefault,

  /// Show no subtitles.
  off,
}

/// Default User-Agent sent to IPTV servers.
const String kCarinaUserAgent = 'Carina/1.0 (Windows)';

/// User-Agent used when the playlist setting is "VLC".
const String kVlcUserAgent = 'VLC/3.0.20 LibVLC/3.0.20';

/// Value of [EngineOptions.preferredSubtitleLanguage] meaning "Disabled".
const String kSubtitlesDisabled = 'disabled';

/// What to play.
@immutable
class PlaybackSource {
  const PlaybackSource({
    required this.url,
    this.headers = const <String, String>{},
    this.userAgent,
    this.referer,
    this.isLive = false,
    this.title,
  });

  /// Stream URL or local file path.
  final String url;

  /// Per-entry HTTP headers (M3U `#EXTHTTP`, `#EXTVLCOPT`, `#KODIPROP`).
  final Map<String, String> headers;

  /// Per-entry User-Agent; wins over [EngineOptions.userAgent].
  final String? userAgent;

  /// Optional `Referer` header.
  final String? referer;

  /// Live TV (enables reconnects, live buffers and auto-retry).
  final bool isLive;

  /// Display title (not sent to the server).
  final String? title;

  PlaybackSource copyWith({
    String? url,
    Map<String, String>? headers,
    String? userAgent,
    String? referer,
    bool? isLive,
    String? title,
  }) {
    return PlaybackSource(
      url: url ?? this.url,
      headers: headers ?? this.headers,
      userAgent: userAgent ?? this.userAgent,
      referer: referer ?? this.referer,
      isLive: isLive ?? this.isLive,
      title: title ?? this.title,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PlaybackSource &&
      other.url == url &&
      const MapEquality<String, String>().equals(other.headers, headers) &&
      other.userAgent == userAgent &&
      other.referer == referer &&
      other.isLive == isLive &&
      other.title == title;

  @override
  int get hashCode => Object.hash(
    url,
    const MapEquality<String, String>().hash(headers),
    userAgent,
    referer,
    isLive,
    title,
  );

  /// Never prints the URL: IPTV URLs carry credentials.
  @override
  String toString() =>
      'PlaybackSource(title: $title, isLive: $isLive, '
      'headers: ${headers.length})';
}

/// Engine settings. They come from the per-playlist Player settings
///  and are applied to mpv before every `open()`.
@immutable
class EngineOptions {
  const EngineOptions({
    this.profile = EngineProfile.auto,
    this.bufferPolicy = BufferPolicy.auto,
    this.customBufferSeconds = 10,
    this.hardwareAcceleration = true,
    this.deinterlaceMode = DeinterlaceMode.auto,
    this.deinterlaceMethod = DeinterlaceMethod.bwdif,
    this.aspect = AspectMode.auto,
    this.preferredAudioLanguage,
    this.preferredSubtitleLanguage,
    this.subtitleFallback = SubtitleFallback.streamDefault,
    this.audioDelay = Duration.zero,
    this.subtitleDelay = Duration.zero,
    this.subtitleScale = 1.0,
    this.reconnectAttempts = 3,
    this.userAgent = kCarinaUserAgent,
    this.networkTimeoutSeconds = 15,
    this.muted = false,
  });

  /// Requested profile. Preview engines always start in
  /// [EngineProfile.lowLatency].
  final EngineProfile profile;

  /// Live buffer policy; see `liveCacheSecondsFor`.
  final BufferPolicy bufferPolicy;

  /// Seconds used with [BufferPolicy.custom] (clamped to 1–60).
  final int customBufferSeconds;

  /// Hardware acceleration on/off. Off forces `hwdec=no` for every profile
  /// and renders the video texture without the GPU.
  final bool hardwareAcceleration;

  final DeinterlaceMode deinterlaceMode;
  final DeinterlaceMethod deinterlaceMethod;

  /// Initial aspect mode.
  final AspectMode aspect;

  /// ISO 639 code or language name (`tr`, `tur`, `Turkish`); null keeps the
  /// stream default.
  final String? preferredAudioLanguage;

  /// Like [preferredAudioLanguage]; [kSubtitlesDisabled] turns subtitles off.
  final String? preferredSubtitleLanguage;

  /// Used when the preferred subtitle language is missing.
  final SubtitleFallback subtitleFallback;

  /// Default audio delay (−5 s … +5 s in the UI).
  final Duration audioDelay;

  /// Initial subtitle delay.
  final Duration subtitleDelay;

  /// Subtitle size: Small 0.75, Medium 1.0, Large 1.3 (mpv `sub-scale`).
  final double subtitleScale;

  /// Live auto-retry attempts before the error is shown (backoff 1, 2, 4 s).
  final int reconnectAttempts;

  /// Fallback User-Agent when the source has none.
  final String userAgent;

  /// mpv `network-timeout`.
  final int networkTimeoutSeconds;

  /// Start muted (preview engines are always muted at start).
  final bool muted;

  /// True when [preferredSubtitleLanguage] means "no subtitles".
  bool get subtitlesDisabled {
    final pref = preferredSubtitleLanguage?.trim().toLowerCase();
    return pref == kSubtitlesDisabled ||
        pref == 'off' ||
        pref == 'none' ||
        pref == 'no';
  }

  EngineOptions copyWith({
    EngineProfile? profile,
    BufferPolicy? bufferPolicy,
    int? customBufferSeconds,
    bool? hardwareAcceleration,
    DeinterlaceMode? deinterlaceMode,
    DeinterlaceMethod? deinterlaceMethod,
    AspectMode? aspect,
    Object? preferredAudioLanguage = _unset,
    Object? preferredSubtitleLanguage = _unset,
    SubtitleFallback? subtitleFallback,
    Duration? audioDelay,
    Duration? subtitleDelay,
    double? subtitleScale,
    int? reconnectAttempts,
    String? userAgent,
    int? networkTimeoutSeconds,
    bool? muted,
  }) {
    return EngineOptions(
      profile: profile ?? this.profile,
      bufferPolicy: bufferPolicy ?? this.bufferPolicy,
      customBufferSeconds: customBufferSeconds ?? this.customBufferSeconds,
      hardwareAcceleration: hardwareAcceleration ?? this.hardwareAcceleration,
      deinterlaceMode: deinterlaceMode ?? this.deinterlaceMode,
      deinterlaceMethod: deinterlaceMethod ?? this.deinterlaceMethod,
      aspect: aspect ?? this.aspect,
      preferredAudioLanguage: identical(preferredAudioLanguage, _unset)
          ? this.preferredAudioLanguage
          : preferredAudioLanguage as String?,
      preferredSubtitleLanguage: identical(preferredSubtitleLanguage, _unset)
          ? this.preferredSubtitleLanguage
          : preferredSubtitleLanguage as String?,
      subtitleFallback: subtitleFallback ?? this.subtitleFallback,
      audioDelay: audioDelay ?? this.audioDelay,
      subtitleDelay: subtitleDelay ?? this.subtitleDelay,
      subtitleScale: subtitleScale ?? this.subtitleScale,
      reconnectAttempts: reconnectAttempts ?? this.reconnectAttempts,
      userAgent: userAgent ?? this.userAgent,
      networkTimeoutSeconds:
          networkTimeoutSeconds ?? this.networkTimeoutSeconds,
      muted: muted ?? this.muted,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EngineOptions &&
      other.profile == profile &&
      other.bufferPolicy == bufferPolicy &&
      other.customBufferSeconds == customBufferSeconds &&
      other.hardwareAcceleration == hardwareAcceleration &&
      other.deinterlaceMode == deinterlaceMode &&
      other.deinterlaceMethod == deinterlaceMethod &&
      other.aspect == aspect &&
      other.preferredAudioLanguage == preferredAudioLanguage &&
      other.preferredSubtitleLanguage == preferredSubtitleLanguage &&
      other.subtitleFallback == subtitleFallback &&
      other.audioDelay == audioDelay &&
      other.subtitleDelay == subtitleDelay &&
      other.subtitleScale == subtitleScale &&
      other.reconnectAttempts == reconnectAttempts &&
      other.userAgent == userAgent &&
      other.networkTimeoutSeconds == networkTimeoutSeconds &&
      other.muted == muted;

  @override
  int get hashCode => Object.hash(
    profile,
    bufferPolicy,
    customBufferSeconds,
    hardwareAcceleration,
    deinterlaceMode,
    deinterlaceMethod,
    aspect,
    preferredAudioLanguage,
    preferredSubtitleLanguage,
    subtitleFallback,
    audioDelay,
    subtitleDelay,
    subtitleScale,
    reconnectAttempts,
    userAgent,
    networkTimeoutSeconds,
    muted,
  );
}

/// Track type.
enum EngineTrackKind { audio, subtitle }

/// An audio or subtitle track.
@immutable
class EngineTrack {
  const EngineTrack({
    required this.id,
    required this.kind,
    this.title,
    this.language,
    this.codec,
    this.channels,
    this.isDefault = false,
    this.isExternal = false,
  });

  /// mpv track id (`aid` / `sid` value).
  final String id;
  final EngineTrackKind kind;
  final String? title;

  /// Language tag as stored in the stream (`eng`, `tur`, `tr`…).
  final String? language;

  /// mpv codec name (`aac`, `ac3`, `subrip`…).
  final String? codec;

  /// Audio channel count.
  final int? channels;
  final bool isDefault;

  /// Added with `addExternalSubtitle` (or `sub-add`).
  final bool isExternal;

  String? get _codecLabel {
    final c = codec;
    return c == null || c.isEmpty ? null : codecDisplayName(c);
  }

  /// `AC3 5.1`, `AAC stereo`, `SRT`.
  String get technicalLabel {
    final parts = <String>[?_codecLabel, ?channelLayoutLabel(channels)];
    return parts.join(' ');
  }

  @override
  bool operator ==(Object other) =>
      other is EngineTrack &&
      other.id == id &&
      other.kind == kind &&
      other.title == title &&
      other.language == language &&
      other.codec == codec &&
      other.channels == channels &&
      other.isDefault == isDefault &&
      other.isExternal == isExternal;

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    title,
    language,
    codec,
    channels,
    isDefault,
    isExternal,
  );

  @override
  String toString() =>
      'EngineTrack(${kind.name} $id, $language, $title, $codec, '
      '${channels ?? '-'}ch${isDefault ? ', default' : ''}'
      '${isExternal ? ', external' : ''})';
}

/// Error categories shown by the player error overlay.
enum EngineErrorKind { http, network, timeout, ended, codec, unknown }

/// A playback failure with a readable (English) message. The UI may localize
/// it from [kind] and [statusCode].
@immutable
class EngineError {
  const EngineError({
    required this.kind,
    required this.message,
    this.statusCode,
    this.detail,
  });

  final EngineErrorKind kind;

  /// HTTP status for [EngineErrorKind.http] when known.
  final int? statusCode;

  /// Readable one-line message.
  final String message;

  /// The mpv log line that caused it, with URLs masked.
  final String? detail;

  /// Whether retrying can help (everything except unsupported codecs).
  bool get retryable => kind != EngineErrorKind.codec;

  @override
  bool operator ==(Object other) =>
      other is EngineError &&
      other.kind == kind &&
      other.statusCode == statusCode &&
      other.message == message &&
      other.detail == detail;

  @override
  int get hashCode => Object.hash(kind, statusCode, message, detail);

  @override
  String toString() =>
      'EngineError(${kind.name}${statusCode == null ? '' : ' $statusCode'}: '
      '$message)';
}

const Object _unset = Object();

/// Immutable playback state, emitted on [PlaybackEngine.stateStream].
@immutable
class EngineState {
  const EngineState({
    this.source,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.buffered = Duration.zero,
    this.playing = false,
    this.buffering = false,
    this.bufferingPercent = 0,
    this.completed = false,
    this.error,
    this.width = 0,
    this.height = 0,
    this.volume = 100,
    this.muted = false,
    this.rate = 1.0,
    this.reconnectAttempt = 0,
    this.audioTracks = const <EngineTrack>[],
    this.subtitleTracks = const <EngineTrack>[],
    this.selectedAudioId,
    this.selectedSubtitleId,
  });

  /// The source being played (null when idle).
  final PlaybackSource? source;
  final Duration position;

  /// Zero for live streams.
  final Duration duration;

  /// Demuxer cache end (`demuxer-cache-time`), for the progress bar.
  final Duration buffered;
  final bool playing;
  final bool buffering;

  /// 0–100 from `cache-buffering-state` ("Buffering 43%").
  final double bufferingPercent;
  final bool completed;
  final EngineError? error;

  /// Decoded video size; 0 until the first frame.
  final int width;
  final int height;

  /// 0–100.
  final double volume;
  final bool muted;
  final double rate;

  /// Live auto-retry in progress (1-based); 0 when not reconnecting.
  final int reconnectAttempt;
  final List<EngineTrack> audioTracks;
  final List<EngineTrack> subtitleTracks;
  final String? selectedAudioId;

  /// Null when subtitles are off.
  final String? selectedSubtitleId;

  bool get hasVideo => width > 0 && height > 0;
  bool get isLive => source?.isLive ?? false;
  bool get hasError => error != null;
  bool get reconnecting => reconnectAttempt > 0 && error == null;

  EngineTrack? get selectedAudioTrack =>
      audioTracks.firstWhereOrNull((t) => t.id == selectedAudioId);
  EngineTrack? get selectedSubtitleTrack =>
      subtitleTracks.firstWhereOrNull((t) => t.id == selectedSubtitleId);

  /// Nullable fields ([source], [error], [selectedAudioId],
  /// [selectedSubtitleId]) can be cleared by passing `null` explicitly.
  EngineState copyWith({
    Object? source = _unset,
    Duration? position,
    Duration? duration,
    Duration? buffered,
    bool? playing,
    bool? buffering,
    double? bufferingPercent,
    bool? completed,
    Object? error = _unset,
    int? width,
    int? height,
    double? volume,
    bool? muted,
    double? rate,
    int? reconnectAttempt,
    List<EngineTrack>? audioTracks,
    List<EngineTrack>? subtitleTracks,
    Object? selectedAudioId = _unset,
    Object? selectedSubtitleId = _unset,
  }) {
    return EngineState(
      source: identical(source, _unset)
          ? this.source
          : source as PlaybackSource?,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      buffered: buffered ?? this.buffered,
      playing: playing ?? this.playing,
      buffering: buffering ?? this.buffering,
      bufferingPercent: bufferingPercent ?? this.bufferingPercent,
      completed: completed ?? this.completed,
      error: identical(error, _unset) ? this.error : error as EngineError?,
      width: width ?? this.width,
      height: height ?? this.height,
      volume: volume ?? this.volume,
      muted: muted ?? this.muted,
      rate: rate ?? this.rate,
      reconnectAttempt: reconnectAttempt ?? this.reconnectAttempt,
      audioTracks: audioTracks ?? this.audioTracks,
      subtitleTracks: subtitleTracks ?? this.subtitleTracks,
      selectedAudioId: identical(selectedAudioId, _unset)
          ? this.selectedAudioId
          : selectedAudioId as String?,
      selectedSubtitleId: identical(selectedSubtitleId, _unset)
          ? this.selectedSubtitleId
          : selectedSubtitleId as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EngineState &&
      other.source == source &&
      other.position == position &&
      other.duration == duration &&
      other.buffered == buffered &&
      other.playing == playing &&
      other.buffering == buffering &&
      other.bufferingPercent == bufferingPercent &&
      other.completed == completed &&
      other.error == error &&
      other.width == width &&
      other.height == height &&
      other.volume == volume &&
      other.muted == muted &&
      other.rate == rate &&
      other.reconnectAttempt == reconnectAttempt &&
      const ListEquality<EngineTrack>().equals(
        other.audioTracks,
        audioTracks,
      ) &&
      const ListEquality<EngineTrack>().equals(
        other.subtitleTracks,
        subtitleTracks,
      ) &&
      other.selectedAudioId == selectedAudioId &&
      other.selectedSubtitleId == selectedSubtitleId;

  @override
  int get hashCode => Object.hashAll([
    source,
    position,
    duration,
    buffered,
    playing,
    buffering,
    bufferingPercent,
    completed,
    error,
    width,
    height,
    volume,
    muted,
    rate,
    reconnectAttempt,
    const ListEquality<EngineTrack>().hash(audioTracks),
    const ListEquality<EngineTrack>().hash(subtitleTracks),
    selectedAudioId,
    selectedSubtitleId,
  ]);

  @override
  String toString() =>
      'EngineState(playing: $playing, buffering: $buffering '
      '${bufferingPercent.toStringAsFixed(0)}%, position: $position, '
      'duration: $duration, ${width}x$height, completed: $completed, '
      'error: $error, reconnect: $reconnectAttempt, '
      'audio: ${audioTracks.length}, subtitles: ${subtitleTracks.length})';
}

@immutable
class EngineStats {
  const EngineStats({
    this.width = 0,
    this.height = 0,
    this.fps = 0,
    this.videoCodec,
    this.audioCodec,
    this.audioChannels = 0,
    this.sampleRate = 0,
    this.hwdec,
    this.cacheDurationSec = 0,
    this.bufferingPercent = 0,
    this.droppedFrames = 0,
    this.profile = EngineProfile.auto,
    this.fallbackHappened = false,
    this.videoBitrate,
    this.audioBitrate,
    this.deinterlacing = false,
  });

  /// `video-params/w`, `video-params/h`.
  final int width;
  final int height;

  /// `estimated-vf-fps`, falling back to `container-fps`.
  final double fps;

  /// Short codec names (`h264`, `hevc`, `aac`, `ac3`, `eac3`, `mp2`).
  final String? videoCodec;
  final String? audioCodec;
  final int audioChannels;
  final int sampleRate;

  /// `hwdec-current`: `videotoolbox`, `d3d11va`, `no`…
  final String? hwdec;

  /// `demuxer-cache-duration`.
  final double cacheDurationSec;

  /// `cache-buffering-state`.
  final double bufferingPercent;

  /// `frame-drop-count` + `decoder-frame-drop-count`.
  final int droppedFrames;

  /// Concrete profile in use (auto resolves to hardware, or software after
  /// a fallback).
  final EngineProfile profile;

  /// Auto profile fell back from hardware to software decoding.
  final bool fallbackHappened;

  /// Bits per second when mpv reports them.
  final int? videoBitrate;
  final int? audioBitrate;

  /// A deinterlacer is active (`deinterlace=yes` or a bwdif/yadif filter).
  final bool deinterlacing;

  /// Total bitrate in bits per second, if available.
  int? get bitrate => videoBitrate == null && audioBitrate == null
      ? null
      : (videoBitrate ?? 0) + (audioBitrate ?? 0);

  /// `SD`, `HD`, `FHD`, `4K` (null without video).
  String? get qualityLabel {
    if (width <= 0 || height <= 0) return null;
    if (width >= 3200 || height >= 2000) return '4K';
    if (width >= 1700 || height >= 1000) return 'FHD';
    if (width >= 1200 || height >= 700) return 'HD';
    return 'SD';
  }

  /// `1920×1080`.
  String? get sizeLabel => width > 0 && height > 0 ? '$width×$height' : null;

  EngineStats copyWith({
    int? width,
    int? height,
    double? fps,
    String? videoCodec,
    String? audioCodec,
    int? audioChannels,
    int? sampleRate,
    String? hwdec,
    double? cacheDurationSec,
    double? bufferingPercent,
    int? droppedFrames,
    EngineProfile? profile,
    bool? fallbackHappened,
    int? videoBitrate,
    int? audioBitrate,
    bool? deinterlacing,
  }) {
    return EngineStats(
      width: width ?? this.width,
      height: height ?? this.height,
      fps: fps ?? this.fps,
      videoCodec: videoCodec ?? this.videoCodec,
      audioCodec: audioCodec ?? this.audioCodec,
      audioChannels: audioChannels ?? this.audioChannels,
      sampleRate: sampleRate ?? this.sampleRate,
      hwdec: hwdec ?? this.hwdec,
      cacheDurationSec: cacheDurationSec ?? this.cacheDurationSec,
      bufferingPercent: bufferingPercent ?? this.bufferingPercent,
      droppedFrames: droppedFrames ?? this.droppedFrames,
      profile: profile ?? this.profile,
      fallbackHappened: fallbackHappened ?? this.fallbackHappened,
      videoBitrate: videoBitrate ?? this.videoBitrate,
      audioBitrate: audioBitrate ?? this.audioBitrate,
      deinterlacing: deinterlacing ?? this.deinterlacing,
    );
  }

  Map<String, Object?> toJson() => {
    'width': width,
    'height': height,
    'fps': fps,
    'videoCodec': videoCodec,
    'audioCodec': audioCodec,
    'audioChannels': audioChannels,
    'sampleRate': sampleRate,
    'hwdec': hwdec,
    'cacheDurationSec': cacheDurationSec,
    'bufferingPercent': bufferingPercent,
    'droppedFrames': droppedFrames,
    'profile': profile.name,
    'fallbackHappened': fallbackHappened,
    'videoBitrate': videoBitrate,
    'audioBitrate': audioBitrate,
    'deinterlacing': deinterlacing,
  };

  @override
  bool operator ==(Object other) =>
      other is EngineStats &&
      other.width == width &&
      other.height == height &&
      other.fps == fps &&
      other.videoCodec == videoCodec &&
      other.audioCodec == audioCodec &&
      other.audioChannels == audioChannels &&
      other.sampleRate == sampleRate &&
      other.hwdec == hwdec &&
      other.cacheDurationSec == cacheDurationSec &&
      other.bufferingPercent == bufferingPercent &&
      other.droppedFrames == droppedFrames &&
      other.profile == profile &&
      other.fallbackHappened == fallbackHappened &&
      other.videoBitrate == videoBitrate &&
      other.audioBitrate == audioBitrate &&
      other.deinterlacing == deinterlacing;

  @override
  int get hashCode => Object.hash(
    width,
    height,
    fps,
    videoCodec,
    audioCodec,
    audioChannels,
    sampleRate,
    hwdec,
    cacheDurationSec,
    bufferingPercent,
    droppedFrames,
    profile,
    fallbackHappened,
    videoBitrate,
    audioBitrate,
    deinterlacing,
  );

  @override
  String toString() => 'EngineStats(${toJson()})';
}

/// The player engine used by every playback surface (VOD, live, previews,
/// multi-channel tiles). Implementations must be safe to call after
/// [dispose] (calls become no-ops).
abstract class PlaybackEngine {
  /// Emits on every state change (position updates are throttled to ~4 Hz).
  /// New listeners do not get a replay; read [state] first.
  Stream<EngineState> get stateStream;
  EngineState get state;

  /// 1 Hz while listened to.
  Stream<EngineStats> get statsStream;

  /// The latest stats sample.
  EngineStats get stats;

  /// Options the engine was created with.
  EngineOptions get options;

  Future<void> open(
    PlaybackSource source, {
    Duration? start,
    bool autoplay = true,
  });
  Future<void> play();
  Future<void> pause();
  Future<void> playOrPause();
  Future<void> seek(Duration position);
  Future<void> stop();
  Future<void> setVolume(double v0to100);
  Future<void> setMuted(bool m);
  Future<void> setRate(double rate);
  List<EngineTrack> get audioTracks;
  List<EngineTrack> get subtitleTracks;
  Future<void> selectAudio(EngineTrack t);

  /// Null turns subtitles off.
  Future<void> selectSubtitle(EngineTrack? t);
  Future<void> addExternalSubtitle(String pathOrUri);
  Future<void> setAudioDelay(Duration d);
  Future<void> setSubtitleDelay(Duration d);
  Future<void> setSubtitleScale(double s);
  Future<void> setAspect(AspectMode m);
  Future<void> setDeinterlace(DeinterlaceMode m);

  /// Reopens the same source at the same position with another profile,
  /// without disposing the video widget.
  Future<void> switchProfile(EngineProfile p);
  EngineProfile get profile;

  /// Raw mpv property (null when unavailable).
  Future<String?> getProperty(String mpvName);

  /// The video surface, without any built-in controls.
  Widget buildVideo({Key? key, BoxFit fit = BoxFit.contain});

  /// Frees the native player. Idempotent.
  Future<void> dispose();
}

/// Creates engines. Tests override [playbackEngineFactoryProvider] with
/// `FakeEngineFactory`.
abstract class PlaybackEngineFactory {
  PlaybackEngine create({required EngineOptions options, bool preview = false});
}

/// The engine factory; defaults to [MpvEngineFactory].
final Provider<PlaybackEngineFactory> playbackEngineFactoryProvider =
    Provider<PlaybackEngineFactory>((ref) => const MpvEngineFactory());

/// `AAC`, `AC3`, `E-AC3`, `H.264`…
String codecDisplayName(String codec) {
  final c = codec.trim().toLowerCase();
  const names = <String, String>{
    'aac': 'AAC',
    'aac_latm': 'AAC',
    'ac3': 'AC3',
    'eac3': 'E-AC3',
    'mp2': 'MP2',
    'mp3': 'MP3',
    'opus': 'Opus',
    'vorbis': 'Vorbis',
    'flac': 'FLAC',
    'dts': 'DTS',
    'truehd': 'TrueHD',
    'pcm_s16le': 'PCM',
    'h264': 'H.264',
    'hevc': 'HEVC',
    'h265': 'HEVC',
    'mpeg2video': 'MPEG-2',
    'mpeg4': 'MPEG-4',
    'vp9': 'VP9',
    'av1': 'AV1',
    'subrip': 'SRT',
    'srt': 'SRT',
    'ass': 'ASS',
    'ssa': 'SSA',
    'webvtt': 'WebVTT',
    'mov_text': 'TX3G',
    'hdmv_pgs_subtitle': 'PGS',
    'dvb_subtitle': 'DVB',
    'dvd_subtitle': 'VobSub',
    'dvb_teletext': 'Teletext',
  };
  return names[c] ?? c.toUpperCase();
}

/// `mono`, `stereo`, `5.1`, `7.1`, `N ch`.
String? channelLayoutLabel(int? channels) {
  return switch (channels) {
    null || <= 0 => null,
    1 => 'mono',
    2 => 'stereo',
    6 => '5.1',
    8 => '7.1',
    final n => '$n ch',
  };
}
