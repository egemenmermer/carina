import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/settings/settings_store.dart';
import 'package:carina/l10n/gen/app_localizations_en.dart';
import 'package:carina/l10n/gen/app_localizations_tr.dart';
import 'package:carina/player/engine/playback_engine.dart';
import 'package:carina/player/ui/player_chapters.dart';
import 'package:carina/player/ui/player_controller.dart';
import 'package:carina/player/ui/player_options.dart';
import 'package:carina/player/ui/player_shortcuts.dart';
import 'package:carina/player/ui/player_texts.dart';

void main() {
  group('shortcut map', () {
    PlayerShortcut? vod(
      LogicalKeyboardKey key, {
      bool controls = false,
      bool info = false,
      bool shift = false,
      bool control = false,
    }) => playerShortcutFor(
      key,
      kind: PlayerKind.vod,
      controlsVisible: controls,
      infoPanelOpen: info,
      modifiers: PlayerModifiers(shift: shift, control: control),
    );

    PlayerShortcut? live(LogicalKeyboardKey key, {bool shift = false}) =>
        playerShortcutFor(
          key,
          kind: PlayerKind.live,
          controlsVisible: false,
          modifiers: PlayerModifiers(shift: shift),
        );

    PlayerCommand? cmd(PlayerShortcut? s) => s?.command;

    test('VOD transport keys', () {
      expect(cmd(vod(LogicalKeyboardKey.space)), PlayerCommand.togglePlay);
      expect(cmd(vod(LogicalKeyboardKey.keyK)), PlayerCommand.togglePlay);
      expect(cmd(vod(LogicalKeyboardKey.arrowLeft)), PlayerCommand.seekBack);
      expect(
        cmd(vod(LogicalKeyboardKey.arrowRight)),
        PlayerCommand.seekForward,
      );
      expect(
        cmd(vod(LogicalKeyboardKey.arrowLeft, shift: true)),
        PlayerCommand.seekBackLong,
      );
      expect(
        cmd(vod(LogicalKeyboardKey.arrowRight, shift: true)),
        PlayerCommand.seekForwardLong,
      );
      expect(cmd(vod(LogicalKeyboardKey.keyJ)), PlayerCommand.seekBack);
      expect(cmd(vod(LogicalKeyboardKey.keyL)), PlayerCommand.seekForward);
      expect(
        vod(LogicalKeyboardKey.digit7),
        const PlayerShortcut(PlayerCommand.seekPercent, digit: 7),
      );
      expect(
        vod(LogicalKeyboardKey.numpad0),
        const PlayerShortcut(PlayerCommand.seekPercent, digit: 0),
      );
      expect(cmd(vod(LogicalKeyboardKey.keyN)), PlayerCommand.nextEpisode);
    });

    test('VOD ↑/↓: volume, or the info panel while the controls show', () {
      expect(cmd(vod(LogicalKeyboardKey.arrowUp)), PlayerCommand.volumeUp);
      expect(cmd(vod(LogicalKeyboardKey.arrowDown)), PlayerCommand.volumeDown);
      expect(
        cmd(vod(LogicalKeyboardKey.arrowDown, controls: true)),
        PlayerCommand.infoPanel,
      );
      expect(
        cmd(vod(LogicalKeyboardKey.arrowUp, info: true)),
        PlayerCommand.closeInfoPanel,
      );
      expect(vod(LogicalKeyboardKey.arrowDown, info: true), isNull);
      expect(cmd(vod(LogicalKeyboardKey.keyI)), PlayerCommand.infoPanel);
      expect(
        cmd(vod(LogicalKeyboardKey.keyI, info: true)),
        PlayerCommand.closeInfoPanel,
      );
    });

    test('shared keys', () {
      for (final kind in PlayerKind.values) {
        PlayerCommand? c(
          LogicalKeyboardKey k, {
          bool shift = false,
          bool ctrl = false,
        }) => playerShortcutFor(
          k,
          kind: kind,
          controlsVisible: false,
          modifiers: PlayerModifiers(shift: shift, control: ctrl),
        )?.command;
        expect(c(LogicalKeyboardKey.keyM), PlayerCommand.toggleMute);
        expect(c(LogicalKeyboardKey.keyF), PlayerCommand.toggleFullscreen);
        expect(c(LogicalKeyboardKey.keyA), PlayerCommand.audioMenu);
        expect(c(LogicalKeyboardKey.keyS), PlayerCommand.subtitlesMenu);
        expect(c(LogicalKeyboardKey.escape), PlayerCommand.back);
        expect(c(LogicalKeyboardKey.bracketLeft), PlayerCommand.audioDelayDown);
        expect(c(LogicalKeyboardKey.bracketRight), PlayerCommand.audioDelayUp);
        expect(
          c(LogicalKeyboardKey.keyD, shift: true, ctrl: true),
          PlayerCommand.toggleStats,
        );
        // Ctrl/⌘ + other keys are left to the app (e.g. Ctrl+Q).
        expect(c(LogicalKeyboardKey.keyM, ctrl: true), isNull);
        expect(c(LogicalKeyboardKey.equal), PlayerCommand.volumeUp);
        expect(c(LogicalKeyboardKey.minus), PlayerCommand.volumeDown);
      }
      expect(
        playerShortcutFor(
          LogicalKeyboardKey.keyD,
          kind: PlayerKind.vod,
          controlsVisible: false,
          modifiers: const PlayerModifiers(shift: true, meta: true),
        )?.command,
        PlayerCommand.toggleStats,
      );
    });

    test('live keys', () {
      expect(cmd(live(LogicalKeyboardKey.arrowUp)), PlayerCommand.zapPrevious);
      expect(cmd(live(LogicalKeyboardKey.pageUp)), PlayerCommand.zapPrevious);
      expect(
        cmd(live(LogicalKeyboardKey.channelUp)),
        PlayerCommand.zapPrevious,
      );
      expect(cmd(live(LogicalKeyboardKey.arrowDown)), PlayerCommand.zapNext);
      expect(cmd(live(LogicalKeyboardKey.pageDown)), PlayerCommand.zapNext);
      expect(cmd(live(LogicalKeyboardKey.channelDown)), PlayerCommand.zapNext);
      expect(cmd(live(LogicalKeyboardKey.enter)), PlayerCommand.actionSheet);
      expect(cmd(live(LogicalKeyboardKey.keyG)), PlayerCommand.miniGuide);
      expect(
        cmd(live(LogicalKeyboardKey.keyG, shift: true)),
        PlayerCommand.fullGuide,
      );
      expect(
        cmd(live(LogicalKeyboardKey.backspace)),
        PlayerCommand.previousChannel,
      );
      expect(
        live(LogicalKeyboardKey.digit4),
        const PlayerShortcut(PlayerCommand.numberZap, digit: 4),
      );
      // No transport keys on live TV.
      expect(live(LogicalKeyboardKey.arrowLeft), isNull);
      expect(live(LogicalKeyboardKey.space), isNull);
      expect(live(LogicalKeyboardKey.keyN), isNull);
    });

    test('catch-up seeks ±30 s / ±5 min, VOD ±10 s / ±60 s', () {
      expect(
        seekStepFor(PlayerCommand.seekForward, PlayerKind.catchup),
        const Duration(seconds: 30),
      );
      expect(
        seekStepFor(PlayerCommand.seekBackLong, PlayerKind.catchup),
        const Duration(minutes: -5),
      );
      expect(
        seekStepFor(PlayerCommand.seekBack, PlayerKind.vod),
        const Duration(seconds: -10),
      );
      expect(
        seekStepFor(PlayerCommand.seekForwardLong, PlayerKind.vod),
        const Duration(seconds: 60),
      );
      expect(
        playerShortcutFor(
          LogicalKeyboardKey.keyN,
          kind: PlayerKind.catchup,
          controlsVisible: false,
        ),
        isNull,
      );
    });
  });

  group('engine options from settings', () {
    late AppDatabase db;
    late SettingsStore settings;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      settings = SettingsStore(db);
      await settings.load();
    });
    tearDown(() => db.close());

    test('defaults', () {
      final o = playerEngineOptions(settings, 1, PlayerKind.live);
      expect(o.profile, EngineProfile.auto);
      expect(o.bufferPolicy, BufferPolicy.auto);
      expect(o.hardwareAcceleration, isTrue);
      expect(o.deinterlaceMode, DeinterlaceMode.auto);
      expect(o.deinterlaceMethod, DeinterlaceMethod.bwdif);
      expect(o.aspect, AspectMode.auto);
      expect(o.preferredAudioLanguage, isNull);
      expect(o.preferredSubtitleLanguage, isNull);
      expect(o.audioDelay, Duration.zero);
      expect(o.subtitleScale, 1.0);
      expect(o.reconnectAttempts, 3);
      expect(o.userAgent, kCarinaUserAgent);
    });

    test(
      'each kind reads its own default player; every setting maps',
      () async {
        await settings.set(
          PlaylistSettings.playerVod,
          'hardware',
          playlistId: 1,
        );
        await settings.set(
          PlaylistSettings.playerLive,
          'lowLatency',
          playlistId: 1,
        );
        await settings.set(
          PlaylistSettings.playerArchive,
          'software',
          playlistId: 1,
        );
        await settings.set(
          PlaylistSettings.bufferPolicy,
          'custom',
          playlistId: 1,
        );
        await settings.set(
          PlaylistSettings.bufferCustomSeconds,
          90,
          playlistId: 1,
        );
        await settings.set(
          PlaylistSettings.hardwareAcceleration,
          false,
          playlistId: 1,
        );
        await settings.set(PlaylistSettings.deinterlace, 'on', playlistId: 1);
        await settings.set(
          PlaylistSettings.deinterlaceMethod,
          'yadif',
          playlistId: 1,
        );
        await settings.set(PlaylistSettings.aspect, 'crop', playlistId: 1);
        await settings.set(
          PlaylistSettings.audioLanguage,
          'tur',
          playlistId: 1,
        );
        await settings.set(
          PlaylistSettings.subtitleLanguage,
          'eng',
          playlistId: 1,
        );
        await settings.set(
          PlaylistSettings.subtitleSize,
          'small',
          playlistId: 1,
        );
        await settings.set(PlaylistSettings.audioDelayMs, -9000, playlistId: 1);
        await settings.set(
          PlaylistSettings.liveReconnectAttempts,
          5,
          playlistId: 1,
        );

        expect(
          playerEngineOptions(settings, 1, PlayerKind.vod).profile,
          EngineProfile.hardware,
        );
        expect(
          playerEngineOptions(settings, 1, PlayerKind.live).profile,
          EngineProfile.lowLatency,
        );
        final o = playerEngineOptions(settings, 1, PlayerKind.catchup);
        expect(o.profile, EngineProfile.software);
        expect(o.bufferPolicy, BufferPolicy.custom);
        expect(o.customBufferSeconds, 60);
        expect(o.hardwareAcceleration, isFalse);
        expect(o.deinterlaceMode, DeinterlaceMode.on);
        expect(o.deinterlaceMethod, DeinterlaceMethod.yadif);
        expect(o.aspect, AspectMode.crop);
        expect(o.preferredAudioLanguage, 'tur');
        expect(o.preferredSubtitleLanguage, 'eng');
        expect(o.subtitleScale, 0.75);
        expect(o.audioDelay, const Duration(seconds: -5));
        expect(o.reconnectAttempts, 5);
        // Other playlists keep their defaults.
        expect(
          playerEngineOptions(settings, 2, PlayerKind.vod).profile,
          EngineProfile.auto,
        );
      },
    );

    test('subtitles "disabled" turns subtitles off', () async {
      await settings.set(
        PlaylistSettings.subtitleLanguage,
        'disabled',
        playlistId: 1,
      );
      expect(
        playerEngineOptions(settings, 1, PlayerKind.vod).subtitlesDisabled,
        isTrue,
      );
    });
  });

  group('chapters', () {
    const json =
        '[{"title":"Opening","time":0.0},{"title":"Part 1","time":95.5},'
        '{"title":"End Credits","time":2400}]';

    test('parse with ends and roles', () {
      final c = parseChapterList(json, const Duration(seconds: 2537));
      expect(c, hasLength(3));
      expect(c[0].isIntro, isTrue);
      expect(c[0].end, const Duration(milliseconds: 95500));
      expect(c[2].isCredits, isTrue);
      expect(c[2].end, const Duration(seconds: 2537));
      expect(introAt(c, const Duration(seconds: 30)), c[0]);
      expect(introAt(c, const Duration(seconds: 100)), isNull);
      expect(creditsStart(c), const Duration(seconds: 2400));
    });

    test('garbage gives no chapters', () {
      expect(parseChapterList(null, Duration.zero), isEmpty);
      expect(parseChapterList('nope', Duration.zero), isEmpty);
      expect(parseChapterList('{"a":1}', Duration.zero), isEmpty);
      expect(parseChapterList('[{"title":"Intro"}]', Duration.zero), isEmpty);
    });

    test('Turkish names count', () {
      final c = parseChapterList(
        '[{"title":"Giriş","time":0},{"title":"Bölüm","time":60},'
        '{"title":"Jenerik","time":120}]',
        const Duration(seconds: 150),
      );
      expect(c.first.isIntro, isTrue);
      expect(c.last.isCredits, isTrue);
    });
  });

  group('labels', () {
    final en = L10nEn();
    final tr = L10nTr();

    test('delays', () {
      expect(delayLabel(en, const Duration(milliseconds: 300)), '+0.3 s');
      expect(delayLabel(en, const Duration(milliseconds: -1200)), '−1.2 s');
      expect(delayLabel(en, Duration.zero), '0.0 s');
      expect(delayLabel(tr, const Duration(milliseconds: 300)), '+0,3 sn');
    });

    test('tracks', () {
      const audio = EngineTrack(
        id: '3',
        kind: EngineTrackKind.audio,
        language: 'tur',
        codec: 'ac3',
        channels: 6,
      );
      expect(trackLabel(en, audio), 'Turkish');
      expect(trackLabel(tr, audio), 'Türkçe');
      expect(trackDetail(en, audio), 'AC3 5.1');
      const bare = EngineTrack(id: '4', kind: EngineTrackKind.subtitle);
      expect(trackLabel(en, bare), 'Track 4');
      const ext = EngineTrack(
        id: '5',
        kind: EngineTrackKind.subtitle,
        title: 'movie.tr.srt',
        codec: 'subrip',
        isExternal: true,
      );
      expect(trackDetail(en, ext), 'SRT · External');
    });

    test('profiles name the platform decoder', () {
      expect(hardwareApiName(TargetPlatform.windows), 'D3D11');
      expect(hardwareApiName(TargetPlatform.macOS), 'VideoToolbox');
      expect(profileLabel(en, EngineProfile.software), 'MPV · Software');
    });

    test('error messages', () {
      String msg(EngineError e) => failureMessage(
        en,
        PlayerFailure(PlayerFailureKind.engine, engineError: e),
      );
      expect(
        msg(
          const EngineError(
            kind: EngineErrorKind.http,
            statusCode: 404,
            message: '',
          ),
        ),
        'Stream not found (HTTP 404).',
      );
      expect(
        msg(
          const EngineError(
            kind: EngineErrorKind.http,
            statusCode: 503,
            message: '',
          ),
        ),
        'Server error (HTTP 503). Try again later.',
      );
      expect(
        msg(const EngineError(kind: EngineErrorKind.timeout, message: '')),
        'The server did not respond in time.',
      );
      expect(
        failureMessage(en, const PlayerFailure(PlayerFailureKind.noCatchup)),
        'This channel has no TV archive for this programme.',
      );
      expect(
        const PlayerFailure(PlayerFailureKind.unsupported).retryable,
        isFalse,
      );
      expect(
        const PlayerFailure(
          PlayerFailureKind.engine,
          engineError: EngineError(kind: EngineErrorKind.codec, message: ''),
        ).retryable,
        isFalse,
      );
    });

    test('runtime and rates', () {
      expect(shortRuntime(const Duration(minutes: 8)), '8m');
      expect(shortRuntime(const Duration(hours: 1, minutes: 49)), '1h 49m');
      expect(rateLabel(en, 1.0), 'Normal');
      expect(rateLabel(en, 1.25), '1.25×');
      expect(rateLabel(en, 2.0), '2×');
    });
  });
}
