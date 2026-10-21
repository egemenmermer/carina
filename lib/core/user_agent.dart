import 'dart:io';

/// App version used in the default User-Agent.
const String carinaUserAgentVersion = '1.0';

/// `Carina/1.0 (Windows)` on Windows, `Carina/1.0 (macOS)` on macOS,
/// `Carina/1.0 (Android)` on Android (TV).
String defaultUserAgent() {
  final String os;
  if (Platform.isWindows) {
    os = 'Windows';
  } else if (Platform.isMacOS) {
    os = 'macOS';
  } else if (Platform.isAndroid) {
    os = 'Android';
  } else if (Platform.isLinux) {
    os = 'Linux';
  } else {
    os = Platform.operatingSystem;
  }
  return 'Carina/$carinaUserAgentVersion ($os)';
}
