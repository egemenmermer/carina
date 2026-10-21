import 'package:carina/app/platform/form_factor.dart';
import 'package:carina/data/app_paths.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/secrets/secret_store.dart';
import 'package:carina/data/settings/settings_store.dart';
import 'package:carina/features/playlists/data/phone_setup_page.dart';
import 'package:carina/features/playlists/data/phone_setup_server.dart';
import 'package:carina/features/playlists/data/source_checker.dart';
import 'package:carina/features/playlists/data/wizard_form.dart';
import 'package:carina/features/playlists/playlist_wizard_screen.dart';
import 'package:carina/features/playlists/widgets/phone_setup_panel.dart';
import 'package:carina/l10n/gen/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/drift_widgets.dart';
import '../../support/screenshot.dart';
import 'support/playlists_harness.dart';

class _FakeHandle implements PhoneSetupHandle {
  _FakeHandle(this.url);

  @override
  final Uri url;
  int closed = 0;

  @override
  Future<void> close() async => closed++;
}

/// A starter that records what the panel asked for.
class _FakeStarter {
  _FakeStarter({this.noNetwork = false});

  final bool noNetwork;
  final List<_FakeHandle> handles = [];
  String? page;
  void Function(WizardValues values)? submit;
  void Function()? expire;

  Future<PhoneSetupHandle?> call({
    required String page,
    required void Function(WizardValues values) onSubmitted,
    required void Function() onExpired,
  }) async {
    if (noNetwork && handles.isEmpty) {
      handles.add(_FakeHandle(Uri()));
      return null;
    }
    this.page = page;
    submit = onSubmitted;
    expire = onExpired;
    final handle = _FakeHandle(
      Uri.parse('http://192.168.1.20:41234/abcDEF123_tokenTOKEN'),
    );
    handles.add(handle);
    return handle;
  }
}

Future<List<Override>> _overrides(
  WidgetTester tester,
  FormFactor formFactor,
  _FakeStarter starter,
  FakeSourceChecker checker,
) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final settings = SettingsStore(db);
  late AppPaths paths;
  await tester.runAsync(() async {
    await settings.load();
    paths = await tempAppPaths();
  });
  addTearDown(() => tester.runAsync(db.close));
  return [
    appDatabaseProvider.overrideWithValue(db),
    appPathsProvider.overrideWithValue(paths),
    settingsStoreProvider.overrideWithValue(settings),
    secretStoreProvider.overrideWithValue(MemorySecretStore()),
    formFactorProvider.overrideWithValue(formFactor),
    playlistSourceCheckerProvider.overrideWithValue(checker),
    phoneSetupStarterProvider.overrideWithValue(starter.call),
  ];
}

Future<void> _pumpWizard(
  WidgetTester tester,
  FormFactor formFactor,
  _FakeStarter starter,
  FakeSourceChecker checker,
) async {
  await pumpScreen(
    tester,
    const PlaylistWizardScreen(),
    size: const Size(960, 540),
    overrides: await _overrides(tester, formFactor, starter, checker),
  );
}

String _text(WidgetTester tester, String field) => tester
    .widget<TextField>(
      find.descendant(
        of: find.byKey(ValueKey('wizard-field-$field')),
        matching: find.byType(TextField),
      ),
    )
    .controller!
    .text;

void main() {
  setUpAll(loadAppFonts);

  testWidgets('TV: "Use your phone" shows the QR code and the address', (
    tester,
  ) async {
    final starter = _FakeStarter();
    await _pumpWizard(tester, FormFactor.tv, starter, FakeSourceChecker());
    expect(find.byKey(const ValueKey('wizard-source-phone')), findsOneWidget);
    expect(find.text('Use your phone'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('wizard-source-phone')));
    await settle(tester);
    expect(starter.handles, hasLength(1));
    expect(find.byKey(const ValueKey('phone-setup-qr')), findsOneWidget);
    expect(
      find.text('http://192.168.1.20:41234/abcDEF123_tokenTOKEN'),
      findsOneWidget,
    );
    expect(find.text('Waiting for your phone…'), findsOneWidget);
    // The page the phone gets follows the app language.
    expect(starter.page, contains('<html lang="en">'));

    // Back returns to the source choice and stops the server.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.byKey(const ValueKey('wizard-source-xtream')), findsOneWidget);
    expect(find.byKey(const ValueKey('phone-setup-qr')), findsNothing);
    expect(starter.handles.single.closed, 1);
    await unmountAndFlush(tester);
  });

  testWidgets('TV: a phone submission fills the form and focuses Save', (
    tester,
  ) async {
    final starter = _FakeStarter();
    final checker = FakeSourceChecker();
    await _pumpWizard(tester, FormFactor.tv, starter, checker);
    await tester.tap(find.byKey(const ValueKey('wizard-source-phone')));
    await settle(tester);

    starter.submit!(
      WizardValues(
        type: PlaylistType.xtream,
        name: 'tv.example.com',
        server: 'http://tv.example.com:8080',
        username: 'alice',
        password: 's3cret',
      ),
    );
    await settle(tester);

    expect(find.byKey(const ValueKey('phone-setup-qr')), findsNothing);
    expect(_text(tester, 'name'), 'tv.example.com');
    expect(_text(tester, 'server'), 'http://tv.example.com:8080');
    expect(_text(tester, 'username'), 'alice');
    expect(_text(tester, 'password'), 's3cret');
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'wizard-save');
    expect(
      find.text('Details received from your phone. Check them, then save.'),
      findsOneWidget,
    );
    // The usual live check ran on the received login.
    expect(checker.calls, contains('xtream http://tv.example.com:8080'));
    // The panel (and its server) is gone.
    expect(starter.handles.single.closed, 1);
    await unmountAndFlush(tester);
  });

  testWidgets('TV: no home network shows a message and a retry', (
    tester,
  ) async {
    final starter = _FakeStarter(noNetwork: true);
    await _pumpWizard(tester, FormFactor.tv, starter, FakeSourceChecker());
    await tester.tap(find.byKey(const ValueKey('wizard-source-phone')));
    await settle(tester);
    expect(find.textContaining('not on a home network'), findsOneWidget);
    expect(find.byKey(const ValueKey('phone-setup-url')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('phone-setup-retry')));
    await settle(tester);
    expect(find.byKey(const ValueKey('phone-setup-url')), findsOneWidget);
    await unmountAndFlush(tester);
  });

  testWidgets('TV: an expired link offers a retry', (tester) async {
    final starter = _FakeStarter();
    await _pumpWizard(tester, FormFactor.tv, starter, FakeSourceChecker());
    await tester.tap(find.byKey(const ValueKey('wizard-source-phone')));
    await settle(tester);
    starter.expire!();
    await settle(tester);
    expect(find.text('The link expired after 10 minutes.'), findsOneWidget);
    expect(find.byKey(const ValueKey('phone-setup-retry')), findsOneWidget);
    await unmountAndFlush(tester);
  });

  testWidgets('desktop: the wizard has no phone option', (tester) async {
    final starter = _FakeStarter();
    await _pumpWizard(tester, FormFactor.desktop, starter, FakeSourceChecker());
    expect(find.byKey(const ValueKey('wizard-source-xtream')), findsOneWidget);
    expect(find.byKey(const ValueKey('wizard-source-phone')), findsNothing);
    expect(starter.handles, isEmpty);
    await unmountAndFlush(tester);
  });

  group('phone page', () {
    test('is in the app language and carries every text', () async {
      final en = await L10n.delegate.load(const Locale('en'));
      final tr = await L10n.delegate.load(const Locale('tr'));
      final enPage = buildPhoneSetupPage(
        lang: 'en',
        strings: phoneSetupStrings(en),
      );
      final trPage = buildPhoneSetupPage(
        lang: tr.localeName,
        strings: phoneSetupStrings(tr),
      );
      expect(enPage, contains('<html lang="en">'));
      expect(enPage, contains('Send to TV'));
      expect(trPage, contains('<html lang="tr">'));
      expect(trPage, contains('TV\'ye gönder'));
      expect(trPage, isNot(contains('Send to TV')));

      // Every text the markup and script ask for exists.
      final strings = phoneSetupStrings(en);
      final used = RegExp(r'data-(?:s|ph)="(\w+)"')
          .allMatches(enPage)
          .map((m) => m[1]!)
          .toSet();
      expect(used, isNotEmpty);
      expect(strings.keys, containsAll(used));
      for (final problem in WizardProblem.values) {
        if (problem == WizardProblem.file) continue;
        expect(strings, contains('e_${problem.name}'));
      }
    });

    test('keeps injected texts from closing the script', () {
      final page = buildPhoneSetupPage(
        lang: 'en"><script>',
        strings: {'title': '</script><script>alert(1)</script>'},
      );
      expect(page, contains('<html lang="en">'));
      expect(page, isNot(contains('<script>alert(1)')));
      expect(page, contains(r'\u003c/script\u003e'));
    });
  });
}
