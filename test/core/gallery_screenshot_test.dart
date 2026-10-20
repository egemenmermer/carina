import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carina/core/core.dart';

import '../support/screenshot.dart';
import 'gallery/gallery_widgets.dart';

Future<TestGesture> _hover(WidgetTester tester, Finder finder) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: tester.getCenter(finder));
  addTearDown(gesture.removePointer);
  await tester.pump();
  return gesture;
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('gallery: nav, pills, buttons, badges, progress, row, FAB', (
    tester,
  ) async {
    await pumpScreen(tester, const GalleryNavControls());
    await _hover(tester, find.byType(GalleryContinueCard).at(1));
    await settle(tester);
    await saveScreen(tester, 'gallery_nav_controls');
  });

  testWidgets('gallery: TV Live horizontal + toast', (tester) async {
    await pumpScreen(tester, const GalleryLive());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(GalleryLive)),
    );
    container
        .read(toastControllerProvider)
        .show('Parental control channels updated');
    await settle(tester, maxFrames: 10);
    await saveScreen(tester, 'gallery_live_toast');
    // Let the toast time out so the test ends without pending timers.
    await tester.pump(const Duration(seconds: 3));
    await settle(tester);
  });

  testWidgets('gallery: TV Live grid + context menu', (tester) async {
    await pumpScreen(tester, const GalleryLiveGrid());
    final card = find.byType(GalleryGridChannelCard).at(5);
    final center = tester.getCenter(card);
    await tester.tapAt(
      center + const Offset(40, 10),
      buttons: kSecondaryButton,
    );
    await settle(tester);
    // Keyboard highlight → white pill on the second row.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await settle(tester);
    await saveScreen(tester, 'gallery_context_menu');
  });

  testWidgets('gallery: playlist manager + titled menu', (tester) async {
    await pumpScreen(tester, const GalleryPlaylistManager());
    final avatar = find.byKey(const ValueKey('playlist-Spor Paketi'));
    await tester.tapAt(
      tester.getCenter(avatar) + const Offset(30, 20),
      buttons: kSecondaryButton,
    );
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await settle(tester);
    await saveScreen(tester, 'gallery_playlist_menu');
  });

  testWidgets('gallery: settings page', (tester) async {
    await pumpScreen(tester, const GallerySettings());
    await _hover(tester, find.byKey(const Key('resolution-row')));
    await settle(tester);
    await saveScreen(tester, 'gallery_settings');
  });

  testWidgets('gallery: wizard text fields', (tester) async {
    await pumpScreen(tester, const GalleryForms());
    await saveScreen(tester, 'gallery_forms');
  });

  testWidgets('gallery: chooser', (tester) async {
    await pumpScreen(tester, const GallerySettings());
    final context = tester.element(find.byType(GallerySettings));
    showChooser<String>(
      context,
      title: 'Aspect ratio',
      description:
          'Force the aspect ratio of the video player (if supported by the '
          'type of player used).',
      selected: 'auto',
      choices: const [
        KChoice(value: 'auto', label: 'Auto'),
        KChoice(value: 'fill', label: 'Fill'),
        KChoice(value: 'crop', label: 'Crop'),
        KChoice(value: '16:9', label: '16:9'),
        KChoice(value: '4:3', label: '4:3'),
      ],
    );
    await settle(tester);
    await saveScreen(tester, 'gallery_chooser');
  });

  testWidgets('gallery: PIN pad', (tester) async {
    await pumpScreen(tester, const GalleryForms());
    final context = tester.element(find.byType(GalleryForms));
    showPinPad(
      context,
      title: 'Enter PIN',
      subtitle: 'Çocuk Kanalı is locked',
      validate: (pin) async => pin == '1234',
    );
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await settle(tester);
    await saveScreen(tester, 'gallery_pin_pad');
  });

  testWidgets('gallery: player popover', (tester) async {
    final audioKey = GlobalKey();
    await pumpScreen(tester, GalleryPlayer(audioButtonKey: audioKey));
    final context = tester.element(find.byType(GalleryPlayer));
    showKPopoverMenu(
      context,
      anchorRect: tester.getRect(find.byKey(audioKey)),
      sections: (_) => galleryAudioSections(0.3),
    );
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await settle(tester);
    await saveScreen(tester, 'gallery_popover');
  });

  testWidgets('gallery: archive sheet', (tester) async {
    await pumpScreen(tester, const GalleryLive());
    final context = tester.element(find.byType(GalleryLive));
    showKSheet<void>(context, width: 640, child: const GalleryArchiveSheet());
    await settle(tester);
    await saveScreen(tester, 'gallery_sheet');
  });

  testWidgets('gallery: avatar picker', (tester) async {
    await pumpScreen(tester, const GalleryAvatarPicker());
    await saveScreen(tester, 'gallery_avatar_picker');
  });

  testWidgets('gallery: all avatars, logo tiles, states', (tester) async {
    await pumpScreen(tester, const GalleryAvatarsAll());
    await saveScreen(tester, 'gallery_avatars_states');
  });
}
