import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/core/user_agent.dart';
import 'package:carina/player/engine/engine_mapping.dart';
import 'package:carina/player/engine/playback_engine.dart';

void main() {
  const vod = PlaybackSource(url: 'http://host:8080/movie/u/p/3001.mkv');
  const liveTs = PlaybackSource(
    url: 'http://host:8080/live/u/p/1001.ts',
    isLive: true,
  );
  const liveHls = PlaybackSource(
    url: 'https://host/live/1005/index.m3u8?token=x',
    isLive: true,
  );
  const localTs = PlaybackSource(url: '/media/h264_aac.ts', isLive: true);

  group('always-on properties', () {
    for (final profile in EngineProfile.values) {
      for (final source in [vod, liveTs, liveHls, localTs]) {
        test('${profile.name} / ${source.url}', () {
          final p = mpvPropertiesFor(EngineOptions(profile: profile), source);
          expect(p['audio-fallback-to-null'], 'yes');
          expect(p['hwdec-codecs'], contains('mpeg2video'));
          expect(p['cache-on-disk'], 'no');
          expect(p['network-timeout'], '15');
          expect(p['user-agent'], defaultUserAgent());
          expect(p['cache'], 'yes');
          expect(p['video-sync'], 'audio');
          expect(p['untimed'], 'no');
          expect(p['aid'], 'auto');
          expect(p['demuxer-lavf-o-remove'], 'fflags');
          // Never replace media_kit's demuxer-lavf-o (protocol whitelist).
          expect(p.containsKey('demuxer-lavf-o'), isFalse);
          // Every key of mpv's low-latency profile is always set, so a
          // runtime profile switch restores a known state.
          for (final key in kLowLatencyValues.keys) {
            expect(p.containsKey(key), isTrue, reason: key);
          }
          expect(p.containsKey('vd-lavc-threads'), isTrue);
        });
      }
    }

    test('audio-fallback-to-null is the first property', () {
      final p = mpvPropertiesFor(const EngineOptions(), vod);
      expect(p.keys.first, 'audio-fallback-to-null');
    });
  });

  group('profiles → hwdec', () {
    test('hardware and auto use auto-safe', () {
      for (final profile in [EngineProfile.hardware, EngineProfile.auto]) {
        final p = mpvPropertiesFor(EngineOptions(profile: profile), vod);
        expect(p['hwdec'], 'auto-safe', reason: profile.name);
      }
    });

    test('software uses hwdec=no', () {
      final p = mpvPropertiesFor(
        const EngineOptions(profile: EngineProfile.software),
        vod,
      );
      expect(p['hwdec'], 'no');
    });

    test('profile argument overrides options.profile', () {
      final p = mpvPropertiesFor(
        const EngineOptions(profile: EngineProfile.hardware),
        vod,
        profile: EngineProfile.software,
      );
      expect(p['hwdec'], 'no');
    });

    test('hardware acceleration off forces hwdec=no everywhere', () {
      for (final profile in EngineProfile.values) {
        final p = mpvPropertiesFor(
          EngineOptions(profile: profile, hardwareAcceleration: false),
          liveTs,
        );
        expect(p['hwdec'], 'no', reason: profile.name);
      }
    });

    test('auto fallback forces software', () {
      final p = mpvPropertiesFor(
        const EngineOptions(),
        vod,
        forceSoftware: true,
      );
      expect(p['hwdec'], 'no');
    });

    test('hwdecFor / concreteProfile', () {
      expect(
        hwdecFor(profile: EngineProfile.lowLatency, hardwareAcceleration: true),
        'auto-safe',
      );
      expect(
        concreteProfile(EngineProfile.auto, hardwareAcceleration: true),
        EngineProfile.hardware,
      );
      expect(
        concreteProfile(
          EngineProfile.auto,
          hardwareAcceleration: true,
          forceSoftware: true,
        ),
        EngineProfile.software,
      );
      expect(
        concreteProfile(EngineProfile.hardware, hardwareAcceleration: false),
        EngineProfile.software,
      );
      expect(
        concreteProfile(EngineProfile.lowLatency, hardwareAcceleration: true),
        EngineProfile.lowLatency,
      );
    });
  });

  group('low latency', () {
    final p = mpvPropertiesFor(
      const EngineOptions(profile: EngineProfile.lowLatency),
      liveTs,
    );

    test('default values', () {
      expect(p['profile'], 'low-latency');
      expect(p['cache'], 'yes');
      expect(p['cache-secs'], '2');
      expect(p['demuxer-readahead-secs'], '1');
      expect(p['video-sync'], 'audio');
      expect(p['untimed'], 'no');
      expect(p['demuxer-lavf-o-add'], 'fflags=+nobuffer');
      expect(p['hwdec'], 'auto-safe');
    });

    test('mpv low-latency profile values are explicit', () {
      kLowLatencyValues.forEach((k, v) => expect(p[k], v, reason: k));
      expect(p['vd-lavc-threads'], '1');
      expect(p['demuxer-max-back-bytes'], '0');
      expect(p['demuxer-max-bytes'], '${32 * 1024 * 1024}');
    });

    test('profile comes before the explicit overrides', () {
      final keys = p.keys.toList();
      final profileIndex = keys.indexOf('profile');
      expect(profileIndex, greaterThanOrEqualTo(0));
      for (final key in [
        'cache-secs',
        'cache-pause',
        'vd-lavc-threads',
        'demuxer-lavf-o-add',
      ]) {
        expect(keys.indexOf(key), greaterThan(profileIndex), reason: key);
      }
      // fflags is removed first so it is present exactly once.
      expect(
        keys.indexOf('demuxer-lavf-o-remove'),
        lessThan(keys.indexOf('demuxer-lavf-o-add')),
      );
    });

    test('software low latency keeps multithreaded decoding', () {
      final sw = mpvPropertiesFor(
        const EngineOptions(
          profile: EngineProfile.lowLatency,
          hardwareAcceleration: false,
        ),
        liveTs,
      );
      expect(sw['hwdec'], 'no');
      expect(sw['vd-lavc-threads'], '0');
    });

    test('other profiles restore the mpv defaults', () {
      final normal = mpvPropertiesFor(const EngineOptions(), vod);
      expect(normal.containsKey('profile'), isFalse);
      expect(normal.containsKey('demuxer-lavf-o-add'), isFalse);
      kNormalLatencyValues.forEach((k, v) => expect(normal[k], v, reason: k));
      expect(normal['vd-lavc-threads'], '0');
    });

    test('live streams analyze 1 s before the first frame', () {
      final live = mpvPropertiesFor(const EngineOptions(), liveTs);
      expect(live['demuxer-lavf-analyzeduration'], '1');
      final vodProps = mpvPropertiesFor(const EngineOptions(), vod);
      expect(vodProps['demuxer-lavf-analyzeduration'], '0');
      final low = mpvPropertiesFor(
        const EngineOptions(profile: EngineProfile.lowLatency),
        liveTs,
      );
      expect(low['demuxer-lavf-analyzeduration'], '0.1');
    });
  });

  group('buffers', () {
    test('VOD: 30 s, 150 MiB, 50 MiB back', () {
      final p = mpvPropertiesFor(const EngineOptions(), vod);
      expect(p['cache-secs'], '30');
      expect(p['demuxer-max-bytes'], '${150 * 1024 * 1024}');
      expect(p['demuxer-max-back-bytes'], '${50 * 1024 * 1024}');
    });

    test('VOD ignores the live buffer policy', () {
      final p = mpvPropertiesFor(
        const EngineOptions(bufferPolicy: BufferPolicy.small),
        vod,
      );
      expect(p['cache-secs'], '30');
    });

    test('live policies', () {
      String secs(BufferPolicy policy, {int custom = 10}) => mpvPropertiesFor(
        EngineOptions(bufferPolicy: policy, customBufferSeconds: custom),
        liveTs,
      )['cache-secs']!;
      expect(secs(BufferPolicy.small), '3');
      expect(secs(BufferPolicy.medium), '8');
      expect(secs(BufferPolicy.large), '20');
      expect(secs(BufferPolicy.custom, custom: 12), '12');
      expect(secs(BufferPolicy.custom, custom: 0), '1');
      expect(secs(BufferPolicy.custom, custom: 99), '60');
      expect(secs(BufferPolicy.auto), '5');
    });

    test('auto adapts after rebuffering stalls', () {
      expect(liveCacheSecondsFor(BufferPolicy.auto), 5);
      expect(liveCacheSecondsFor(BufferPolicy.auto, stallCount: 1), 10);
      expect(liveCacheSecondsFor(BufferPolicy.auto, stallCount: 2), 20);
      expect(liveCacheSecondsFor(BufferPolicy.auto, stallCount: 9), 20);
      expect(liveCacheSecondsFor(BufferPolicy.small, stallCount: 9), 3);
      final p = mpvPropertiesFor(
        const EngineOptions(),
        liveTs,
        liveStallCount: 1,
      );
      expect(p['cache-secs'], '10');
    });

    test('live limits', () {
      final p = mpvPropertiesFor(const EngineOptions(), liveTs);
      expect(p['demuxer-max-bytes'], '${64 * 1024 * 1024}');
      expect(p['demuxer-max-back-bytes'], '${16 * 1024 * 1024}');
    });
  });

  group('network', () {
    test('reconnect options only for live HTTP TS', () {
      expect(
        mpvPropertiesFor(const EngineOptions(), liveTs)['stream-lavf-o'],
        kLiveReconnectOptions,
      );
      expect(
        mpvPropertiesFor(const EngineOptions(), liveHls)['stream-lavf-o'],
        '',
      );
      expect(
        mpvPropertiesFor(const EngineOptions(), localTs)['stream-lavf-o'],
        '',
      );
      expect(mpvPropertiesFor(const EngineOptions(), vod)['stream-lavf-o'], '');
      expect(
        kLiveReconnectOptions,
        'reconnect=1,reconnect_streamed=1,reconnect_on_network_error=1,'
        'reconnect_delay_max=5',
      );
    });

    test('isHlsUrl ignores queries', () {
      expect(isHlsUrl('http://x/a.m3u8?token=1'), isTrue);
      expect(isHlsUrl('http://x/a.M3U8'), isTrue);
      expect(isHlsUrl('http://x/a.ts?x=.m3u8'), isFalse);
    });

    test('custom network timeout', () {
      final p = mpvPropertiesFor(
        const EngineOptions(networkTimeoutSeconds: 4),
        vod,
      );
      expect(p['network-timeout'], '4');
    });

    test('user agent precedence', () {
      const options = EngineOptions(userAgent: kVlcUserAgent);
      expect(userAgentFor(options, vod), kVlcUserAgent);
      expect(
        userAgentFor(options, vod.copyWith(userAgent: 'Custom/2')),
        'Custom/2',
      );
      expect(
        userAgentFor(
          options,
          vod.copyWith(headers: {'user-agent': 'FromHeader/1'}),
        ),
        'FromHeader/1',
      );
      expect(
        userAgentFor(const EngineOptions(userAgent: ' '), vod),
        defaultUserAgent(),
      );
      expect(kCarinaUserAgent, 'Carina/1.0 (Windows)');
      expect(kVlcUserAgent, 'VLC/3.0.20 LibVLC/3.0.20');
    });

    test('headers: referer + per-entry, user agent excluded', () {
      final source = liveTs.copyWith(
        referer: 'http://ref.example/',
        headers: {'X-Token': 'abc', 'User-Agent': 'UA/1', 'Origin': 'o'},
      );
      expect(httpHeadersFor(source), {
        'Referer': 'http://ref.example/',
        'X-Token': 'abc',
        'Origin': 'o',
      });
      final p = mpvPropertiesFor(const EngineOptions(), source);
      expect(
        p['http-header-fields'],
        'Referer: http://ref.example/,X-Token: abc,Origin: o',
      );
      expect(p['user-agent'], 'UA/1');
    });

    test('per-entry referer wins over the source referer', () {
      final source = vod.copyWith(
        referer: 'http://a/',
        headers: {'referer': 'http://b/'},
      );
      expect(httpHeadersFor(source), {'referer': 'http://b/'});
    });

    test('empty headers and escaping', () {
      expect(
        mpvPropertiesFor(const EngineOptions(), vod)['http-header-fields'],
        '',
      );
      expect(
        formatHeaderFields({'Cookie': r'a=1, b=2\x'}),
        r'Cookie: a=1\, b=2\\x',
      );
      expect(kMediaKitManagedProperties, contains('http-header-fields'));
    });
  });

  group('deinterlace', () {
    test('auto uses deinterlace=auto only when supported', () {
      expect(
        mpvPropertiesFor(
          const EngineOptions(),
          vod,
          deinterlaceAutoSupported: true,
        )['deinterlace'],
        'auto',
      );
      final p = mpvPropertiesFor(const EngineOptions(), vod);
      expect(p['deinterlace'], 'no');
      expect(p['vf'], '');
    });

    test('forced on without filters uses mpv deinterlace=yes', () {
      // The media_kit libmpv builds have no yadif/bwdif: mpv's own
      // deinterlacer (d3d11vpp for D3D11 frames) is the only option.
      final p = mpvPropertiesFor(
        const EngineOptions(deinterlaceMode: DeinterlaceMode.on),
        vod,
      );
      expect(p['deinterlace'], 'yes');
      expect(p['vf'], '');
    });

    test('forced on uses the chosen filter when available', () {
      final bwdif = mpvPropertiesFor(
        const EngineOptions(deinterlaceMode: DeinterlaceMode.on),
        vod,
        deinterlaceFilters: DeinterlaceMethod.values.toSet(),
      );
      expect(bwdif['vf'], 'bwdif=mode=send_field');
      expect(bwdif['deinterlace'], 'no');
      final yadif = mpvPropertiesFor(
        const EngineOptions(
          deinterlaceMode: DeinterlaceMode.on,
          deinterlaceMethod: DeinterlaceMethod.yadif,
        ),
        vod,
        deinterlaceFilters: DeinterlaceMethod.values.toSet(),
      );
      expect(yadif['vf'], 'yadif=mode=send_field');
    });

    test('forced on falls back to the other available filter', () {
      expect(
        deinterlacePropertiesFor(
          DeinterlaceMode.on,
          DeinterlaceMethod.bwdif,
          availableFilters: {DeinterlaceMethod.yadif},
        ),
        {'deinterlace': 'no', 'vf': 'yadif=mode=send_field'},
      );
    });

    test('off clears everything', () {
      expect(
        deinterlacePropertiesFor(
          DeinterlaceMode.off,
          DeinterlaceMethod.bwdif,
          autoSupported: true,
        ),
        {'deinterlace': 'no', 'vf': ''},
      );
    });
  });

  group('aspect', () {
    test('mpv properties per profile', () {
      expect(aspectPropertiesFor(AspectMode.auto), {
        'video-aspect-override': '-1',
        'panscan': '0.0',
        'keepaspect': 'yes',
      });
      expect(aspectPropertiesFor(AspectMode.fill)['keepaspect'], 'no');
      expect(aspectPropertiesFor(AspectMode.crop)['panscan'], '1.0');
      expect(
        aspectPropertiesFor(AspectMode.r16x9)['video-aspect-override'],
        '16:9',
      );
      expect(
        aspectPropertiesFor(AspectMode.r4x3)['video-aspect-override'],
        '4:3',
      );
    });

    test('every mode sets all three properties (switching resets)', () {
      for (final mode in AspectMode.values) {
        expect(aspectPropertiesFor(mode).keys.toSet(), {
          'video-aspect-override',
          'panscan',
          'keepaspect',
        });
      }
    });

    test('Flutter fit', () {
      expect(boxFitForAspect(AspectMode.auto), BoxFit.contain);
      expect(boxFitForAspect(AspectMode.fill), BoxFit.fill);
      expect(boxFitForAspect(AspectMode.crop), BoxFit.cover);
      expect(boxFitForAspect(AspectMode.r16x9), BoxFit.contain);
      expect(boxFitForAspect(AspectMode.r4x3), BoxFit.contain);
      expect(
        boxFitForAspect(AspectMode.auto, base: BoxFit.cover),
        BoxFit.cover,
      );
    });

    test('options.aspect flows into the mapping', () {
      final p = mpvPropertiesFor(
        const EngineOptions(aspect: AspectMode.r4x3),
        vod,
      );
      expect(p['video-aspect-override'], '4:3');
    });
  });

  group('tracks and languages', () {
    test('no preference', () {
      final p = mpvPropertiesFor(const EngineOptions(), vod);
      expect(p['alang'], '');
      expect(p['slang'], '');
      expect(p['sid'], 'auto');
      expect(p['subs-fallback'], 'default');
    });

    test('Turkish audio and English subtitles', () {
      final p = mpvPropertiesFor(
        const EngineOptions(
          preferredAudioLanguage: 'tr',
          preferredSubtitleLanguage: 'English',
        ),
        vod,
      );
      expect(p['alang'], 'tur,tr,trk');
      expect(p['slang'], 'eng,en');
      expect(p['sid'], 'auto');
    });

    test('Disabled subtitles', () {
      for (final value in [kSubtitlesDisabled, 'off', 'None']) {
        final p = mpvPropertiesFor(
          EngineOptions(preferredSubtitleLanguage: value),
          vod,
        );
        expect(p['sid'], 'no', reason: value);
        expect(p['slang'], '', reason: value);
      }
    });

    test('subtitle fallback off', () {
      final p = mpvPropertiesFor(
        const EngineOptions(subtitleFallback: SubtitleFallback.off),
        vod,
      );
      expect(p['subs-fallback'], 'no');
    });
  });

  group('delays and subtitle size', () {
    test('formatting', () {
      final p = mpvPropertiesFor(
        const EngineOptions(
          audioDelay: Duration(milliseconds: 300),
          subtitleDelay: Duration(milliseconds: -1250),
          subtitleScale: 1.25,
        ),
        vod,
      );
      expect(p['audio-delay'], '0.300');
      expect(p['sub-delay'], '-1.250');
      expect(p['sub-scale'], '1.25');
    });

    test('defaults and clamping', () {
      final p = mpvPropertiesFor(const EngineOptions(), vod);
      expect(p['audio-delay'], '0.000');
      expect(p['sub-delay'], '0.000');
      expect(p['sub-scale'], '1.00');
      expect(formatScale(10), '3.00');
      expect(formatScale(0), '0.30');
      expect(formatSeconds(const Duration(seconds: -5)), '-5.000');
    });
  });

  group('list option keys', () {
    test('suffix parsing', () {
      final m = kListOptionSuffix.firstMatch('demuxer-lavf-o-remove')!;
      expect(m.group(1), 'demuxer-lavf-o');
      expect(m.group(2), 'remove');
      expect(kListOptionSuffix.hasMatch('demuxer-lavf-o-add'), isTrue);
    });

    test('no regular property is mistaken for a list operation', () {
      final all = {
        ...mpvPropertiesFor(const EngineOptions(), vod),
        ...mpvPropertiesFor(
          const EngineOptions(profile: EngineProfile.lowLatency),
          liveTs,
        ),
      };
      final listKeys = all.keys.where(kListOptionSuffix.hasMatch).toSet();
      expect(listKeys, {'demuxer-lavf-o-remove', 'demuxer-lavf-o-add'});
    });
  });

  test('mapping is deterministic', () {
    const options = EngineOptions(
      profile: EngineProfile.lowLatency,
      preferredAudioLanguage: 'tur',
    );
    expect(
      mpvPropertiesFor(options, liveTs),
      mpvPropertiesFor(options, liveTs),
    );
  });
}
