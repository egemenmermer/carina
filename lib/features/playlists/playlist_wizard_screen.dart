import 'dart:async';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import 'package:carina/app/time_format.dart';
import 'package:carina/core/core.dart';
import 'package:carina/data/db/database.dart' show PlaylistType;
import 'package:carina/data/import/import.dart';
import 'package:carina/data/repositories/playlist_repository.dart';
import 'package:carina/data/sources/source_exception.dart';
import 'package:carina/data/sources/m3u/m3u_detect.dart'
    show XtreamExportInfo, detectXtreamExport;
import 'package:carina/data/sources/xtream/xtream_credentials.dart';
import 'package:carina/features/playlists/data/playlist_actions.dart'
    show waitForImportIdle;
import 'package:carina/features/playlists/data/playlists_navigation.dart';
import 'package:carina/features/playlists/data/source_checker.dart';
import 'package:carina/features/playlists/data/source_messages.dart';
import 'package:carina/features/playlists/data/wizard_form.dart';
import 'package:carina/features/playlists/widgets/playlists_chrome.dart';
import 'package:carina/features/playlists/widgets/wizard_widgets.dart';
import 'package:carina/l10n/gen/app_localizations.dart';

/// Add / edit playlist wizard: full screen; the
/// left column shows the step (`04 / Server address`) and a one-line hint
/// that follow the focused field; the right column shows every field of the
/// chosen source type, the current one outlined in red. A red rule and the
/// CARINA wordmark sit at the bottom.
///
/// Step 02 chooses the source (Xtream, M3U via URL, M3U file) unless
/// [initialType] is given (the form opens directly, Name focused) or a
/// [playlistId] is edited. URL fields are checked live when they lose
/// focus. Save creates or updates the playlist and opens the import
/// progress screen (an edit reloads only when the source or the guide
/// changed).
class PlaylistWizardScreen extends ConsumerStatefulWidget {
  const PlaylistWizardScreen({super.key, this.playlistId, this.initialType});

  /// The playlist to edit; null adds a new one.
  final int? playlistId;

  /// Skip "Choose a source" and open this type's form.
  final PlaylistType? initialType;

  @override
  ConsumerState<PlaylistWizardScreen> createState() =>
      _PlaylistWizardScreenState();
}

class _PlaylistWizardScreenState extends ConsumerState<PlaylistWizardScreen> {
  final _name = TextEditingController();
  final _server = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _playlistUrl = TextEditingController();
  final _epg = TextEditingController();
  final _userAgent = TextEditingController();
  final Map<WizardField, FocusNode> _nodes = {
    for (final field in WizardField.values)
      field: FocusNode(debugLabel: 'wizard-${field.name}'),
  };

  PlaylistType? _type;
  WizardField _current = WizardField.name;
  bool _loading = false;
  bool _missing = false;
  bool _saving = false;

  String? _filePath;
  bool _epgDisabled = false;
  String? _headerEpgUrl;
  int _epgShift = 0;
  int _reloadHours = defaultReloadFrequencyHours;
  String? _avatarId;

  /// Live-check results per field (the Xtream login shows under Server, or
  /// under Password when the login was refused).
  final Map<WizardField, KFieldStatus> _status = {};

  /// Validation problems, shown for [_touched] fields.
  final Map<WizardField, WizardProblem> _problems = {};
  final Set<WizardField> _touched = {};

  /// The M3U URL is an Xtream `get.php` export.
  XtreamExportInfo? _export;

  final Map<WizardField, CancelToken> _checkTokens = {};
  final Map<WizardField, int> _checkSeq = {};

  /// Input of the last Xtream check (server|user|password), so an
  /// unchanged login is not checked twice.
  String? _xtreamChecked;

  bool get _editing => widget.playlistId != null;

  @override
  void initState() {
    super.initState();
    for (final entry in _nodes.entries) {
      entry.value.addListener(() => _onFocus(entry.key, entry.value));
    }
    if (_editing) {
      _loading = true;
      unawaited(_load());
    } else if (widget.initialType != null) {
      _type = widget.initialType;
      _focusField(WizardField.name);
    }
  }

  @override
  void dispose() {
    for (final token in _checkTokens.values) {
      token.cancel('wizard closed');
    }
    for (final node in _nodes.values) {
      node.dispose();
    }
    for (final c in [
      _name,
      _server,
      _username,
      _password,
      _playlistUrl,
      _epg,
      _userAgent,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Loading and values
  // -------------------------------------------------------------------------

  Future<void> _load() async {
    final repository = ref.read(playlistRepositoryProvider);
    final id = widget.playlistId!;
    final row = await repository.get(id);
    final draft = row == null ? null : await repository.draftFor(id);
    if (!mounted) return;
    if (row == null || draft == null) {
      setState(() {
        _loading = false;
        _missing = true;
      });
      return;
    }
    final values = WizardValues.fromDraft(
      draft,
      storedEpgUrl: row.epgUrl,
      headerEpgUrl: repository.m3uHeader(row)?.tvgUrls.firstOrNull,
    );
    setState(() {
      _loading = false;
      _type = values.type;
      _name.text = values.name;
      _server.text = values.server;
      _username.text = values.username;
      _password.text = values.password;
      _playlistUrl.text = values.playlistUrl;
      _filePath = values.filePath;
      _epg.text = values.epgText;
      _epgDisabled = values.epgDisabled;
      _headerEpgUrl = values.headerEpgUrl;
      _epgShift = values.epgShift;
      _reloadHours = values.reloadHours;
      _userAgent.text = values.userAgent;
      _avatarId = values.avatarId;
      _export = values.type == PlaylistType.m3u
          ? detectXtreamExport(values.playlistUrl)
          : null;
    });
    _focusField(WizardField.name);
  }

  WizardValues _values() => WizardValues(
    type: _type ?? PlaylistType.xtream,
    name: _name.text,
    server: _server.text,
    username: _username.text,
    password: _password.text,
    playlistUrl: _playlistUrl.text,
    filePath: _filePath,
    epgText: _epg.text,
    epgDisabled: _epgDisabled,
    headerEpgUrl: _headerEpgUrl,
    epgShift: _epgShift,
    reloadHours: _reloadHours,
    userAgent: _userAgent.text,
    avatarId: _avatarId,
  );

  List<WizardField> get _fields =>
      _type == null ? const [] : wizardFields(_type!);

  // -------------------------------------------------------------------------
  // Focus and navigation
  // -------------------------------------------------------------------------

  void _focusField(WizardField field) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _nodes[field]?.requestFocus();
    });
  }

  void _onFocus(WizardField field, FocusNode node) {
    if (!mounted || _type == null) return;
    if (node.hasFocus) {
      if (_current != field) setState(() => _current = field);
      // Small windows scroll the form: keep the focused row in view.
      final rowContext = node.context;
      if (rowContext != null) {
        for (final policy in const [
          ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
          ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        ]) {
          unawaited(
            Scrollable.ensureVisible(
              rowContext,
              alignmentPolicy: policy,
              duration: KMotion.of(context, KDurations.scroll),
            ),
          );
        }
      }
    } else {
      _onBlur(field);
    }
  }

  void _move(int direction) {
    final fields = _fields;
    if (fields.isEmpty) return;
    final index = fields.indexOf(_current);
    final next = (index + direction).clamp(0, fields.length - 1);
    if (next == index && _nodes[_current]!.hasFocus) return;
    _nodes[fields[next]]!.requestFocus();
  }

  void _onEscape() {
    if (_type != null && !_editing) {
      _invalidateChecks();
      setState(() {
        _type = null;
        _current = WizardField.name;
      });
      return;
    }
    goBackFromPlaylists(context);
  }

  void _chooseType(PlaylistType type) {
    _invalidateChecks();
    setState(() {
      _type = type;
      _current = WizardField.name;
      _status.clear();
      _problems.clear();
      _touched.clear();
      _xtreamChecked = null;
    });
    _focusField(WizardField.name);
  }

  // -------------------------------------------------------------------------
  // Validation and live checks
  // -------------------------------------------------------------------------

  void _revalidate(WizardField field) {
    final problem = _values().validate()[field];
    if (problem == null) {
      _problems.remove(field);
    } else {
      _problems[field] = problem;
    }
  }

  void _onChanged(WizardField field) {
    setState(() {
      _status.remove(field);
      if (field == WizardField.server ||
          field == WizardField.username ||
          field == WizardField.password) {
        // The login check shows under Server or Password.
        _status.remove(WizardField.server);
        _status.remove(WizardField.password);
        _xtreamChecked = null;
      }
      if (field == WizardField.playlistUrl) {
        _export = detectXtreamExport(_playlistUrl.text);
      }
      if (field == WizardField.epgUrl && _epg.text.isNotEmpty) {
        _epgDisabled = false;
      }
      if (_touched.contains(field)) _revalidate(field);
    });
  }

  void _onBlur(WizardField field) {
    if (field == WizardField.save) return;
    setState(() {
      _touched.add(field);
      _revalidate(field);
    });
    switch (field) {
      case WizardField.server:
        _splitXtreamLink();
        unawaited(_checkXtream());
      case WizardField.username || WizardField.password:
        unawaited(_checkXtream());
      case WizardField.playlistUrl:
        unawaited(_checkPlaylistUrl());
      case WizardField.epgUrl:
        unawaited(_checkEpg());
      default:
        break;
    }
  }

  /// A `get.php?username=…&password=…` link pasted into Server fills the
  /// three Xtream fields.
  void _splitXtreamLink() {
    final export = detectXtreamExport(_server.text);
    if (export == null) return;
    setState(() {
      _server.text = export.server;
      _username.text = export.username;
      _password.text = export.password;
      _revalidate(WizardField.server);
      _problems.remove(WizardField.username);
      _problems.remove(WizardField.password);
    });
    ref
        .read(toastControllerProvider)
        .show(
          L10n.of(context).playlistsXtreamFilled,
          kind: KToastKind.info,
          icon: PhosphorIconsLight.info,
        );
  }

  /// Starts a check of [field]; returns its sequence number and token.
  (int, CancelToken) _beginCheck(WizardField field) {
    _checkTokens[field]?.cancel('superseded');
    final token = CancelToken();
    _checkTokens[field] = token;
    final seq = (_checkSeq[field] ?? 0) + 1;
    _checkSeq[field] = seq;
    setState(() => _status[field] = const KFieldStatus.checking());
    return (seq, token);
  }

  bool _isLatest(WizardField field, int seq) => _checkSeq[field] == seq;

  /// Cancels every running check; their answers no longer apply (the source
  /// type changed).
  void _invalidateChecks() {
    for (final token in _checkTokens.values) {
      token.cancel('source changed');
    }
    _checkTokens.clear();
    for (final field in _checkSeq.keys.toList()) {
      _checkSeq[field] = _checkSeq[field]! + 1;
    }
  }

  Future<void> _checkXtream() async {
    if (_type != PlaylistType.xtream) return;
    final server = _server.text.trim();
    final username = _username.text.trim();
    final password = _password.text;
    if (checkServerAddress(server) != null ||
        username.isEmpty ||
        password.isEmpty) {
      return;
    }
    final key = '$server|$username|$password';
    if (key == _xtreamChecked &&
        (_status[WizardField.server] ?? _status[WizardField.password]) !=
            null) {
      return;
    }
    _xtreamChecked = key;
    _status.remove(WizardField.password);
    final (seq, token) = _beginCheck(WizardField.server);
    final result = await ref
        .read(playlistSourceCheckerProvider)
        .checkXtream(
          XtreamCredentials(normalizeXtreamServer(server), username, password),
          cancelToken: token,
        );
    if (!mounted ||
        !_isLatest(WizardField.server, seq) ||
        _type != PlaylistType.xtream) {
      return;
    }
    final l10n = L10n.of(context);
    final fmt = ref.read(timeFormatProvider);
    final status = xtreamCheckStatus(l10n, fmt, result);
    // A refused login belongs under Password; everything else (reachable,
    // unreachable, not an Xtream server) under Server.
    final credentials = switch (result.error) {
      SourceErrorKind.unauthorized ||
      SourceErrorKind.forbidden ||
      SourceErrorKind.accountInactive => true,
      _ => false,
    };
    setState(() {
      _status.remove(WizardField.server);
      _status[credentials ? WizardField.password : WizardField.server] = status;
    });
  }

  Future<void> _checkPlaylistUrl() async {
    final url = _playlistUrl.text.trim();
    if (_type != PlaylistType.m3u || !isHttpUrl(url)) return;
    final (seq, token) = _beginCheck(WizardField.playlistUrl);
    final result = await ref
        .read(playlistSourceCheckerProvider)
        .checkPlaylistUrl(
          url,
          userAgent: _userAgent.text.trim().isEmpty
              ? null
              : _userAgent.text.trim(),
          cancelToken: token,
        );
    if (!mounted ||
        !_isLatest(WizardField.playlistUrl, seq) ||
        _type != PlaylistType.m3u) {
      return;
    }
    final l10n = L10n.of(context);
    setState(() {
      _status[WizardField.playlistUrl] = playlistUrlStatus(l10n, result);
    });
    if (result.ok) _adoptHeaderGuide(result.m3uEpgUrls);
  }

  /// Pre-fills the EPG field from the playlist header's `url-tvg`.
  void _adoptHeaderGuide(List<String> urls) {
    final url = urls.firstOrNull;
    if (url == null) return;
    setState(() {
      _headerEpgUrl = url;
      if (!_epgDisabled && _epg.text.trim().isEmpty) {
        _epg.text = url;
        _status[WizardField.epgUrl] = KFieldStatus.ok(
          L10n.of(context).playlistsCheckGuideFromPlaylist,
        );
        _problems.remove(WizardField.epgUrl);
      }
    });
  }

  Future<void> _checkEpg() async {
    final url = _epg.text.trim();
    if (_epgDisabled || url.isEmpty) {
      setState(() => _status.remove(WizardField.epgUrl));
      return;
    }
    if (!isHttpUrl(url)) return;
    final (seq, token) = _beginCheck(WizardField.epgUrl);
    final result = await ref
        .read(playlistSourceCheckerProvider)
        .checkEpgUrl(
          url,
          userAgent: _type == PlaylistType.m3u && _userAgent.text.trim() != ''
              ? _userAgent.text.trim()
              : null,
          cancelToken: token,
        );
    if (!mounted || !_isLatest(WizardField.epgUrl, seq)) return;
    final l10n = L10n.of(context);
    setState(() => _status[WizardField.epgUrl] = epgUrlStatus(l10n, result));
  }

  Future<void> _pickFile() async {
    final l10n = L10n.of(context);
    final path = await ref.read(playlistFilePickerProvider)(
      l10n.playlistsFilePickerTitle,
    );
    if (path == null || !mounted) return;
    setState(() {
      _filePath = path;
      _touched.add(WizardField.file);
      _revalidate(WizardField.file);
      if (_name.text.trim().isEmpty) {
        _name.text = p.basenameWithoutExtension(path);
        _problems.remove(WizardField.name);
      }
    });
    final (seq, _) = _beginCheck(WizardField.file);
    final result = await ref
        .read(playlistSourceCheckerProvider)
        .checkFile(path);
    if (!mounted || !_isLatest(WizardField.file, seq)) return;
    setState(() => _status[WizardField.file] = fileStatus(l10n, result));
    if (result.ok) _adoptHeaderGuide(result.epgUrls);
  }

  void _switchToXtream() {
    final export = _export;
    if (export == null) return;
    _invalidateChecks();
    setState(() {
      _type = PlaylistType.xtream;
      _server.text = export.server;
      _username.text = export.username;
      _password.text = export.password;
      // The header guide belongs to the M3U; Xtream has its own default.
      if (_epg.text.trim() == (_headerEpgUrl ?? '').trim()) _epg.clear();
      _headerEpgUrl = null;
      _export = null;
      _status.clear();
      _problems.clear();
      _xtreamChecked = null;
      _current = WizardField.server;
    });
    _focusField(WizardField.server);
    unawaited(_checkXtream());
  }

  void _toggleGuide() {
    // Drop a running guide check: its answer no longer applies.
    _checkTokens.remove(WizardField.epgUrl)?.cancel('guide toggled');
    _checkSeq[WizardField.epgUrl] = (_checkSeq[WizardField.epgUrl] ?? 0) + 1;
    setState(() {
      _epgDisabled = !_epgDisabled;
      _status.remove(WizardField.epgUrl);
      _problems.remove(WizardField.epgUrl);
      if (_epgDisabled) {
        _epg.clear();
      } else if (_type != PlaylistType.xtream && _headerEpgUrl != null) {
        _epg.text = _headerEpgUrl!;
      }
    });
  }

  /// The chooser focuses the current value but does not scroll to it; with
  /// 25 shift values it can sit below the fold.
  void _revealChooserFocus() {
    final duration = KMotion.of(context, KDurations.scroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final focused = FocusManager.instance.primaryFocus?.context;
        if (focused != null && focused.mounted) {
          unawaited(
            Scrollable.ensureVisible(
              focused,
              alignment: 0.5,
              duration: duration,
            ),
          );
        }
      });
    });
  }

  Future<void> _chooseShift() async {
    final l10n = L10n.of(context);
    _revealChooserFocus();
    final value = await showChooser<int>(
      context,
      title: l10n.playlistsFieldShift,
      description: l10n.playlistsShiftChooserDescription,
      selected: _epgShift,
      choices: [
        for (var h = minEpgShift; h <= maxEpgShift; h++)
          KChoice(value: h, label: formatEpgShift(h)),
      ],
    );
    if (value != null && mounted) setState(() => _epgShift = value);
  }

  void _stepShift(int delta) => setState(
    () => _epgShift = (_epgShift + delta).clamp(minEpgShift, maxEpgShift),
  );

  List<int> get _reloadOptions =>
      {...reloadFrequencyOptions, _reloadHours}.toList()..sort();

  Future<void> _chooseReload() async {
    final l10n = L10n.of(context);
    _revealChooserFocus();
    final value = await showChooser<int>(
      context,
      title: l10n.playlistsFieldReload,
      description: l10n.playlistsReloadChooserDescription,
      selected: _reloadHours,
      choices: [
        for (final h in _reloadOptions)
          KChoice(value: h, label: reloadFrequencyLabel(l10n, h)),
      ],
    );
    if (value != null && mounted) setState(() => _reloadHours = value);
  }

  void _stepReload(int delta) {
    final options = _reloadOptions;
    final index = options.indexOf(_reloadHours);
    final next = (index + delta).clamp(0, options.length - 1);
    setState(() => _reloadHours = options[next]);
  }

  // -------------------------------------------------------------------------
  // Save
  // -------------------------------------------------------------------------

  Future<void> _save() async {
    if (_saving || _type == null) return;
    final values = _values();
    final problems = values.validate();
    if (problems.isNotEmpty) {
      setState(() {
        _problems
          ..clear()
          ..addAll(problems);
        _touched.addAll(problems.keys);
      });
      final first = _fields.firstWhere(problems.containsKey);
      _nodes[first]!.requestFocus();
      return;
    }
    setState(() => _saving = true);
    final l10n = L10n.of(context);
    final router = GoRouter.of(context);
    final toasts = ref.read(toastControllerProvider);
    final repository = ref.read(playlistRepositoryProvider);
    final imports = ref.read(importServiceProvider);
    try {
      final draft = values.toDraft();
      if (!_editing) {
        final id = await repository.create(
          draft.copyWith(
            avatarId: draft.avatarId ?? AvatarCatalog.defaultFor(draft.name).id,
          ),
        );
        router.go(importLocation(id));
        return;
      }
      final id = widget.playlistId!;
      final changes = await repository.updateWithChanges(id, draft);
      if (changes.source || changes.epg) {
        if (imports.isRunning(id)) {
          imports.cancel(id);
          await waitForImportIdle(imports, id);
        }
        router.go(
          importLocation(
            id,
            scope: changes.source ? ImportScope.all : ImportScope.epg,
          ),
        );
        return;
      }
      toasts.show(l10n.playlistsSaved);
      if (mounted) goBackFromPlaylists(context);
    } on Object catch (error) {
      debugPrint('Saving the playlist failed: ${error.runtimeType}');
      toasts.show(
        l10n.playlistsSaveFailed,
        kind: KToastKind.error,
        icon: PhosphorIconsLight.warningCircle,
      );
      if (mounted) setState(() => _saving = false);
    }
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  (String, String) _stepText(L10n l10n, WizardField field) => switch (field) {
    WizardField.name => (l10n.playlistsStepName, l10n.playlistsStepNameHint),
    WizardField.server => (
      l10n.playlistsStepServer,
      l10n.playlistsStepServerHint,
    ),
    WizardField.username => (
      l10n.playlistsStepUsername,
      l10n.playlistsStepUsernameHint,
    ),
    WizardField.password => (
      l10n.playlistsStepPassword,
      l10n.playlistsStepPasswordHint,
    ),
    WizardField.playlistUrl => (
      l10n.playlistsStepPlaylistUrl,
      l10n.playlistsStepPlaylistUrlHint,
    ),
    WizardField.file => (l10n.playlistsStepFile, l10n.playlistsStepFileHint),
    WizardField.epgUrl => (
      l10n.playlistsStepEpg,
      _type == PlaylistType.xtream
          ? l10n.playlistsStepEpgHintXtream
          : l10n.playlistsStepEpgHintM3u,
    ),
    WizardField.epgShift => (
      l10n.playlistsStepShift,
      l10n.playlistsStepShiftHint,
    ),
    WizardField.reloadFrequency => (
      l10n.playlistsStepReload,
      l10n.playlistsStepReloadHint,
    ),
    WizardField.userAgent => (
      l10n.playlistsStepUserAgent,
      l10n.playlistsStepUserAgentHint,
    ),
    WizardField.save => (
      l10n.playlistsStepSave,
      _editing ? l10n.playlistsStepSaveHintEdit : l10n.playlistsStepSaveHintNew,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final type = _type;
    final String header;
    final String hint;
    final double progress;
    if (type == null) {
      header = l10n.playlistsStepLabel(
        formatStepNumber(wizardSourceStep),
        l10n.playlistsStepSource,
      );
      hint = l10n.playlistsStepSourceHint;
      progress = 0.08;
    } else {
      final (title, text) = _stepText(l10n, _current);
      header = l10n.playlistsStepLabel(
        formatStepNumber(wizardStepNumber(type, _current)),
        title,
      );
      hint = text;
      final fields = _fields;
      progress = (fields.indexOf(_current) + 1) / (fields.length + 1) + 0.08;
    }

    Widget right;
    if (_loading) {
      right = const SizedBox(height: 360, child: KLoadingState());
    } else if (_missing) {
      right = SizedBox(
        height: 360,
        child: KEmptyState(message: l10n.playlistsNotFound),
      );
    } else if (type == null) {
      right = _SourceChoice(onChoose: _chooseType);
    } else {
      right = _buildForm(l10n, type);
    }

    return PlaylistsWindowFrame(
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): _onEscape},
        child: FocusScope(
          autofocus: true,
          child: Padding(
            padding: EdgeInsets.only(top: macTitleBarInset()),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 76,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 32),
                      child: KIconButton(
                        icon: PhosphorIconsRegular.arrowLeft,
                        size: 40,
                        iconSize: 20,
                        focusable: false,
                        tooltip: l10n.back,
                        onPressed: _onEscape,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 72),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 6, right: 48),
                            child: WizardStepHeader(label: header, hint: hint),
                          ),
                        ),
                        Expanded(
                          flex: 7,
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 660),
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.only(bottom: 24),
                                child: right,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(72, 8, 72, 30),
                  child: CarinaWordmarkFooter(progress: progress),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _errorFor(L10n l10n, WizardField field) {
    if (!_touched.contains(field)) return null;
    final problem = _problems[field];
    return problem == null ? null : wizardProblemText(l10n, problem);
  }

  Widget _buildForm(L10n l10n, PlaylistType type) {
    final fields = wizardFields(type);
    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Text(
          playlistTypeLabel(l10n, type),
          textAlign: TextAlign.center,
          style: KText.buttonLarge.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    ];
    for (final field in fields) {
      children
        ..add(_buildField(l10n, type, field))
        ..add(const SizedBox(height: 12));
    }
    return FocusTraversalGroup(
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowDown): () => _move(1),
          const SingleActivator(LogicalKeyboardKey.arrowUp): () => _move(-1),
        },
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }

  KTextField _text(
    WizardField field, {
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    TextInputType? keyboardType,
    Iterable<String>? autofillHints,
    Widget? suffix,
    String? semanticLabel,
  }) {
    final l10n = L10n.of(context);
    return KTextField(
      key: ValueKey('wizard-field-${field.name}'),
      controller: controller,
      focusNode: _nodes[field],
      hint: hint,
      obscure: obscure,
      highlighted: _current == field,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      textInputAction: TextInputAction.next,
      onChanged: (_) => _onChanged(field),
      onSubmitted: (_) => _move(1),
      errorText: _errorFor(l10n, field),
      status: _status[field],
      suffix: suffix,
      semanticLabel: semanticLabel ?? hint,
    );
  }

  Widget _buildField(L10n l10n, PlaylistType type, WizardField field) {
    switch (field) {
      case WizardField.name:
        return _text(field, controller: _name, hint: l10n.playlistsFieldName);
      case WizardField.server:
        return _text(
          field,
          controller: _server,
          hint: l10n.playlistsFieldServer,
          keyboardType: TextInputType.url,
          autofillHints: const [AutofillHints.url],
        );
      case WizardField.username:
        return _text(
          field,
          controller: _username,
          hint: l10n.playlistsFieldUsername,
          autofillHints: const [AutofillHints.username],
        );
      case WizardField.password:
        return _text(
          field,
          controller: _password,
          hint: l10n.playlistsFieldPassword,
          obscure: true,
          autofillHints: const [AutofillHints.password],
        );
      case WizardField.playlistUrl:
        final export = _export;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _text(
              field,
              controller: _playlistUrl,
              hint: l10n.playlistsFieldPlaylistUrl,
              keyboardType: TextInputType.url,
            ),
            if (export != null) ...[
              const SizedBox(height: 10),
              WizardNotice(
                key: const ValueKey('wizard-xtream-offer'),
                message: l10n.playlistsXtreamDetected,
                actionLabel: l10n.playlistsSwitchToXtream,
                onAction: _switchToXtream,
              ),
            ],
          ],
        );
      case WizardField.file:
        return WizardFileRow(
          key: const ValueKey('wizard-field-file'),
          fileName: _filePath == null ? null : p.basename(_filePath!),
          placeholder: l10n.playlistsFieldFile,
          buttonLabel: l10n.playlistsChooseFile,
          onPick: _pickFile,
          focusNode: _nodes[field],
          highlighted: _current == field,
          status: _status[field],
          errorText: _errorFor(l10n, field),
        );
      case WizardField.epgUrl:
        final hint = _epgDisabled
            ? l10n.playlistsFieldEpgOff
            : type == PlaylistType.xtream
            ? l10n.playlistsFieldEpgDefault
            : l10n.playlistsFieldEpgM3u;
        return _text(
          field,
          controller: _epg,
          hint: hint,
          keyboardType: TextInputType.url,
          semanticLabel: l10n.playlistsStepEpg,
          suffix: KPill(
            key: const ValueKey('wizard-guide-toggle'),
            label: _epgDisabled
                ? l10n.playlistsEnableGuide
                : l10n.playlistsDisableGuide,
            onTap: _toggleGuide,
          ),
        );
      case WizardField.epgShift:
        return WizardChoiceRow(
          key: const ValueKey('wizard-field-epgShift'),
          label: l10n.playlistsFieldShift,
          value: formatEpgShift(_epgShift),
          focusNode: _nodes[field],
          highlighted: _current == field,
          onTap: _chooseShift,
          onStep: _stepShift,
        );
      case WizardField.reloadFrequency:
        return WizardChoiceRow(
          key: const ValueKey('wizard-field-reloadFrequency'),
          label: l10n.playlistsFieldReload,
          value: reloadFrequencyLabel(l10n, _reloadHours),
          focusNode: _nodes[field],
          highlighted: _current == field,
          onTap: _chooseReload,
          onStep: _stepReload,
        );
      case WizardField.userAgent:
        return _text(
          field,
          controller: _userAgent,
          hint: l10n.playlistsFieldUserAgent,
        );
      case WizardField.save:
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CurrentOutline(
                visible: _current == WizardField.save,
                child: KButton.accent(
                  key: const ValueKey('wizard-save'),
                  label: l10n.save,
                  size: KButtonSize.large,
                  expand: true,
                  focusNode: _nodes[field],
                  onPressed: _saving ? null : _save,
                ),
              ),
              if (_editing) ...[
                const SizedBox(height: 10),
                KButton.secondary(
                  key: const ValueKey('wizard-cancel'),
                  label: l10n.cancel,
                  size: KButtonSize.large,
                  expand: true,
                  onPressed: () => goBackFromPlaylists(context),
                ),
              ],
            ],
          ),
        );
    }
  }
}

/// Step 02: the source pills.
class _SourceChoice extends StatelessWidget {
  const _SourceChoice({required this.onChoose});

  final ValueChanged<PlaylistType> onChoose;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return FocusTraversalGroup(
      child: Padding(
        padding: const EdgeInsets.only(top: 140),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WizardSourcePill(
              key: const ValueKey('wizard-source-xtream'),
              label: l10n.playlistsTypeXtream,
              autofocus: true,
              onTap: () => onChoose(PlaylistType.xtream),
            ),
            const SizedBox(height: 18),
            WizardSourcePill(
              key: const ValueKey('wizard-source-m3u'),
              label: l10n.playlistsTypeM3u,
              onTap: () => onChoose(PlaylistType.m3u),
            ),
            const SizedBox(height: 18),
            WizardSourcePill(
              key: const ValueKey('wizard-source-m3uFile'),
              label: l10n.playlistsTypeM3uFile,
              onTap: () => onChoose(PlaylistType.m3uFile),
            ),
            const SizedBox(height: 26),
            Text(
              l10n.playlistsSourceHint,
              textAlign: TextAlign.center,
              style: KText.caption,
            ),
          ],
        ),
      ),
    );
  }
}

/// The red "current field" outline around the Save button.
class _CurrentOutline extends StatelessWidget {
  const _CurrentOutline({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return KFocusRing(
      visible: visible,
      color: KColors.accent,
      gap: 3,
      width: 2,
      borderRadius: KRadii.button,
      child: child,
    );
  }
}
