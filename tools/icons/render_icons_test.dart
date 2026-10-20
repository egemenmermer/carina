// Renders the Carina app icon PNGs from the same painter the app uses
// (lib/core/brand/carina_mark.dart), so the icon can never drift from the mark.
//
// Not part of the unit test suite (it lives outside test/). Run it through
// tools/icons/build_icons.sh, which also builds the .ico and copies the PNGs
// to the macOS and brand folders. Output folder: $CARINA_ICON_OUT or
// tools/icons/png.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/core/brand/carina_mark.dart';

/// Every size any platform asks for (Windows .ico, macOS AppIcon set, brand).
const iconSizes = <int>[16, 20, 24, 32, 40, 48, 64, 128, 256, 512, 1024];

/// Tile colour from docs/ARCHITECTURE.md section 5; the mark keeps its
/// brand gradient.
const tileBlack = Color(0xFF000000);

Future<List<int>> renderIcon(int size) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const CarinaMarkPainter(background: tileBlack).paint(canvas, Size.square(size.toDouble()));
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

void main() {
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
}
