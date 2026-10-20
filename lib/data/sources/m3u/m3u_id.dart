// Stable provider ids for M3U entries.

import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'm3u_models.dart';

/// Stable provider id of an entry, used as `providerId` in the database so
/// favorites and watch state survive a reload: the first 16 hex characters
/// of `sha1("<tvg-id>|<url>")` (empty tvg-id when missing). The URL is the
/// one without the `|header` suffix.
///
/// Two identical lines (same tvg-id and URL, e.g. one channel listed in two
/// groups) get the same id; the importer keeps one of them.
String m3uEntryId(M3uEntry entry) => sha1
    .convert(utf8.encode('${entry.tvgId ?? ''}|${entry.url}'))
    .toString()
    .substring(0, 16);
