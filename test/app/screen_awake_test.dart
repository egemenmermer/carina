import 'package:carina/app/platform/screen_awake.dart';
import 'package:flutter_test/flutter_test.dart';

class _Recorder implements WakelockBackend {
  final List<String> calls = [];

  @override
  Future<void> enable() async => calls.add('on');

  @override
  Future<void> disable() async => calls.add('off');
}

void main() {
  test('holds while any owner needs it and releases after the last one', () {
    final backend = _Recorder();
    final awake = ScreenAwake(backend);
    final player = Object();
    final multiview = Object();

    awake.hold(multiview);
    awake.hold(player);
    awake.hold(player);
    expect(backend.calls, ['on']);
    expect(awake.isHeld, isTrue);

    awake.release(player);
    expect(backend.calls, ['on']);
    awake.release(player);
    awake.release(multiview);
    expect(backend.calls, ['on', 'off']);
    expect(awake.isHeld, isFalse);
  });
}
