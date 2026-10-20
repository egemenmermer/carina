import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carina/core/core.dart';

import '../support/test_app.dart';

class _FakeWindow extends KWindowControls {
  final calls = <String>[];
  final ValueNotifier<bool> _max = ValueNotifier(false);

  @override
  ValueListenable<bool> get isMaximized => _max;

  @override
  Future<void> startDragging() async => calls.add('drag');

  @override
  Future<void> minimize() async => calls.add('min');

  @override
  Future<void> toggleMaximize() async {
    calls.add('max');
    _max.value = !_max.value;
  }

  @override
  Future<void> close() async => calls.add('close');
}

void main() {
  group('tokens', () {
    test('accent and surfaces keep their values', () {
      expect(KColors.bg, const Color(0xFF000000));
      expect(KColors.accent, const Color(0xFFFF2500));
      expect(KColors.surface1, const Color(0xFF0D0D0D));
      expect(KRadii.card, 10);
      expect(KRadii.contextMenu, 18);
      expect(KDurations.hover, const Duration(milliseconds: 120));
      expect(KDurations.toast, const Duration(milliseconds: 2500));
      expect(
        KText.time.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });

    testWidgets('KMotion follows MediaQuery.disableAnimations', (tester) async {
      late bool reduced;
      late Duration d;
      Widget probe(bool disable) => MediaQuery(
        data: MediaQueryData(disableAnimations: disable),
        child: Builder(
          builder: (context) {
            reduced = KMotion.reduced(context);
            d = KMotion.of(context, KDurations.menu);
            return const SizedBox();
          },
        ),
      );
      await tester.pumpWidget(probe(true));
      expect(reduced, isTrue);
      expect(d, Duration.zero);
      await tester.pumpWidget(probe(false));
      expect(reduced, isFalse);
      expect(d, KDurations.menu);
    });

    test('theme is dark, pure black, Inter, no ink splash', () {
      final theme = buildCarinaTheme();
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, KColors.bg);
      expect(theme.textTheme.bodyMedium!.fontFamily, 'Inter');
      expect(theme.splashFactory, NoSplash.splashFactory);
      expect(theme.textSelectionTheme.cursorColor, KColors.accent);
    });
  });

  group('avatars', () {
    test('catalog has ≥ 48 unique avatars in six categories', () {
      expect(AvatarCatalog.all.length, greaterThanOrEqualTo(48));
      final ids = AvatarCatalog.all.map((a) => a.id).toSet();
      expect(ids.length, AvatarCatalog.all.length);
      for (final c in AvatarCategory.values) {
        expect(AvatarCatalog.byCategory(c), isNotEmpty, reason: c.name);
      }
      for (final a in AvatarCatalog.all) {
        final glyphs = [a.emoji != null, a.shape != null, a.usesInitials];
        expect(glyphs.where((g) => g).length, 1, reason: a.id);
        expect(a.gradient, hasLength(2));
      }
    });

    test('lookup and deterministic defaults', () {
      expect(AvatarCatalog.byId('animal-fox')!.emoji, '🦊');
      expect(AvatarCatalog.byId('nope'), isNull);
      expect(AvatarCatalog.byId(null), isNull);
      expect(
        AvatarCatalog.defaultFor('Home IPTV').id,
        AvatarCatalog.defaultFor('Home IPTV').id,
      );
      expect(AvatarCatalog.defaultFor('Home IPTV').usesInitials, isFalse);
      expect(AvatarCatalog.initialsFor('x').usesInitials, isTrue);
    });

    test('monogram initials ignore quality tokens and prefixes', () {
      expect(KMonogram.initialsOf('TRT 1 HD'), 'T1');
      expect(KMonogram.initialsOf('Show TV FHD'), 'ST');
      expect(KMonogram.initialsOf('TR: Haber Canlı'), 'HC');
      expect(KMonogram.initialsOf('|TR| Spor Arena'), 'SA');
      expect(KMonogram.initialsOf('Çocuk Kilitli'), 'ÇK');
      expect(KMonogram.initialsOf('NTV'), 'NT');
      expect(KMonogram.initialsOf('  '), '?');
      expect(KMonogram.stableHash('abc'), KMonogram.stableHash('abc'));
    });

    testWidgets('KAvatar renders every catalog entry and unknown ids', (
      tester,
    ) async {
      await tester.pumpWidget(
        carinaTestApp(
          Wrap(
            children: [
              for (final a in AvatarCatalog.all)
                KAvatar(a.id, 40, fallbackName: 'Ev TV'),
              const KAvatar(null, 40, fallbackName: 'Kanal Test'),
              const KAvatar('missing', 40),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('KT'), findsOneWidget);
      expect(find.text('?'), findsOneWidget);
      expect(find.text('ET'), findsNWidgets(8));
    });
  });

  group('images', () {
    tearDown(() => KImageLoader.debugFetchOverride = null);

    test('loads fail fast under flutter test (no network)', () async {
      await expectLater(
        KImageLoader.instance.load('https://example.invalid/logo.png'),
        throwsA(isA<KImageLoadException>()),
      );
    });

    test('debugFetchOverride supplies bytes', () async {
      KImageLoader.debugFetchOverride = (url) async =>
          Uint8List.fromList([1, 2]);
      expect(await KImageLoader.instance.load('x'), [1, 2]);
    });

    testWidgets('KImage shows the error fallback when loading fails', (
      tester,
    ) async {
      await tester.pumpWidget(
        carinaTestApp(
          SizedBox(
            width: 120,
            height: 80,
            child: KImage(
              'https://example.invalid/poster.jpg',
              errorBuilder: (_) => const Text('fallback'),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('fallback'), findsOneWidget);
    });

    testWidgets('KLogoTile falls back to the monogram', (tester) async {
      await tester.pumpWidget(
        carinaTestApp(
          const Column(
            children: [
              KLogoTile(
                name: 'Show TV FHD',
                url: 'https://example.invalid/a.png',
              ),
              KLogoTile(name: 'Kanal D'),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('ST'), findsOneWidget);
      expect(find.text('KD'), findsOneWidget);
    });
  });

  group('top nav', () {
    const tabs = [
      KNavTab(id: 'movies', label: 'Movies'),
      KNavTab(id: 'shows', label: 'Shows'),
      KNavTab.icon(
        id: 'search',
        icon: PhosphorIconsRegular.magnifyingGlass,
        label: 'Search',
      ),
      KNavTab(id: 'settings', label: 'Settings'),
    ];

    testWidgets('tabs, avatar and window gestures call back', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final window = _FakeWindow();
      final selected = <String>[];
      Rect? avatarRect;
      await tester.pumpWidget(
        carinaTestApp(
          KWindowControlsScope(
            controls: window,
            child: Align(
              alignment: Alignment.topCenter,
              child: KTopNav(
                tabs: tabs,
                activeTabId: 'movies',
                onTabSelected: selected.add,
                dateTimeText: 'Wed, May 20 • 00:26',
                avatar: const KAvatar('animal-fox', 44),
                onAvatarTap: (r) => avatarRect = r,
                showCaptionButtons: true,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Wed, May 20 • 00:26'), findsOneWidget);

      await tester.tap(find.text('Shows').last);
      await tester.tap(find.byIcon(PhosphorIconsRegular.magnifyingGlass));
      await tester.pump();
      expect(selected, ['shows', 'search']);

      await tester.tap(find.byType(KAvatar));
      await tester.pump();
      expect(avatarRect, isNotNull);
      expect(avatarRect!.width, greaterThanOrEqualTo(44));

      // Empty bar area: drag moves the window, double-click maximizes.
      await tester.dragFrom(const Offset(300, 60), const Offset(40, 0));
      await tester.pump();
      expect(window.calls, contains('drag'));
      await tester.tapAt(const Offset(1000, 60));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(const Offset(1000, 60));
      await tester.pumpAndSettle();
      expect(window.calls, contains('max'));

      // Caption buttons (forced visible) use the same controls.
      final caption = find.byType(KCaptionButtons);
      final topRight = tester.getTopRight(caption);
      await tester.tapAt(topRight + const Offset(-23, 16)); // close
      await tester.tapAt(topRight + const Offset(-23 - 92, 16)); // minimize
      await tester.pump();
      expect(window.calls, containsAll(['close', 'min']));
    });

    for (final width in [1100.0, 1440.0, 1920.0]) {
      testWidgets('fits a ${width.toInt()} px window, tabs centered', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          carinaTestApp(
            Align(
              alignment: Alignment.topCenter,
              child: KTopNav(
                tabs: tabs,
                activeTabId: 'movies',
                onTabSelected: (_) {},
                dateTimeText: 'Wed, May 20 • 00:26',
                avatar: const KAvatar('animal-fox', 44),
                trailing: const [
                  KProgressChip(label: 'Updating 45%', progress: 0.45),
                ],
                showCaptionButtons: true,
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        final left = tester.getTopLeft(find.text('Movies').first).dx;
        final right = tester.getTopRight(find.text('Settings').first).dx;
        // The label glyph boxes include the reserved bold width; allow a
        // few pixels of slack.
        expect(((left + right) / 2 - width / 2).abs(), lessThan(12));
      });
    }

    testWidgets('without window controls the bar is inert (tests)', (
      tester,
    ) async {
      await tester.pumpWidget(
        carinaTestApp(
          KTopNav(tabs: tabs, activeTabId: 'shows', onTabSelected: (_) {}),
        ),
      );
      await tester.dragFrom(const Offset(20, 30), const Offset(30, 0));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(KWindowControls.platformDefault, isNull);
    });
  });

  group('text field', () {
    testWidgets('focus draws the red outline; the eye toggles obscuring', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'secret');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        carinaTestApp(
          Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                KTextField(
                  label: 'Password',
                  controller: controller,
                  obscure: true,
                ),
                const KTextField(
                  label: 'Server',
                  status: KFieldStatus.ok('Server reachable'),
                ),
                const KTextField(label: 'URL', errorText: 'Unreachable'),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Server reachable'), findsOneWidget);
      expect(find.text('Unreachable'), findsOneWidget);

      TextField field() =>
          tester.widget<TextField>(find.byType(TextField).first);
      expect(field().obscureText, isTrue);
      await tester.tap(find.byIcon(PhosphorIconsLight.eye));
      await tester.pump();
      expect(field().obscureText, isFalse);

      BoxDecoration box() =>
          tester
                  .widget<AnimatedContainer>(
                    find
                        .descendant(
                          of: find.byType(KTextField).first,
                          matching: find.byType(AnimatedContainer),
                        )
                        .first,
                  )
                  .decoration!
              as BoxDecoration;
      expect((box().border! as Border).top.width, 1);
      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();
      final border = box().border! as Border;
      expect(border.top.color, KColors.accent);
      expect(border.top.width, 2);
    });
  });

  group('sheet', () {
    testWidgets('Esc and the × button close the sheet', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        carinaTestApp(
          Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox.expand();
            },
          ),
        ),
      );
      var result = showKSheet<String>(ctx, child: const Text('Series detail'));
      await tester.pumpAndSettle();
      expect(find.text('Series detail'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(await result, isNull);
      expect(find.text('Series detail'), findsNothing);

      // Not dismissible from the backdrop, so only the × can close it.
      result = showKSheet<String>(
        ctx,
        width: 400,
        barrierDismissible: false,
        child: const Text('Archive'),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(KSheetCloseButton)),
        const Size(36, 36),
      );
      await tester.tap(find.byType(KSheetCloseButton));
      await tester.pumpAndSettle();
      expect(find.text('Archive'), findsNothing);
    });
  });
}
