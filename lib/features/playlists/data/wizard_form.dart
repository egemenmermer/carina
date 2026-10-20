/// Pure logic of the add / edit playlist wizard: which fields a
/// source type shows and in which order, their step numbers, validation,
/// and the [PlaylistDraft] the form saves. No Flutter widgets in here, so
/// it is unit-tested directly.
library;

import 'package:carina/data/db/database.dart' show PlaylistType;
import 'package:carina/data/repositories/playlist_repository.dart'
    show PlaylistDraft;
import 'package:carina/data/sources/xtream/xtream_credentials.dart'
    show normalizeXtreamServer;

/// One row of the wizard form.
enum WizardField {
  name,
  server,
  username,
  password,
  playlistUrl,
  file,
  epgUrl,
  epgShift,
  reloadFrequency,
  userAgent,
  save,
}

/// Step number of "Choose a source"; the fields of a type follow from 03.
const int wizardSourceStep = 2;

/// The rows of [type] in form order.
List<WizardField> wizardFields(PlaylistType type) => switch (type) {
  PlaylistType.xtream => const [
    WizardField.name,
    WizardField.server,
    WizardField.username,
    WizardField.password,
    WizardField.epgUrl,
    WizardField.epgShift,
    WizardField.reloadFrequency,
    WizardField.save,
  ],
  PlaylistType.m3u => const [
    WizardField.name,
    WizardField.playlistUrl,
    WizardField.epgUrl,
    WizardField.epgShift,
    WizardField.reloadFrequency,
    WizardField.userAgent,
    WizardField.save,
  ],
  PlaylistType.m3uFile => const [
    WizardField.name,
    WizardField.file,
    WizardField.epgUrl,
    WizardField.epgShift,
    WizardField.reloadFrequency,
    WizardField.save,
  ],
};

/// `03` for the first field of every type (`02` is "Choose a source").
int wizardStepNumber(PlaylistType type, WizardField field) {
  final index = wizardFields(type).indexOf(field);
  return index < 0 ? wizardSourceStep : wizardSourceStep + 1 + index;
}

/// Two-digit step number (`02`, `10`).
String formatStepNumber(int number) => number.toString().padLeft(2, '0');

/// Reload frequencies offered by the wizard, in hours (0 = never).
const List<int> reloadFrequencyOptions = [0, 12, 24, 72, 168];

/// Default reload frequency (3 days).
const int defaultReloadFrequencyHours = 72;

/// EPG time shift range in hours.
const int minEpgShift = -12;
const int maxEpgShift = 12;

/// `+2`, `0`, `−3` (with a real minus sign).
String formatEpgShift(int hours) {
  if (hours > 0) return '+$hours';
  if (hours < 0) return '−${hours.abs()}';
  return '0';
}

/// Why a server address cannot be used.
enum ServerProblem {
  /// Nothing typed.
  empty,

  /// Missing or unsupported scheme (only http and https).
  scheme,

  /// No explicit port ("scheme and port required").
  port,

  /// Anything else (no host, bad port, a query string…).
  invalid,
}

/// Checks an Xtream server base such as `https://domain.com:8080`. Returns
/// null when it can be used. The port must be written out, even the
/// default one (`http://domain.com:80`); a path (`/panel`) is allowed.
ServerProblem? checkServerAddress(String input) {
  final s = input.trim();
  if (s.isEmpty) return ServerProblem.empty;
  final schemeEnd = s.indexOf('://');
  if (schemeEnd <= 0) return ServerProblem.scheme;
  final scheme = s.substring(0, schemeEnd).toLowerCase();
  if (scheme != 'http' && scheme != 'https') return ServerProblem.scheme;
  final uri = Uri.tryParse(s);
  if (uri == null || uri.host.isEmpty) return ServerProblem.invalid;
  if (uri.hasQuery || uri.hasFragment || uri.userInfo.isNotEmpty) {
    return ServerProblem.invalid;
  }
  // Uri drops a default port (http :80), so look at the text itself.
  final rest = s.substring(schemeEnd + 3);
  final end = rest.indexOf(RegExp('[/?#]'));
  final authority = end < 0 ? rest : rest.substring(0, end);
  final port = RegExp(r':(\d{1,5})$').firstMatch(authority);
  if (port == null) {
    // `host:` or `host:abc` is malformed rather than missing.
    return authority.contains(':') && !authority.endsWith(']')
        ? ServerProblem.invalid
        : ServerProblem.port;
  }
  final value = int.parse(port[1]!);
  if (value < 1 || value > 65535) return ServerProblem.invalid;
  return null;
}

/// Whether [input] is an absolute http(s) URL with a host.
bool isHttpUrl(String input) {
  final s = input.trim();
  if (s.isEmpty || s.contains(' ')) return false;
  final uri = Uri.tryParse(s);
  if (uri == null) return false;
  final scheme = uri.scheme.toLowerCase();
  return (scheme == 'http' || scheme == 'https') && uri.host.isNotEmpty;
}

/// Everything the wizard form holds, independent of widgets.
class WizardValues {
  WizardValues({
    required this.type,
    this.name = '',
    this.server = '',
    this.username = '',
    this.password = '',
    this.playlistUrl = '',
    this.filePath,
    this.epgText = '',
    this.epgDisabled = false,
    this.headerEpgUrl,
    this.epgShift = 0,
    this.reloadHours = defaultReloadFrequencyHours,
    this.userAgent = '',
    this.avatarId,
  });

  /// The values of a stored playlist for the edit form. [storedEpgUrl] is
  /// `playlists.epgUrl` (null = default guide, `''` = off, else custom);
  /// [headerEpgUrl] the M3U header's `url-tvg`. The Xtream default guide
  /// URL carries the password, so it is never put into the field: the field
  /// stays empty and shows the "Default: provider guide" hint instead.
  factory WizardValues.fromDraft(
    PlaylistDraft draft, {
    required String? storedEpgUrl,
    String? headerEpgUrl,
  }) {
    final stored = storedEpgUrl?.trim();
    final disabled = stored != null && stored.isEmpty;
    String epgText;
    if (stored == null) {
      epgText = draft.type == PlaylistType.xtream ? '' : (headerEpgUrl ?? '');
    } else {
      epgText = stored;
    }
    return WizardValues(
      type: draft.type,
      name: draft.name,
      server: draft.server ?? '',
      username: draft.username ?? '',
      password: draft.password ?? '',
      playlistUrl: draft.type == PlaylistType.m3u ? (draft.m3uUrl ?? '') : '',
      filePath: draft.type == PlaylistType.m3uFile ? draft.m3uUrl : null,
      epgText: epgText,
      epgDisabled: disabled,
      headerEpgUrl: headerEpgUrl,
      epgShift: draft.epgShiftHours.clamp(minEpgShift, maxEpgShift),
      reloadHours: draft.reloadFrequencyHours,
      userAgent: draft.userAgent ?? '',
      avatarId: draft.avatarId,
    );
  }

  PlaylistType type;
  String name;
  String server;
  String username;
  String password;
  String playlistUrl;
  String? filePath;

  /// Text of the EPG URL field.
  String epgText;

  /// "Disable guide": stored as `''`.
  bool epgDisabled;

  /// `url-tvg` of the M3U header found by the live check (or stored by the
  /// last import). When the EPG field still holds it, the playlist keeps
  /// following the header (stored as null).
  String? headerEpgUrl;
  int epgShift;
  int reloadHours;
  String userAgent;
  String? avatarId;

  /// `playlists.epgUrl` semantics (see `PlaylistDraft.epgUrl`): `''` = off,
  /// null = the default guide, anything else a custom URL.
  String? get draftEpgUrl {
    if (epgDisabled) return '';
    final text = epgText.trim();
    if (text.isEmpty) return null;
    final header = headerEpgUrl?.trim();
    if (type != PlaylistType.xtream && header != null && text == header) {
      return null;
    }
    return text;
  }

  /// The first problem of each invalid field, in form order. Empty when the
  /// form can be saved.
  Map<WizardField, WizardProblem> validate() {
    final problems = <WizardField, WizardProblem>{};
    if (name.trim().isEmpty) problems[WizardField.name] = WizardProblem.name;
    switch (type) {
      case PlaylistType.xtream:
        final server = checkServerAddress(this.server);
        if (server != null) {
          problems[WizardField.server] = switch (server) {
            ServerProblem.empty => WizardProblem.serverEmpty,
            ServerProblem.scheme => WizardProblem.serverScheme,
            ServerProblem.port => WizardProblem.serverPort,
            ServerProblem.invalid => WizardProblem.serverInvalid,
          };
        }
        if (username.trim().isEmpty) {
          problems[WizardField.username] = WizardProblem.username;
        }
        if (password.isEmpty) {
          problems[WizardField.password] = WizardProblem.password;
        }
      case PlaylistType.m3u:
        if (playlistUrl.trim().isEmpty) {
          problems[WizardField.playlistUrl] = WizardProblem.urlEmpty;
        } else if (!isHttpUrl(playlistUrl)) {
          problems[WizardField.playlistUrl] = WizardProblem.urlInvalid;
        }
      case PlaylistType.m3uFile:
        if ((filePath ?? '').trim().isEmpty) {
          problems[WizardField.file] = WizardProblem.file;
        }
    }
    if (!epgDisabled && epgText.trim().isNotEmpty && !isHttpUrl(epgText)) {
      problems[WizardField.epgUrl] = WizardProblem.epgInvalid;
    }
    return problems;
  }

  /// The draft to create or update. Call [validate] first.
  PlaylistDraft toDraft() => PlaylistDraft(
    name: name.trim(),
    type: type,
    server: type == PlaylistType.xtream ? normalizeXtreamServer(server) : null,
    username: type == PlaylistType.xtream ? username.trim() : null,
    password: type == PlaylistType.xtream ? password : null,
    m3uUrl: switch (type) {
      PlaylistType.xtream => null,
      PlaylistType.m3u => playlistUrl.trim(),
      PlaylistType.m3uFile => filePath?.trim(),
    },
    epgUrl: draftEpgUrl,
    epgShiftHours: epgShift,
    reloadFrequencyHours: reloadHours,
    userAgent: type == PlaylistType.m3u && userAgent.trim().isNotEmpty
        ? userAgent.trim()
        : null,
    avatarId: avatarId,
  );
}

/// A validation problem shown under a wizard field.
enum WizardProblem {
  name,
  serverEmpty,
  serverScheme,
  serverPort,
  serverInvalid,
  username,
  password,
  urlEmpty,
  urlInvalid,
  file,
  epgInvalid,
}
