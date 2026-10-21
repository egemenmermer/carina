import 'package:flutter_test/flutter_test.dart';
import 'package:carina/app/launch_options.dart';

void main() {
  test('parses smoke test flags and ignores foreign arguments', () {
    final o = LaunchOptions.parse([
      '-NSDocumentRevisionsDebugMode',
      'YES',
      '--smoke-test',
      '--mock-url',
      'http://127.0.0.1:9000',
      '--smoke-out=out.json',
      '--unknown',
    ]);
    expect(o.smokeTest, isTrue);
    expect(o.mock, isTrue);
    expect(o.mockUrl, 'http://127.0.0.1:9000');
    expect(o.smokeOut, 'out.json');
    expect(o.wantsMockPlaylist, isTrue);
  });

  test('capture implies the mock playlist', () {
    final o = LaunchOptions.parse(['--capture', 'shots']);
    expect(o.capture, isTrue);
    expect(o.captureDir, 'shots');
    expect(o.wantsMockPlaylist, isTrue);
    expect(o.mockUrl, LaunchOptions.defaultMockUrl);
  });

  test('no flags gives defaults', () {
    final o = LaunchOptions.parse(const []);
    expect(o.smokeTest, isFalse);
    expect(o.capture, isFalse);
    expect(o.wantsMockPlaylist, isFalse);
  });

  test(
    '--tv forces the TV form factor and is kept among foreign arguments',
    () {
      final o = LaunchOptions.parse([
        '-NSDocumentRevisionsDebugMode',
        'YES',
        '--tv',
      ]);
      expect(o.tv, isTrue);
      expect(LaunchOptions.parse(const []).tv, isFalse);
      expect(LaunchOptions.parse(['--mock', '--tv']).mock, isTrue);
    },
  );
}
