import 'package:flutter_test/flutter_test.dart';
import 'package:carina/player/engine/playback_engine.dart';

void main() {
  group('EngineState', () {
    const error = EngineError(
      kind: EngineErrorKind.timeout,
      message: 'The stream did not respond in time (timeout).',
    );

    test('copyWith keeps unspecified fields', () {
      const s = EngineState(
        position: Duration(seconds: 5),
        width: 1280,
        height: 720,
        selectedAudioId: '2',
        error: error,
      );
      final next = s.copyWith(playing: true);
      expect(next.playing, isTrue);
      expect(next.position, const Duration(seconds: 5));
      expect(next.hasVideo, isTrue);
      expect(next.selectedAudioId, '2');
      expect(next.error, error);
    });

    test('copyWith can clear nullable fields', () {
      const s = EngineState(
        source: PlaybackSource(url: 'x'),
        error: error,
        selectedAudioId: '1',
        selectedSubtitleId: '3',
      );
      final cleared = s.copyWith(
        error: null,
        source: null,
        selectedAudioId: null,
        selectedSubtitleId: null,
      );
      expect(cleared.error, isNull);
      expect(cleared.source, isNull);
      expect(cleared.selectedAudioId, isNull);
      expect(cleared.selectedSubtitleId, isNull);
      expect(cleared.hasError, isFalse);
    });

    test('value equality', () {
      const track = EngineTrack(id: '1', kind: EngineTrackKind.audio);
      const a = EngineState(
        audioTracks: [track],
        position: Duration(seconds: 1),
      );
      const b = EngineState(
        audioTracks: [track],
        position: Duration(seconds: 1),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == a.copyWith(position: const Duration(seconds: 2)), isFalse);
    });

    test('derived getters', () {
      const s = EngineState(
        source: PlaybackSource(url: 'x', isLive: true),
        reconnectAttempt: 1,
        audioTracks: [
          EngineTrack(id: '1', kind: EngineTrackKind.audio, codec: 'aac'),
          EngineTrack(id: '2', kind: EngineTrackKind.audio, codec: 'ac3'),
        ],
        selectedAudioId: '2',
      );
      expect(s.isLive, isTrue);
      expect(s.reconnecting, isTrue);
      expect(s.hasVideo, isFalse);
      expect(s.selectedAudioTrack?.codec, 'ac3');
      expect(s.selectedSubtitleTrack, isNull);
    });
  });

  group('PlaybackSource', () {
    test('equality includes headers', () {
      const a = PlaybackSource(url: 'u', headers: {'Referer': 'r'});
      const b = PlaybackSource(url: 'u', headers: {'Referer': 'r'});
      const c = PlaybackSource(url: 'u', headers: {'Referer': 'x'});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
    });

    test('toString never contains the URL', () {
      const s = PlaybackSource(
        url: 'http://host/live/user/secret/1.ts',
        title: 'TRT 1',
      );
      expect(s.toString(), isNot(contains('secret')));
      expect(s.toString(), contains('TRT 1'));
    });
  });

  group('EngineOptions', () {
    test('defaults', () {
      const o = EngineOptions();
      expect(o.profile, EngineProfile.auto);
      expect(o.bufferPolicy, BufferPolicy.auto);
      expect(o.hardwareAcceleration, isTrue);
      expect(o.deinterlaceMode, DeinterlaceMode.auto);
      expect(o.deinterlaceMethod, DeinterlaceMethod.bwdif);
      expect(o.aspect, AspectMode.auto);
      expect(o.reconnectAttempts, 3);
      expect(o.networkTimeoutSeconds, 15);
      expect(o.userAgent, kCarinaUserAgent);
    });

    test('copyWith and clearing languages', () {
      const o = EngineOptions(preferredAudioLanguage: 'tr');
      final p = o.copyWith(profile: EngineProfile.software);
      expect(p.preferredAudioLanguage, 'tr');
      expect(p.profile, EngineProfile.software);
      expect(
        o.copyWith(preferredAudioLanguage: null).preferredAudioLanguage,
        isNull,
      );
      expect(o, const EngineOptions(preferredAudioLanguage: 'tr'));
    });
  });

  group('EngineTrack labels', () {
    test('technical labels', () {
      const ac3 = EngineTrack(
        id: '2',
        kind: EngineTrackKind.audio,
        codec: 'ac3',
        channels: 6,
      );
      const aac = EngineTrack(
        id: '1',
        kind: EngineTrackKind.audio,
        codec: 'aac',
        channels: 2,
      );
      const srt = EngineTrack(
        id: '3',
        kind: EngineTrackKind.subtitle,
        codec: 'subrip',
      );
      expect(ac3.technicalLabel, 'AC3 5.1');
      expect(aac.technicalLabel, 'AAC stereo');
      expect(srt.technicalLabel, 'SRT');
      expect(
        const EngineTrack(id: '9', kind: EngineTrackKind.audio).technicalLabel,
        '',
      );
    });

    test('codec and channel names', () {
      expect(codecDisplayName('eac3'), 'E-AC3');
      expect(codecDisplayName('h264'), 'H.264');
      expect(codecDisplayName('mpeg2video'), 'MPEG-2');
      expect(codecDisplayName('hdmv_pgs_subtitle'), 'PGS');
      expect(codecDisplayName('weird'), 'WEIRD');
      expect(channelLayoutLabel(1), 'mono');
      expect(channelLayoutLabel(8), '7.1');
      expect(channelLayoutLabel(3), '3 ch');
      expect(channelLayoutLabel(null), isNull);
      expect(channelLayoutLabel(0), isNull);
    });
  });

  group('EngineStats', () {
    test('quality labels', () {
      expect(const EngineStats(width: 720, height: 576).qualityLabel, 'SD');
      expect(const EngineStats(width: 1280, height: 720).qualityLabel, 'HD');
      expect(const EngineStats(width: 1920, height: 1080).qualityLabel, 'FHD');
      expect(const EngineStats(width: 3840, height: 2160).qualityLabel, '4K');
      expect(const EngineStats().qualityLabel, isNull);
      expect(const EngineStats().sizeLabel, isNull);
    });

    test('bitrate and json', () {
      const s = EngineStats(videoBitrate: 4000000, audioBitrate: 192000);
      expect(s.bitrate, 4192000);
      expect(const EngineStats().bitrate, isNull);
      expect(s.toJson()['profile'], 'auto');
      expect(s.copyWith(fallbackHappened: true).fallbackHappened, isTrue);
    });
  });

  test('EngineError', () {
    const e = EngineError(
      kind: EngineErrorKind.http,
      statusCode: 403,
      message: 'm',
    );
    expect(e.retryable, isTrue);
    expect(
      const EngineError(kind: EngineErrorKind.codec, message: 'm').retryable,
      isFalse,
    );
    expect(e.toString(), contains('403'));
  });
}
