/// User-facing texts for the wizard's live checks and the import results
///.
library;

import 'package:intl/intl.dart';
import 'package:carina/app/time_format.dart';
import 'package:carina/core/core.dart';
import 'package:carina/data/db/database.dart' show PlaylistType, SectionKind;
import 'package:carina/data/import/import.dart';
import 'package:carina/data/net/url_check.dart';
import 'package:carina/data/sources/source_exception.dart';
import 'package:carina/data/sources/xtream/xtream_check.dart'
    show XtreamCheckResult;
import 'package:carina/l10n/gen/app_localizations.dart';

import 'source_checker.dart';
import 'wizard_form.dart';

/// "Server reachable · account active · expires 1 March 2027 · 2
/// connections", or a red reason.
KFieldStatus xtreamCheckStatus(
  L10n l10n,
  CarinaTimeFormat fmt,
  XtreamCheckResult result,
) {
  if (result.ok) {
    final parts = [
      l10n.playlistsCheckServerReachable,
      l10n.playlistsCheckAccountActive,
      if (result.isTrial) l10n.playlistsCheckTrial,
      result.expiresAt == null
          ? l10n.playlistsCheckNoExpiry
          : l10n.playlistsCheckExpires(fmt.date(result.expiresAt!)),
      if ((result.maxConnections ?? 0) > 0)
        l10n.playlistsCheckConnections(result.maxConnections!),
    ];
    return KFieldStatus.ok(parts.join(' · '));
  }
  if (result.error == SourceErrorKind.accountInactive) {
    final expired = result.expiresAt;
    final parts = [
      accountInactiveText(l10n, result.status),
      if (expired != null) l10n.playlistsCheckEnded(fmt.date(expired)),
    ];
    return KFieldStatus.error(parts.join(' · '));
  }
  return KFieldStatus.error(
    checkErrorText(
      l10n,
      result.error,
      statusCode: result.statusCode,
      unparseable: l10n.playlistsCheckNotXtream,
    ),
  );
}

/// "Account expired" and friends.
String accountInactiveText(L10n l10n, String? status) =>
    switch (status?.toLowerCase()) {
      'expired' => l10n.playlistsCheckAccountExpired,
      'banned' => l10n.playlistsCheckAccountBanned,
      'disabled' => l10n.playlistsCheckAccountDisabled,
      _ => l10n.playlistsCheckAccountInactive(status ?? '?'),
    };

/// Localized account status for the details sheet (`Active` → "Etkin").
String accountStatusLabel(L10n l10n, String? status) =>
    switch (status?.toLowerCase()) {
      'active' => l10n.playlistsStatusActive,
      'expired' => l10n.playlistsStatusExpired,
      'banned' => l10n.playlistsStatusBanned,
      'disabled' => l10n.playlistsStatusDisabled,
      null || '' => l10n.playlistsStatusActive,
      _ => status!,
    };

/// Status of the M3U URL check (mentions a guide link found in the header).
KFieldStatus playlistUrlStatus(L10n l10n, UrlCheckResult result) {
  if (result.ok) {
    return KFieldStatus.ok(
      result.m3uEpgUrls.isEmpty
          ? l10n.playlistsCheckPlaylistOk
          : l10n.playlistsCheckPlaylistOkGuide,
    );
  }
  return KFieldStatus.error(
    checkErrorText(
      l10n,
      result.error,
      statusCode: result.statusCode,
      unparseable: l10n.playlistsCheckNotM3u,
    ),
  );
}

/// Status of the XMLTV URL check.
KFieldStatus epgUrlStatus(L10n l10n, UrlCheckResult result) {
  if (result.ok) {
    return KFieldStatus.ok(
      result.kind == UrlContentKind.gzip
          ? l10n.playlistsCheckGuideOkGzip
          : l10n.playlistsCheckGuideOk,
    );
  }
  return KFieldStatus.error(
    checkErrorText(
      l10n,
      result.error,
      statusCode: result.statusCode,
      unparseable: l10n.playlistsCheckNotXml,
    ),
  );
}

/// Status of a local playlist file.
KFieldStatus fileStatus(L10n l10n, FileCheckResult result) {
  if (!result.exists) return KFieldStatus.error(l10n.playlistsCheckFileMissing);
  if (result.kind == UrlContentKind.empty) {
    return KFieldStatus.error(l10n.playlistsCheckEmpty);
  }
  if (!result.ok) return KFieldStatus.error(l10n.playlistsCheckNotM3u);
  return KFieldStatus.ok(l10n.playlistsCheckFileOk);
}

/// The red reason of a failed check.
String checkErrorText(
  L10n l10n,
  SourceErrorKind? kind, {
  int? statusCode,
  required String unparseable,
}) => switch (kind) {
  SourceErrorKind.timeout => l10n.playlistsCheckTimeout,
  SourceErrorKind.unauthorized => l10n.playlistsCheckUnauthorized,
  SourceErrorKind.forbidden => l10n.playlistsCheckForbidden,
  SourceErrorKind.notFound => l10n.playlistsCheckNotFound,
  SourceErrorKind.http => l10n.playlistsCheckHttp('${statusCode ?? '?'}'),
  SourceErrorKind.emptyBody => l10n.playlistsCheckEmpty,
  SourceErrorKind.unparseable => unparseable,
  SourceErrorKind.accountInactive => accountInactiveText(l10n, null),
  _ => l10n.playlistsCheckUnreachable,
};

/// The validation message of [problem].
String wizardProblemText(L10n l10n, WizardProblem problem) => switch (problem) {
  WizardProblem.name => l10n.playlistsErrorName,
  WizardProblem.serverEmpty => l10n.playlistsErrorServer,
  WizardProblem.serverScheme => l10n.playlistsErrorServerScheme,
  WizardProblem.serverPort => l10n.playlistsErrorServerPort,
  WizardProblem.serverInvalid => l10n.playlistsErrorServerInvalid,
  WizardProblem.username => l10n.playlistsErrorUsername,
  WizardProblem.password => l10n.playlistsErrorPassword,
  WizardProblem.urlEmpty => l10n.playlistsErrorUrl,
  WizardProblem.urlInvalid => l10n.playlistsErrorUrlInvalid,
  WizardProblem.file => l10n.playlistsErrorFile,
  WizardProblem.epgInvalid => l10n.playlistsErrorEpgInvalid,
};

/// "Xtream (Recommended)", "M3U playlist via URL", "M3U file".
String playlistTypeLabel(L10n l10n, PlaylistType type) => switch (type) {
  PlaylistType.xtream => l10n.playlistsTypeXtream,
  PlaylistType.m3u => l10n.playlistsTypeM3u,
  PlaylistType.m3uFile => l10n.playlistsTypeM3uFile,
};

/// "Never", "12 Hours", "1 Day", "3 Days", "1 Week".
String reloadFrequencyLabel(L10n l10n, int hours) => switch (hours) {
  <= 0 => l10n.playlistsReloadNever,
  12 => l10n.playlistsReload12h,
  24 => l10n.playlistsReload1d,
  72 => l10n.playlistsReload3d,
  168 => l10n.playlistsReload1w,
  _ => l10n.playlistsReloadHours(hours),
};

// ---------------------------------------------------------------------------
// Import results
// ---------------------------------------------------------------------------

/// Title, message and note of an import dialog.
class ImportDialogText {
  const ImportDialogText({
    required this.title,
    required this.message,
    this.note,
  });

  final String title;
  final String message;

  /// "A green check during setup only means…".
  final String? note;
}

/// The dialog of a failed import (step [ImportStep.failed]).
ImportDialogText importFailureText(L10n l10n, SourceException? error) {
  final kind = error?.kind;
  final message = switch (kind) {
    SourceErrorKind.unreachable => l10n.playlistsImportErrorUnreachable,
    SourceErrorKind.timeout => l10n.playlistsImportErrorTimeout,
    SourceErrorKind.unauthorized => l10n.playlistsImportErrorUnauthorized,
    SourceErrorKind.forbidden => l10n.playlistsImportErrorForbidden,
    SourceErrorKind.accountInactive => l10n.playlistsImportErrorInactive(
      _inactiveStatus(l10n, error?.message),
    ),
    SourceErrorKind.notFound => l10n.playlistsImportErrorNotFound,
    SourceErrorKind.http => l10n.playlistsImportErrorHttp(
      '${error?.statusCode ?? '?'}',
    ),
    SourceErrorKind.emptyBody => l10n.playlistsImportErrorEmpty,
    SourceErrorKind.unparseable => l10n.playlistsImportErrorUnparseable,
    _ => l10n.playlistsImportErrorGeneric,
  };
  return ImportDialogText(
    title: l10n.playlistsImportErrorTitle,
    message: message,
    note: l10n.playlistsImportCheckNote,
  );
}

/// `Account status: Expired` (Xtream importer message) → "expired".
String _inactiveStatus(L10n l10n, String? message) {
  final raw = message == null
      ? null
      : RegExp(
          r'status:\s*(\w+)',
          caseSensitive: false,
        ).firstMatch(message)?.group(1);
  return accountStatusLabel(l10n, raw ?? 'expired').toLowerCase();
}

/// The dialog when the guide failed. [contentImported]: the content of an
/// "everything" import is safe (the guide failure is not fatal); false for
/// an EPG-only reload.
ImportDialogText epgFailureText(
  L10n l10n,
  SourceException? error, {
  bool contentImported = true,
}) {
  final reason = switch (error?.kind) {
    SourceErrorKind.unreachable ||
    SourceErrorKind.timeout => l10n.playlistsImportEpgReasonUnreachable,
    SourceErrorKind.emptyBody => l10n.playlistsImportEpgReasonEmpty,
    SourceErrorKind.unparseable => l10n.playlistsImportEpgReasonInvalid,
    SourceErrorKind.http ||
    SourceErrorKind.notFound ||
    SourceErrorKind.forbidden ||
    SourceErrorKind.unauthorized => l10n.playlistsImportEpgReasonHttp(
      '${error?.statusCode ?? '?'}',
    ),
    _ => l10n.playlistsImportEpgReasonGeneric,
  };
  return ImportDialogText(
    title: l10n.playlistsImportEpgFailedTitle,
    message: contentImported
        ? l10n.playlistsImportEpgFailedMessage(reason)
        : reason,
    note: l10n.playlistsImportCheckNote,
  );
}

/// The "imported but section empty" dialog.
ImportDialogText emptySectionsText(L10n l10n, Set<SectionKind> sections) {
  final names = [
    for (final kind in SectionKind.values)
      if (sections.contains(kind))
        switch (kind) {
          SectionKind.live => l10n.playlistsImportStepLiveChannels,
          SectionKind.movie => l10n.playlistsImportStepMovies,
          SectionKind.series => l10n.playlistsImportStepSeries,
        },
  ];
  return ImportDialogText(
    title: l10n.playlistsImportEmptyTitle,
    message: l10n.playlistsImportEmptyMessage(names.join(', ')),
  );
}

/// Label of an import step in the stepper.
String importStepLabel(L10n l10n, ImportStep step) => switch (step) {
  ImportStep.connecting => l10n.playlistsImportStepConnecting,
  ImportStep.liveCategories => l10n.playlistsImportStepLiveCategories,
  ImportStep.liveChannels => l10n.playlistsImportStepLiveChannels,
  ImportStep.movies => l10n.playlistsImportStepMovies,
  ImportStep.series => l10n.playlistsImportStepSeries,
  ImportStep.epgCleaning => l10n.playlistsImportStepEpgCleaning,
  ImportStep.epgDownloading => l10n.playlistsImportStepEpgDownloading,
  ImportStep.epgParsing => l10n.playlistsImportStepEpgParsing,
  ImportStep.completed ||
  ImportStep.failed ||
  ImportStep.cancelled => l10n.playlistsImportStepCompleted,
};

/// `1,234` / `1.234` for the app locale.
String formatCount(String locale, int value) =>
    NumberFormat.decimalPattern(locale).format(value);

/// `12.4 MB`, `820 KB`.
String formatBytes(String locale, int bytes) {
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final pattern = unit == 0 || value >= 100 ? '0' : '0.0';
  return '${NumberFormat(pattern, locale).format(value)} ${units[unit]}';
}
