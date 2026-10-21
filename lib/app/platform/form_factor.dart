import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The kind of screen Carina runs on. UI gates (hidden Downloads, the
/// multi-channel cap) read [formFactorProvider]; OS integrations (wakelock,
/// notifications) check `Platform.isAndroid` instead, so `--tv` on a desktop
/// reproduces the TV layout without touching Android-only plugins.
enum FormFactor {
  /// macOS / Windows window with mouse and keyboard.
  desktop,

  /// Android TV / Google TV with a remote.
  tv;

  bool get isTv => this == FormFactor.tv;
}

/// Channel implemented in `MainActivity.kt`: `isTv` → bool.
const MethodChannel kPlatformChannel = MethodChannel(
  'app.carina.player/platform',
);

/// Decides the form factor once, at bootstrap.
///
/// - [forceTv] (`--tv`) wins on every platform.
/// - On Android the native side answers (UI mode television or the leanback
///   feature). The Android build is TV-only, so when the channel fails any
///   Android device counts as a TV.
/// - Everything else is [FormFactor.desktop].
///
/// [isAndroid] and [channel] exist for tests.
Future<FormFactor> resolveFormFactor({
  bool forceTv = false,
  bool? isAndroid,
  MethodChannel channel = kPlatformChannel,
}) async {
  if (forceTv) return FormFactor.tv;
  if (!(isAndroid ?? (!kIsWeb && Platform.isAndroid))) {
    return FormFactor.desktop;
  }
  try {
    final tv = await channel.invokeMethod<bool>('isTv');
    return tv == false ? FormFactor.desktop : FormFactor.tv;
  } catch (e) {
    debugPrint('Form factor detection failed, assuming TV: $e');
    return FormFactor.tv;
  }
}

/// Overridden at bootstrap; desktop by default so widget tests keep the
/// desktop layout.
final formFactorProvider = Provider<FormFactor>((ref) => FormFactor.desktop);
