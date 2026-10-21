import 'package:carina/app/platform/form_factor.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test.carina/platform');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void answer(Future<Object?> Function(MethodCall call)? handler) =>
      messenger.setMockMethodCallHandler(channel, handler);

  tearDown(() => answer(null));

  test('desktop by default, also with a channel that would say TV', () async {
    answer((_) async => true);
    expect(
      await resolveFormFactor(isAndroid: false, channel: channel),
      FormFactor.desktop,
    );
  });

  test('--tv forces TV on desktop', () async {
    expect(
      await resolveFormFactor(
        forceTv: true,
        isAndroid: false,
        channel: channel,
      ),
      FormFactor.tv,
    );
  });

  test('Android asks the native side', () async {
    answer((call) async => call.method == 'isTv');
    expect(
      await resolveFormFactor(isAndroid: true, channel: channel),
      FormFactor.tv,
    );
    answer((_) async => false);
    expect(
      await resolveFormFactor(isAndroid: true, channel: channel),
      FormFactor.desktop,
    );
  });

  test('Android counts as TV when the channel fails', () async {
    answer((_) async => throw MissingPluginException());
    expect(
      await resolveFormFactor(isAndroid: true, channel: channel),
      FormFactor.tv,
    );
    answer(null);
    expect(
      await resolveFormFactor(isAndroid: true, channel: channel),
      FormFactor.tv,
    );
  });

  test('the provider defaults to desktop and can be overridden', () {
    final plain = ProviderContainer();
    addTearDown(plain.dispose);
    expect(plain.read(formFactorProvider), FormFactor.desktop);
    final tv = ProviderContainer(
      overrides: [formFactorProvider.overrideWithValue(FormFactor.tv)],
    );
    addTearDown(tv.dispose);
    expect(tv.read(formFactorProvider).isTv, isTrue);
  });
}
