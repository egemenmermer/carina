/// Screenshot harness for widget tests: renders a widget with real fonts
/// (Inter, the Phosphor icon fonts and, when the host has one, the system
/// emoji font) inside the Kanal app shell and writes a PNG to
/// `build/screens/<name>.png`.
///
/// Usage:
///
/// ```dart
/// import 'package:flutter_test/flutter_test.dart';
///
/// import '../support/screenshot.dart';
///
/// void main() {
///   setUpAll(loadAppFonts);
///
///   testWidgets('movies home', (tester) async {
///     await captureScreen(tester, const MoviesHome(), 'movies_home',
///         overrides: [moviesProvider.overrideWith(...)]);
///   });
///
///   // To interact before capturing (open a menu, hover a card):
///   testWidgets('channel menu', (tester) async {
///     await pumpScreen(tester, const LiveScreen());
///     await tester.tap(find.text('TRT 1'), buttons: kSecondaryButton);
///     await settle(tester);
///     await saveScreen(tester, 'live_channel_menu');
///   });
/// }
/// ```
///
/// Network images never load in tests (they show their placeholders) and video
/// renders black.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

export 'test_app.dart';

bool _fontsLoaded = false;

/// System emoji fonts tried after the bundled fonts (first match wins per
/// family). They make emoji avatars and flag prefixes render in captures.
const _emojiFonts = <(String, String)>[
  ('Apple Color Emoji', '/System/Library/Fonts/Apple Color Emoji.ttc'),
  ('Segoe UI Emoji', r'C:\Windows\Fonts\seguiemj.ttf'),
  ('Noto Color Emoji', '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf'),
];

/// Loads every font family listed in FontManifest.json (Inter, the
/// Phosphor icon fonts, MaterialIcons) plus a system emoji font, so text
/// and icons render for real instead of as test boxes. Safe to call more
/// than once; call it from `setUpAll`.
Future<void> loadAppFonts() async {
  if (_fontsLoaded) return;
  TestWidgetsFlutterBinding.ensureInitialized();
  final manifest = json.decode(
    await rootBundle.loadString('FontManifest.json'),
  ) as List<dynamic>;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(entry['family'] as String);
    for (final font
        in (entry['fonts'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
  for (final (family, path) in _emojiFonts) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final bytes = file.readAsBytesSync();
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
  _fontsLoaded = true;
}

final GlobalKey _screenKey = GlobalKey(debugLabel: 'screenshot boundary');

/// Pumps frames until nothing is scheduled (or [maxFrames] is reached, so
/// endless animations such as spinners cannot hang the test).
Future<void> settle(
  WidgetTester tester, {
  Duration step = const Duration(milliseconds: 50),
  int maxFrames = 60,
}) async {
  await tester.pump();
  for (var i = 0; i < maxFrames; i++) {
    if (!tester.binding.hasScheduledFrame) break;
    await tester.pump(step);
  }
}

/// Sets the window to [size] logical pixels at [pixelRatio], pumps [child]
/// in the Kanal shell ([carinaTestApp]) with [overrides], and settles.
/// Follow with interactions and [saveScreen].
Future<void> pumpScreen(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(1440, 900),
  double pixelRatio = 1,
  List<Override> overrides = const [],
  Locale locale = const Locale('en'),
  bool wrapInMaterial = true,
  GlobalKey<NavigatorState>? navigatorKey,
}) async {
  await tester.runAsync(loadAppFonts);
  // Desktop behavior: focus rings show for autofocused widgets as they do
  // on macOS/Windows (tests default to the mobile "touch" highlight mode).
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  addTearDown(
    () => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.automatic,
  );
  tester.view.physicalSize = size * pixelRatio;
  tester.view.devicePixelRatio = pixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _screenKey,
      child: carinaTestApp(
        child,
        overrides: overrides,
        locale: locale,
        wrapInMaterial: wrapInMaterial,
        navigatorKey: navigatorKey,
      ),
    ),
  );
  await settle(tester);
}

void _repaintEverything(WidgetTester tester) {
  void visit(RenderObject object) {
    object.markNeedsPaint();
    object.visitChildren(visit);
  }

  tester.binding.renderViews.forEach(visit);
}

/// Writes the current screen (pumped with [pumpScreen]) to
/// `build/screens/<name>.png` at the view's device pixel ratio.
///
/// flutter_test paints shadows unblurred (`debugDisableShadows`); the
/// capture repaints once with real shadows and restores the flag, because
/// the binding verifies it as soon as the test body returns.
Future<File> saveScreen(WidgetTester tester, String name) async {
  final previousShadows = debugDisableShadows;
  debugDisableShadows = false;
  _repaintEverything(tester);
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_screenKey),
  );
  final file = File('build/screens/$name.png');
  final ratio = tester.view.devicePixelRatio;
  try {
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: ratio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
    });
  } finally {
    debugDisableShadows = previousShadows;
    _repaintEverything(tester);
    await tester.pump();
  }
  return file;
}

/// [pumpScreen] + [saveScreen] in one call: renders [child] at [size]
/// (1440×900 by default) and writes `build/screens/<name>.png`.
Future<File> captureScreen(
  WidgetTester tester,
  Widget child,
  String name, {
  Size size = const Size(1440, 900),
  double pixelRatio = 1,
  List<Override> overrides = const [],
  Locale locale = const Locale('en'),
  bool wrapInMaterial = true,
}) async {
  await pumpScreen(
    tester,
    child,
    size: size,
    pixelRatio: pixelRatio,
    overrides: overrides,
    locale: locale,
    wrapInMaterial: wrapInMaterial,
  );
  return saveScreen(tester, name);
}
