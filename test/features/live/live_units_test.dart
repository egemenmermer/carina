import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:carina/app/time_format.dart';
import 'package:carina/data/repositories/live_repository.dart';
import 'package:carina/data/repositories/playlist_repository.dart';
import 'package:carina/data/repositories/repository_models.dart';
import 'package:carina/data/repositories/stream_url_resolver.dart';
import 'package:carina/data/settings/settings_store.dart';
import 'package:carina/features/live/layouts/live_layouts.dart';
import 'package:carina/features/live/preview/live_preview_controller.dart';
import 'package:carina/features/live/state/live_card_info.dart';
import 'package:carina/features/live/state/live_providers.dart';
import 'package:carina/player/engine/fake_engine.dart';
import 'package:carina/player/engine/playback_engine.dart';

import '../../data/repositories/r1/fixtures.dart';

void main() {
  group('epgSourceHost', () {
    test('credits a third-party guide by host only', () {
      expect(
        epgSourceHost(
          'https://www.epg-guide.com/tr.xml.gz?token=secret',
          server: 'http://iptv.example.com:8080',
        ),
        'epg-guide.com',
      );
    });

    test("the provider's own XMLTV and invalid URLs give null", () {
      expect(
        epgSourceHost(
          'http://iptv.example.com:8080/xmltv.php?username=u&password=p',
          server: 'http://iptv.example.com:8080',
        ),
        isNull,
      );
      expect(epgSourceHost(null), isNull);
      expect(epgSourceHost('  '), isNull);
      expect(epgSourceHost('not a url'), isNull);
    });
  });

  group('liveCardInfo', () {
    final format = CarinaTimeFormat(locale: 'en', use24h: false);
    setUpAll(() => initializeDateFormatting('en'));

    test('programme on air: title, range and progress', () {
      final start = DateTime(2026, 10, 17, 15, 15);
      final p = ProgrammeView(
        epgChannelId: 'x',
        start: start.toUtc(),
        stop: start.add(const Duration(hours: 1)).toUtc(),
        title: 'Haberler',
      );
      final info = liveCardInfo(
        programme: p,
        now: DateTime(2026, 10, 17, 15, 30),
        format: format,
        noEpgLabel: 'EPG not available',
      );
      expect(info.title, 'Haberler');
      expect(info.time, '3:15 PM – 4:15 PM');
      expect(info.progress, closeTo(0.25, 1e-9));
      expect(info.hasEpg, isTrue);
    });

    test('no guide: the current hour slot and the label', () {
      final info = liveCardInfo(
        programme: null,
        now: DateTime(2026, 10, 17, 19, 45),
        format: format,
        noEpgLabel: 'EPG not available',
      );
      expect(info.title, 'EPG not available');
      expect(info.time, '7:00 PM – 8:00 PM');
      expect(info.progress, closeTo(0.75, 1e-9));
      expect(info.hasEpg, isFalse);
    });
  });

  group('LiveGridMetrics', () {
    test('four columns at 1440 px, three at the minimum window', () {
      final wide = LiveGridMetrics.of(1440);
      expect(wide.columns, 4);
      expect(wide.tileSize.width / wide.tileSize.height, closeTo(16 / 9, 1e-9));
      expect(wide.tileSize.width, greaterThan(wide.cardWidth));
      expect(LiveGridMetrics.of(1100).columns, 3);
      expect(LiveGridMetrics.of(2560).columns, 4);
    });

    test('the preview panels never get less than they need', () {
      expect(LiveHorizontalLayout.panelsHeight(800), closeTo(346.72, 0.01));
      expect(LiveHorizontalLayout.panelsHeight(500), 290);
    });
  });

  group('LivePreviewController', () {
    late R1Env env;
    late int pid;
    late LiveRepository live;
    late FakeEngineFactory engines;
    late LivePreviewController controller;

    setUp(() async {
      env = await R1Env.create();
      pid = await env.playlist(server: 'http://iptv.example.com:8080');
      await env.channel(pid, '1', 'One HD', displayName: 'One');
      await env.channel(pid, '2', 'Two HD', displayName: 'Two');
      await env.channel(pid, '3', 'Drm', unsupported: true);
      live = LiveRepository(env.db, env.settings);
      engines = FakeEngineFactory(autoTick: false);
      controller = LivePreviewController(
        playlistId: pid,
        factory: engines,
        resolver: StreamUrlResolver(
          PlaylistRepository(env.db, env.secrets, env.settings),
          env.settings,
        ),
        options: () => livePreviewEngineOptions(env.settings, pid),
      );
    });

    tearDown(() async {
      await controller.dispose();
      await live.dispose();
      await env.dispose();
    });

    Future<ChannelView> channel(String id) async =>
        (await live.channel(pid, id))!;

    test('creates one low-latency engine and reuses it', () async {
      await controller.open(await channel('1'), muted: true);
      await controller.open(await channel('2'), muted: true);
      expect(engines.created, hasLength(1));
      final engine = engines.last;
      expect(engine.preview, isTrue);
      expect(engine.profile, EngineProfile.lowLatency);
      expect(engine.openedSources.map((s) => s.url), [
        endsWith('/live/kanal/test123/1.ts'),
        endsWith('/live/kanal/test123/2.ts'),
      ]);
      expect(engine.openedSources.every((s) => s.isLive), isTrue);
      expect(controller.channelId, '2');
    });

    test('200 zaps reuse one engine ', () async {
      final one = await channel('1');
      final two = await channel('2');
      for (var i = 0; i < 200; i++) {
        await controller.open(i.isEven ? one : two, muted: true);
      }
      expect(engines.created, hasLength(1));
      expect(engines.last.openedSources, hasLength(200));
      expect(engines.last.calls.where((c) => c == 'dispose'), isEmpty);
      expect(controller.channelId, '2');
      // The status follows the last zap only.
      expect(controller.status.value.state.source?.url, endsWith('/2.ts'));
    });

    test('overlapping opens: only the last one plays', () async {
      final one = await channel('1');
      final two = await channel('2');
      final first = controller.open(one, muted: true);
      final second = controller.open(two, muted: true);
      await Future.wait([first, second]);
      expect(engines.last.openedSources.map((s) => s.url), [endsWith('/2.ts')]);
      expect(controller.channelId, '2');
    });

    test('a DRM channel reports the resolve error and stops', () async {
      await controller.open(await channel('1'), muted: true);
      await controller.open(await channel('3'), muted: true);
      final status = controller.status.value;
      expect(status.channelId, '3');
      expect(status.resolveError, StreamResolveError.unsupported);
      expect(status.hasError, isTrue);
      expect(engines.last.state.source, isNull, reason: 'stopped');
    });

    test(
      'mute follows the request; stop and dispose free the engine',
      () async {
        await controller.open(await channel('1'), muted: false);
        expect(engines.last.state.muted, isFalse);
        await controller.setMuted(true);
        expect(engines.last.state.muted, isTrue);
        await controller.stop();
        expect(controller.channelId, isNull);
        expect(engines.last.state.source, isNull);
        final engine = engines.last;
        await controller.dispose();
        expect(engine.isDisposed, isTrue);
        // Calls after dispose are no-ops.
        await controller.open(await channel('2'), muted: true);
        expect(engines.created, hasLength(1));
      },
    );

    test(
      'a failing engine shows the error state instead of throwing',
      () async {
        final failing = LivePreviewController(
          playlistId: pid,
          factory: _ThrowingFactory(),
          resolver: StreamUrlResolver(
            PlaylistRepository(env.db, env.secrets, env.settings),
            env.settings,
          ),
          options: () => livePreviewEngineOptions(env.settings, pid),
        );
        await failing.open(await channel('1'), muted: true);
        expect(failing.status.value.failed, isTrue);
        expect(failing.status.value.hasError, isTrue);
        await failing.dispose();
      },
    );

    test('engine stats reach the status once the stream plays', () async {
      await controller.open(await channel('1'), muted: true);
      await pumpEventQueue();
      final status = controller.status.value;
      expect(status.state.hasVideo, isTrue);
      expect(status.stats.qualityLabel, 'FHD');
      expect(status.stats.fps, 25);
      expect(status.loading, isFalse);
    });
  });

  test('preview engine options come from the player settings', () async {
    final env = await R1Env.create();
    addTearDown(env.dispose);
    final pid = await env.playlist();
    await env.settings.set(
      PlaylistSettings.hardwareAcceleration,
      false,
      playlistId: pid,
    );
    await env.settings.set(PlaylistSettings.deinterlace, 'on', playlistId: pid);
    final options = livePreviewEngineOptions(env.settings, pid);
    expect(options.profile, EngineProfile.lowLatency);
    expect(options.hardwareAcceleration, isFalse);
    expect(options.deinterlaceMode, DeinterlaceMode.on);
    expect(options.muted, isTrue);
  });
}

class _ThrowingFactory implements PlaybackEngineFactory {
  @override
  PlaybackEngine create({
    required EngineOptions options,
    bool preview = false,
  }) => throw StateError('no libmpv');
}
