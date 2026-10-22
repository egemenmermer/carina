// Renders the Carina app icon PNGs from the same painter the app uses
// (lib/core/brand/carina_mark.dart), so the icon can never drift from the mark.
//
// Not part of the unit test suite (it lives outside test/). Run it through
// tools/icons/build_icons.sh, which also builds the .ico and copies the PNGs
// to the macOS and brand folders. Output folder: $CARINA_ICON_OUT or
// tools/icons/png.
//
// Besides the app icon it renders the Android launcher foreground (the mark on
// transparent, inside the adaptive-icon safe zone) and the Android TV banner
// (320x180, Inter wordmark next to the mark).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/core/brand/carina_mark.dart';

import '../../test/support/screenshot.dart' show loadAppFonts;

/// Every size any platform asks for (Windows .ico, macOS AppIcon set, Android
/// legacy launcher mdpi..xxxhdpi = 48/72/96/144/192, brand).
const iconSizes = <int>[
  16,
  20,
  24,
  32,
  40,
  48,
  64,
  72,
  96,
  128,
  144,
  192,
  256,
  512,
  1024,
];

/// Adaptive-icon foreground layers: 108 dp at mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi.
const foregroundSizes = <int>[108, 162, 216, 324, 432];

/// Android TV banner size in pixels (drawable-xhdpi).
const bannerWidth = 320;
const bannerHeight = 180;

Future<List<int>> renderIcon(int size) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const CarinaMarkPainter(tile: true)
      .paint(canvas, Size.square(size.toDouble()));
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

Future<List<int>> _encode(
  ui.PictureRecorder recorder,
  int width,
  int height,
) async {
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

/// Centre of the mark's bounding box on the 64 grid.
final _markCentre = CarinaMarkPainter.markBounds.center;

/// Mark alone on transparent, sized for an adaptive-icon foreground layer.
/// The layer is 108 dp; the launcher shows at most the central 66 dp circle, so
/// the 64 grid is shown 96.4 grid units wide: the mark is about 57 dp wide and
/// 46 dp tall, so its tips stay inside that circle.
Future<List<int>> renderForeground(int size) async {
  const canvasUnits = 96.4;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas
    ..translate(size / 2, size / 2)
    ..scale(size / canvasUnits)
    ..translate(-_markCentre.dx, -_markCentre.dy);
  const CarinaMarkPainter().paint(canvas, const Size.square(64));
  return _encode(recorder, size, size);
}

/// Android TV launcher banner: the navy tile gradient, the mark and the Inter
/// wordmark, centred
/// as one group. Needs the app fonts (see [loadAppFonts]).
Future<List<int>> renderTvBanner() async {
  const bounds = CarinaMarkPainter.markBounds;
  const markScale = 2.0; // mark is ~41 grid units tall -> 82 px
  const gap = 18.0;
  final markWidth = bounds.width * markScale;
  final markCentreY = bounds.center.dy;

  final text = TextPainter(
    text: const TextSpan(
      text: 'Carina',
      style: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w600,
        fontSize: 40,
        letterSpacing: -0.8,
        color: Color(0xFFFFFFFF),
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  // Inter cap height is 1490/2048 em; centre the capitals on the banner axis.
  final capHeight = 40 * 1490 / 2048;
  final baseline = text.computeDistanceToActualBaseline(
    TextBaseline.alphabetic,
  );

  const centreY = bannerHeight / 2;
  final groupWidth = markWidth + gap + text.width;
  final left = (bannerWidth - groupWidth) / 2;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 320, 180),
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: CarinaMarkPainter.tileColors,
      ).createShader(const Rect.fromLTWH(0, 0, 320, 180)),
  );
  canvas
    ..save()
    ..translate(
      left - bounds.left * markScale,
      centreY - markCentreY * markScale,
    )
    ..scale(markScale);
  const CarinaMarkPainter().paint(canvas, const Size.square(64));
  canvas.restore();
  text.paint(
    canvas,
    Offset(left + markWidth + gap, centreY + capHeight / 2 - baseline),
  );
  return _encode(recorder, bannerWidth, bannerHeight);
}

void main() {
  setUpAll(loadAppFonts);

  test('renders the Carina app icon at every size', () async {
    final outDir = Directory(
      Platform.environment['CARINA_ICON_OUT'] ?? 'tools/icons/png',
    )..createSync(recursive: true);
    for (final size in iconSizes) {
      final png = await renderIcon(size);
      final file = File('${outDir.path}/carina_icon_$size.png');
      file.writeAsBytesSync(png);
      expect(file.lengthSync(), greaterThan(0));
    }
  });

  test('renders the Android adaptive-icon foreground layers', () async {
    final outDir = Directory(
      Platform.environment['CARINA_ICON_OUT'] ?? 'tools/icons/png',
    )..createSync(recursive: true);
    for (final size in foregroundSizes) {
      final file = File('${outDir.path}/carina_foreground_$size.png');
      file.writeAsBytesSync(await renderForeground(size));
      expect(file.lengthSync(), greaterThan(0));
    }
  });

  test('renders the Android TV banner', () async {
    final outDir = Directory(
      Platform.environment['CARINA_ICON_OUT'] ?? 'tools/icons/png',
    )..createSync(recursive: true);
    final file = File('${outDir.path}/tv_banner.png')
      ..writeAsBytesSync(await renderTvBanner());
    expect(file.lengthSync(), greaterThan(0));
  });
}
