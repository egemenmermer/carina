/// Finds the address other devices on the home network can reach this one
/// on (for Add from phone). The ranking is pure so it is unit-tested.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';

/// One IPv4 address of a network interface.
class LanCandidate {
  const LanCandidate(this.interfaceName, this.address);

  final String interfaceName;
  final InternetAddress address;
}

/// Interface names that are virtual, tunnels or mobile data: never a home
/// network a phone can join.
final RegExp _virtualInterface = RegExp(
  r'(docker|veth|^br-|bridge|vmnet|vbox|virtual|vethernet|utun|^tun|^tap|'
  r'ppp|rmnet|p2p|awdl|llw|dummy|wsl|hyper-v|loopback)',
  caseSensitive: false,
);

/// Wi-Fi and Ethernet names on Android (`wlan0`, `eth0`), macOS (`en0`) and
/// Windows (`Wi-Fi`, `Ethernet`).
final RegExp _homeInterface = RegExp(
  r'^(wlan|wifi|wi-fi|eth|en\d|ethernet)',
  caseSensitive: false,
);

/// RFC 1918 private IPv4 (10/8, 172.16/12, 192.168/16).
bool isPrivateIPv4(InternetAddress address) {
  if (address.type != InternetAddressType.IPv4) return false;
  final b = address.rawAddress;
  if (b.length != 4) return false;
  return b[0] == 10 ||
      (b[0] == 172 && b[1] >= 16 && b[1] <= 31) ||
      (b[0] == 192 && b[1] == 168);
}

/// The best private IPv4 of [candidates]: Wi-Fi / Ethernet first, then any
/// other real interface; virtual ones, link-local and public addresses never
/// qualify. Null when nothing does.
InternetAddress? pickLanAddress(Iterable<LanCandidate> candidates) {
  InternetAddress? best;
  var bestScore = 0;
  for (final c in candidates) {
    if (!isPrivateIPv4(c.address)) continue;
    if (_virtualInterface.hasMatch(c.interfaceName)) continue;
    final score = _homeInterface.hasMatch(c.interfaceName) ? 2 : 1;
    if (score > bestScore) {
      best = c.address;
      bestScore = score;
    }
  }
  return best;
}

/// Looks the interfaces up. Null when the device has no usable LAN address
/// (or the platform refuses to list them).
Future<InternetAddress?> findLanAddress() async {
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );
    return pickLanAddress([
      for (final i in interfaces)
        for (final a in i.addresses) LanCandidate(i.name, a),
    ]);
  } on Object catch (error) {
    debugPrint('Listing network interfaces failed: ${error.runtimeType}');
    return null;
  }
}
