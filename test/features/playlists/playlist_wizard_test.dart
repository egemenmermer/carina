import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/app_paths.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/import/import.dart';
import 'package:carina/data/repositories/playlist_repository.dart';
import 'package:carina/data/secrets/secret_store.dart';
import 'package:carina/data/settings/settings_store.dart';
import 'package:carina/data/sources/xtream/xtream_check.dart';
import 'package:carina/data/sources/xtream/xtream_credentials.dart';
import 'package:carina/features/playlists/data/source_checker.dart';

import '../../../tools/mock_server/src/server.dart';
import '../../support/drift_widgets.dart';
import '../../support/mock_import.dart' show importMockPlaylist;
import '../../support/screenshot.dart';
import 'support/playlists_harness.dart';

/// In-memory app state for the wizard (no playlists yet).
class _Env {
  _Env(this.db, this.settings, this.secrets, this.paths, this.imports);

  final AppDatabase db;
  final SettingsStore settings;
  final MemorySecretStore secrets;
  final AppPaths paths;
  final ImportService imports;

  PlaylistRepository get repository =>
      PlaylistRepository(db, secrets, settings);

  List<Override> overrides(PlaylistSourceChecker checker) => [
    appDatabaseProvider.overrideWithValue(db),
    appPathsProvider.overrideWithValue(paths),
    settingsStoreProvider.overrideWithValue(settings),
    secretStoreProvider.overrideWithValue(secrets),
    importServiceProvider.overrideWithValue(imports),
    playlistSourceCheckerProvider.overrideWithValue(checker),
  ];
}

Future<_Env> _createEnv({bool rootZoneImports = false}) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final settings = SettingsStore(db);
  await settings.load();
  final secrets = MemorySecretStore();
  final paths = await tempAppPaths();
  final ImportService imports = rootZoneImports
      ? RootZoneImportService(
          db: db,
          paths: paths,
          secrets: secrets,
          settings: settings,
        )
      : FakeImportService(
          db: db,
          paths: paths,
          secrets: secrets,
          settings: settings,
        );
  return _Env(db, settings, secrets, paths, imports);
}

Finder _field(String name) => find.descendant(
  of: find.byKey(ValueKey('wizard-field-$name')),
  matching: find.byType(TextField),
);

Future<void> _type(WidgetTester tester, String field, String text) async {
  await tester.enterText(_field(field), text);
  await tester.pump();
}

/// Moves the focus to [field] (blurs the previous one, which starts its
/// live check) and lets the check answer.
Future<void> _focus(WidgetTester tester, String field) async {
  // A mouse click, as on desktop (a touch would show selection handles).
  await tester.tap(_field(field), kind: PointerDeviceKind.mouse);
  await settle(tester);
}

void main() {
  late MockServer server;
  late Directory temp;
  late XtreamCheckResult okLogin;
  late XtreamCheckResult wrongPassword;
  late UrlCheckResult m3uWithGuide;
  late UrlCheckResult xtreamExport;

  setUpAll(() async {
    await loadAppFonts();
    temp = await Directory.systemTemp.createTemp('carina_wizard_');
    final media = Directory('${temp.path}/media')..createSync();
    Directory('${temp.path}/live').createSync();
    server = await MockServer.start(port: 0, mediaDir: media.path);
    const checker = PlaylistSourceChecker();
    okLogin = await withRealHttp(
      () => checker.checkXtream(
        XtreamCredentials(
          server.baseUrl,
          MockFixtures.username,
          MockFixtures.password,
        ),
      ),
    );
    wrongPassword = await withRealHttp(
      () => checker.checkXtream(
        XtreamCredentials(server.baseUrl, MockFixtures.username, 'wrong'),
      ),
    );
    m3uWithGuide = await withRealHttp(
      () => checker.checkPlaylistUrl('${server.baseUrl}/playlist.m3u'),
    );
    xtreamExport = await withRealHttp(
      () => checker.checkPlaylistUrl(
        '${server.baseUrl}/get.php?username=kanal&password=test123'
        '&type=m3u_plus&output=ts',
      ),
    );
    expect(okLogin.ok, isTrue);
    expect(wrongPassword.ok, isFalse);
    expect(m3uWithGuide.m3uEpgUrls, isNotEmpty);
  });

  tearDownAll(() async {
    await server.stop();
    await temp.delete(recursive: true);
  });

  testWidgets('step 02: choose a source; Esc goes back', (tester) async {
    final env = (await tester.runAsync(_createEnv))!;
    final router = playlistsTestRouter(initialLocation: '/playlists/new');
    await pumpScreen(
      tester,
      routerHost(router),
      overrides: env.overrides(FakeSourceChecker()),
    );
    await settleDrift(tester);
    expect(find.text('02 / Choose a source'), findsOneWidget);
    expect(find.text('Use the details you received'), findsOneWidget);
    expect(find.text('Xtream (Recommended)'), findsOneWidget);
    expect(find.text('M3U playlist via URL'), findsOneWidget);
    expect(find.text('M3U file'), findsOneWidget);
    expect(find.text('CARINA'), findsOneWidget);
    await saveScreen(tester, 'playlists_wizard_source');

    // Keyboard: Down + Enter picks "M3U playlist via URL".
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    expect(find.text('03 / Name your playlist'), findsOneWidget);
    expect(find.text('Playlist URL (http://…/playlist.m3u)'), findsOneWidget);
    // Esc: back to the source step, then to the Manager.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.text('02 / Choose a source'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settleDrift(tester);
    expect(router.state.uri.toString(), '/');
    await unmountAndFlush(tester);
  });

  testWidgets('Xtream form: live check, step labels, keyboard', (tester) async {
    final env = (await tester.runAsync(_createEnv))!;
    final checker = FakeSourceChecker(
      xtream: (c) =>
          c.password == MockFixtures.password ? okLogin : wrongPassword,
    );
    final router = playlistsTestRouter(
      initialLocation: '/playlists/new?type=xtream',
    );
    await pumpScreen(
      tester,
      routerHost(router),
      overrides: env.overrides(checker),
    );
    await settleDrift(tester);
    // initialType opens the form with Name focused.
    expect(find.text('03 / Name your playlist'), findsOneWidget);
    expect(find.text('A name you can recognize'), findsOneWidget);
    expect(find.text('Server (i.e. https://domain.com:port)'), findsOneWidget);
    expect(find.text('3 Days'), findsOneWidget);

    await _type(tester, 'name', 'Kanal Demo');
    await _focus(tester, 'server');
    expect(find.text('04 / Server address'), findsOneWidget);
    expect(find.text('Include the scheme and port'), findsOneWidget);
    await _type(tester, 'server', 'http://kanal.example.com:8080');
    await _focus(tester, 'username');
    expect(find.text('05 / Username'), findsOneWidget);
    await _type(tester, 'username', MockFixtures.username);
    await _focus(tester, 'password');
    expect(find.text('06 / Password'), findsOneWidget);
    await _type(tester, 'password', MockFixtures.password);
    expect(checker.calls, isEmpty, reason: 'checks run when a field blurs');
    await _focus(tester, 'epgUrl');
    expect(find.text('07 / EPG URL'), findsOneWidget);
    expect(checker.calls, ['xtream http://kanal.example.com:8080']);
    expect(
      find.text(
        'Server reachable · account active · expires 1 March 2027 · '
        '2 connections',
      ),
      findsOneWidget,
    );
    // Back on Server for the capture (the status stays).
    await _focus(tester, 'server');
    expect(find.text('04 / Server address'), findsOneWidget);
    await saveScreen(tester, 'playlists_wizard_xtream');

    // Up / Down move between rows; Left / Right step the EPG shift.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await settle(tester);
    expect(find.text('08 / EPG time shift'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settle(tester);
    expect(find.text('+2'), findsOneWidget);
    // Enter opens the chooser with −12…+12.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    expect(find.text('EPG time shift (in hours)'), findsNWidgets(2));
    await tester.tap(find.text('−3'));
    await settle(tester);
    expect(find.text('−3'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    expect(find.text('Reload frequency'), findsNWidgets(2));
    await tester.tap(find.text('1 Week'));
    await settle(tester);
    expect(find.text('1 Week'), findsOneWidget);
    await unmountAndFlush(tester);
  });

  testWidgets('validation and failed checks', (tester) async {
    final env = (await tester.runAsync(_createEnv))!;
    final checker = FakeSourceChecker(xtream: (_) => wrongPassword);
    final router = playlistsTestRouter(
      initialLocation: '/playlists/new?type=xtream',
    );
    await pumpScreen(
      tester,
      routerHost(router),
      overrides: env.overrides(checker),
    );
    await settleDrift(tester);
    await _focus(tester, 'server');
    await _type(tester, 'server', 'kanal.example.com:8080');
    await _focus(tester, 'username');
    expect(find.text('Start with http:// or https://'), findsOneWidget);
    await _focus(tester, 'server');
    await _type(tester, 'server', 'http://kanal.example.com');
    expect(
      find.text(
        'Include the port, e.g. :8080 (use :80 if your provider gave none)',
      ),
      findsOneWidget,
    );
    await _type(tester, 'server', 'http://kanal.example.com:8080');
    await _focus(tester, 'username');
    await _type(tester, 'username', 'kanal');
    await _focus(tester, 'password');
    await _type(tester, 'password', 'wrong');
    await _focus(tester, 'epgUrl');
    expect(find.text('Wrong username or password (401)'), findsOneWidget);
    await _type(tester, 'epgUrl', 'guide.example.com/epg.xml');
    // Save with an empty name: every problem shows, Name gets the focus.
    await tester.tap(find.byKey(const ValueKey('wizard-save')));
    await settleDrift(tester);
    expect(find.text('Enter a name'), findsOneWidget);
    expect(
      find.text('Enter a complete http:// or https:// link, or leave it empty'),
      findsOneWidget,
    );
    expect(find.text('03 / Name your playlist'), findsOneWidget);
    expect(await tester.runAsync(env.repository.getAll), isEmpty);
    await saveScreen(tester, 'playlists_wizard_error');
    await unmountAndFlush(tester);
  });

  testWidgets('M3U: header guide pre-fill; an Xtream link offers Xtream', (
    tester,
  ) async {
    final env = (await tester.runAsync(_createEnv))!;
    final checker = FakeSourceChecker(
      playlistUrl: (url) =>
          url.contains('get.php') ? xtreamExport : m3uWithGuide,
      epgUrl: (_) => const UrlCheckResult(ok: true, reachable: true),
      xtream: (_) => okLogin,
    );
    final router = playlistsTestRouter(
      initialLocation: '/playlists/new?type=m3u',
    );
    await pumpScreen(
      tester,
      routerHost(router),
      overrides: env.overrides(checker),
    );
    await settleDrift(tester);
    await _type(tester, 'name', 'Mock M3U');
    await _focus(tester, 'playlistUrl');
    expect(find.text('04 / Playlist URL'), findsOneWidget);
    final url = '${server.baseUrl}/playlist.m3u';
    await _type(tester, 'playlistUrl', url);
    await _focus(tester, 'userAgent');
    expect(
      find.text('Playlist reachable · M3U · guide link found'),
      findsOneWidget,
    );
    final guide = m3uWithGuide.m3uEpgUrls.first;
    expect(find.text(guide), findsOneWidget, reason: 'EPG field pre-filled');
    expect(find.text('Filled in from the playlist'), findsOneWidget);

    // An Xtream get.php link: offer to switch.
    await _focus(tester, 'playlistUrl');
    await _type(
      tester,
      'playlistUrl',
      '${server.baseUrl}/get.php?username=kanal&password=test123&type=m3u_plus',
    );
    expect(find.byKey(const ValueKey('wizard-xtream-offer')), findsOneWidget);
    await tester.tap(find.text('Switch to Xtream'));
    await settle(tester);
    expect(find.text('Xtream (Recommended)'), findsOneWidget);
    expect(find.text(server.baseUrl), findsOneWidget);
    expect(find.text('kanal'), findsOneWidget);
    expect(
      tester.widget<TextField>(_field('password')).obscureText,
      isTrue,
      reason: 'password is masked',
    );
    expect(checker.calls.last, 'xtream ${server.baseUrl}');
    await unmountAndFlush(tester);
  });

  testWidgets('M3U save keeps the header guide as the default', (tester) async {
    final env = (await tester.runAsync(_createEnv))!;
    final imports = env.imports as FakeImportService;
    final checker = FakeSourceChecker(playlistUrl: (_) => m3uWithGuide);
    final router = playlistsTestRouter(
      initialLocation: '/playlists/new?type=m3u',
    );
    await pumpScreen(
      tester,
      routerHost(router),
      overrides: env.overrides(checker),
    );
    await settleDrift(tester);
    await _type(tester, 'name', 'Mock M3U');
    await _focus(tester, 'playlistUrl');
    await _type(tester, 'playlistUrl', '${server.baseUrl}/playlist.m3u');
    await _focus(tester, 'userAgent');
    await _type(tester, 'userAgent', 'VLC/3.0.20');
    await tester.tap(find.byKey(const ValueKey('wizard-save')));
    await pumpUntil(tester, () => imports.started.isNotEmpty);
    final rows = (await tester.runAsync(env.repository.getAll))!;
    expect(rows, hasLength(1));
    final row = rows.single;
    expect(row.type, PlaylistType.m3u);
    expect(row.m3uUrl, '${server.baseUrl}/playlist.m3u');
    expect(row.epgUrl, isNull, reason: 'follows the url-tvg header');
    expect(row.userAgent, 'VLC/3.0.20');
    expect(row.avatarId, isNotNull, reason: 'a default avatar is assigned');
    expect(router.state.uri.toString(), '/playlists/${row.id}/import');
    expect(imports.started.single, (row.id, ImportScope.all));
    await unmountAndFlush(tester);
  });

  testWidgets('Disable guide stores an empty EPG URL', (tester) async {
    final env = (await tester.runAsync(_createEnv))!;
    final imports = env.imports as FakeImportService;
    final router = playlistsTestRouter(
      initialLocation: '/playlists/new?type=xtream',
    );
    await pumpScreen(
      tester,
      routerHost(router),
      overrides: env.overrides(FakeSourceChecker(xtream: (_) => okLogin)),
    );
    await settleDrift(tester);
    await _type(tester, 'name', 'No Guide');
    await _focus(tester, 'server');
    await _type(tester, 'server', 'http://kanal.example.com:8080');
    await _focus(tester, 'username');
    await _type(tester, 'username', 'kanal');
    await _focus(tester, 'password');
    await _type(tester, 'password', 'test123');
    await tester.tap(find.byKey(const ValueKey('wizard-guide-toggle')));
    await settle(tester);
    expect(find.text('Guide disabled'), findsOneWidget);
    expect(find.text('Enable guide'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('wizard-save')));
    await pumpUntil(tester, () => imports.started.isNotEmpty);
    final row = (await tester.runAsync(env.repository.getAll))!.single;
    expect(row.epgUrl, '');
    expect(row.server, 'http://kanal.example.com:8080');
    await unmountAndFlush(tester);
  });

  testWidgets('Turkish: the wizard and its errors fit', (tester) async {
    final env = (await tester.runAsync(_createEnv))!;
    final router = playlistsTestRouter(
      initialLocation: '/playlists/new?type=m3u',
    );
    await pumpScreen(
      tester,
      routerHost(router),
      locale: const Locale('tr'),
      overrides: env.overrides(
        FakeSourceChecker(playlistUrl: (_) => m3uWithGuide),
      ),
    );
    await settleDrift(tester);
    expect(find.text('03 / Listenize ad verin'), findsOneWidget);
    expect(find.text('URL ile M3U listesi'), findsOneWidget);
    await _focus(tester, 'playlistUrl');
    await _type(tester, 'playlistUrl', '${server.baseUrl}/playlist.m3u');
    await _focus(tester, 'userAgent');
    expect(
      find.text('Listeye ulaşıldı · M3U · rehber bağlantısı bulundu'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('wizard-save')));
    await settleDrift(tester);
    expect(find.text('Bir ad girin'), findsOneWidget);
    await saveScreen(tester, 'playlists_wizard_tr');
    await unmountAndFlush(tester);
  });

  testWidgets('M3U file: picker, name from the file, check', (tester) async {
    final env = (await tester.runAsync(_createEnv))!;
    final path = '${temp.path}/Ev Listesi.m3u';
    final checker = FakeSourceChecker(
      file: (_) => const FileCheckResult(exists: true, kind: null),
    );
    final router = playlistsTestRouter(
      initialLocation: '/playlists/new?type=m3uFile',
    );
    await pumpScreen(
      tester,
      routerHost(router),
      overrides: [
        ...env.overrides(checker),
        playlistFilePickerProvider.overrideWithValue((_) async => path),
      ],
    );
    await settleDrift(tester);
    expect(find.text('Choose a .m3u or .m3u8 file'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('wizard-field-file')));
    await settleDrift(tester);
    expect(find.text('Ev Listesi.m3u'), findsOneWidget);
    expect(find.text('Ev Listesi'), findsOneWidget, reason: 'name filled');
    expect(find.text('This is not an M3U playlist'), findsOneWidget);
    expect(checker.calls, ['file $path']);
    await unmountAndFlush(tester);
  });

  testWidgets('create an Xtream playlist, import it from the mock server, '
      'open it', (tester) async {
    final env = (await tester.runAsync(
      () => _createEnv(rootZoneImports: true),
    ))!;
    final checker = FakeSourceChecker(xtream: (_) => okLogin);
    final router = playlistsTestRouter(
      initialLocation: '/playlists/new?type=xtream',
    );
    await pumpScreen(
      tester,
      routerHost(router),
      overrides: env.overrides(checker),
    );
    await settleDrift(tester);
    await _type(tester, 'name', 'Mock TV');
    await _focus(tester, 'server');
    await _type(tester, 'server', server.baseUrl);
    await _focus(tester, 'username');
    await _type(tester, 'username', MockFixtures.username);
    await _focus(tester, 'password');
    await _type(tester, 'password', MockFixtures.password);
    await tester.tap(find.byKey(const ValueKey('wizard-save')));
    await pumpUntil(
      tester,
      () => router.state.uri.path.startsWith('/p/'),
      rounds: 400,
    );
    final row = (await tester.runAsync(env.repository.getAll))!.single;
    expect(router.state.uri.toString(), '/p/${row.id}/live');
    expect(row.liveCount, greaterThan(0));
    expect(row.movieCount, greaterThan(0));
    expect(row.seriesCount, greaterThan(0));
    expect(row.lastReloadAt, isNotNull);
    expect(row.epgUrl, isNull, reason: 'default guide, no password stored');
    expect(
      await tester.runAsync(
        () => env.secrets.read(SecretStore.playlistPassword(row.id)),
      ),
      MockFixtures.password,
    );
    expect(find.text('Playlist ready'), findsOneWidget);
    await unmountAndFlush(tester);
    await tester.runAsync(env.imports.dispose);
  });

  testWidgets('edit: name only saves; EPG shift reloads the guide; source '
      'reloads everything', (tester) async {
    final fx = (await tester.runAsync(() => importMockPlaylist()))!;
    final imports = FakeImportService(
      db: fx.db,
      paths: fx.paths,
      secrets: fx.secrets,
      settings: fx.settings,
    );
    final router = playlistsTestRouter(
      initialLocation: '/playlists/${fx.playlistId}/edit',
    );
    final repository = PlaylistRepository(fx.db, fx.secrets, fx.settings);
    await pumpScreen(
      tester,
      routerHost(router),
      overrides: [
        appDatabaseProvider.overrideWithValue(fx.db),
        appPathsProvider.overrideWithValue(fx.paths),
        settingsStoreProvider.overrideWithValue(fx.settings),
        secretStoreProvider.overrideWithValue(fx.secrets),
        importServiceProvider.overrideWithValue(imports),
        playlistSourceCheckerProvider.overrideWithValue(
          FakeSourceChecker(xtream: (_) => okLogin),
        ),
      ],
    );
    await settleDrift(tester);
    expect(find.text('03 / Name your playlist'), findsOneWidget);
    expect(find.text('Kanal Demo'), findsOneWidget);
    expect(find.text(fx.server.baseUrl), findsOneWidget);
    // The default guide URL carries the password: never shown.
    expect(find.textContaining('xmltv.php'), findsNothing);
    expect(find.text('EPG URL · Default: provider guide'), findsOneWidget);
    expect(find.byKey(const ValueKey('wizard-cancel')), findsOneWidget);

    // 1. Name only: saved, no reload, back to the Manager.
    await _type(tester, 'name', 'Kanal Demo HD');
    await tester.tap(find.byKey(const ValueKey('wizard-save')));
    await settleDrift(tester);
    expect(find.text('Playlist saved'), findsOneWidget);
    expect(router.state.uri.toString(), '/');
    expect(imports.started, isEmpty);
    expect(
      (await tester.runAsync(() => repository.get(fx.playlistId)))?.name,
      'Kanal Demo HD',
    );

    // 2. EPG time shift: guide-only import.
    router.go('/playlists/${fx.playlistId}/edit');
    await settleDrift(tester);
    await tester.tap(find.byKey(const ValueKey('wizard-field-epgShift')));
    await settle(tester);
    await tester.tap(find.text('+1'));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('wizard-save')));
    await pumpUntil(tester, () => imports.started.isNotEmpty);
    expect(imports.started.single, (fx.playlistId, ImportScope.epg));
    expect(
      router.state.uri.toString(),
      '/playlists/${fx.playlistId}/import?scope=epg',
    );

    // 3. A new password changes the source: everything reloads.
    router.go('/playlists/${fx.playlistId}/edit');
    await settleDrift(tester);
    await _type(tester, 'password', 'test1234');
    await tester.tap(find.byKey(const ValueKey('wizard-save')));
    await pumpUntil(tester, () => imports.started.length == 2);
    expect(imports.started.last, (fx.playlistId, ImportScope.all));
    expect(
      await tester.runAsync(
        () => fx.secrets.read(SecretStore.playlistPassword(fx.playlistId)),
      ),
      'test1234',
    );
    await unmountAndFlush(tester);
    await tester.runAsync(fx.dispose);
  });
}
