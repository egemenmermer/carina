/// PIN pad flows shared by the parental gate and Settings → Parental
/// Control: asking for the parental PIN, creating it (twice, to confirm),
/// changing and removing it, and the playlist access PIN.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/core.dart';
import '../../data/repositories/parental_service.dart';
import '../../data/repositories/playlist_repository.dart';
import '../../l10n/gen/app_localizations.dart';

/// Playlists whose Parental Control settings were opened with the PIN in
/// this session (cleared on restart).
final parentalSettingsAccessProvider =
    NotifierProvider<ParentalSettingsAccess, Set<int>>(
      ParentalSettingsAccess.new,
    );

/// See [parentalSettingsAccessProvider].
class ParentalSettingsAccess extends Notifier<Set<int>> {
  @override
  Set<int> build() => const {};

  void grant(int playlistId) => state = {...state, playlistId};

  void revoke(int playlistId) =>
      state = {...state.where((id) => id != playlistId)};
}

ProviderContainer _container(BuildContext context) =>
    ProviderScope.containerOf(context, listen: false);

/// Asks for the parental PIN of [playlistId] ([subject] names what is
/// locked). Without a stored PIN the user creates one first (the lock
/// still protects the content). Resolves true when the PIN was entered or
/// created.
Future<bool> requestParentalPin(
  BuildContext context, {
  required int playlistId,
  String? subject,
}) async {
  final l10n = L10n.of(context);
  final service = _container(context).read(parentalServiceProvider);
  if (!await service.hasPin(playlistId)) {
    if (!context.mounted) return false;
    return createParentalPin(
      context,
      playlistId: playlistId,
      subtitle: l10n.libraryParentalCreateFirst,
    );
  }
  if (!context.mounted) return false;
  final pin = await showPinPad(
    context,
    title: l10n.libraryParentalEnterPin,
    subtitle: subject == null ? null : l10n.libraryParentalIsLocked(subject),
    validate: (pin) => service.verifyPin(playlistId, pin),
  );
  return pin != null;
}

/// Asks for a new 4-digit PIN twice; null when cancelled.
Future<String?> askNewPin(
  BuildContext context, {
  required String title,
  String? subtitle,
}) async {
  final l10n = L10n.of(context);
  final first = await showPinPad(context, title: title, subtitle: subtitle);
  if (first == null || !context.mounted) return null;
  final second = await showPinPad(
    context,
    title: l10n.libraryParentalConfirmPin,
    subtitle: l10n.libraryParentalConfirmPinHint,
    validate: (pin) async => pin == first,
  );
  return second;
}

/// Creates the parental PIN of [playlistId] (new PIN + confirmation) and
/// shows the green toast. Resolves true when a PIN was stored.
Future<bool> createParentalPin(
  BuildContext context, {
  required int playlistId,
  String? subtitle,
}) async {
  final l10n = L10n.of(context);
  final container = _container(context);
  final pin = await askNewPin(
    context,
    title: l10n.libraryParentalCreatePin,
    subtitle: subtitle ?? l10n.libraryParentalCreatePinHint,
  );
  if (pin == null) return false;
  await container.read(parentalServiceProvider).setPin(playlistId, pin);
  container.read(parentalSettingsAccessProvider.notifier).grant(playlistId);
  container.read(toastControllerProvider).show(l10n.libraryParentalPinSet);
  return true;
}

/// Changes the parental PIN: current PIN, then the new one twice.
Future<bool> changeParentalPin(
  BuildContext context, {
  required int playlistId,
}) async {
  final l10n = L10n.of(context);
  final container = _container(context);
  final service = container.read(parentalServiceProvider);
  final current = await showPinPad(
    context,
    title: l10n.libraryParentalCurrentPin,
    validate: (pin) => service.verifyPin(playlistId, pin),
  );
  if (current == null || !context.mounted) return false;
  final pin = await askNewPin(context, title: l10n.libraryParentalNewPin);
  if (pin == null) return false;
  await service.setPin(playlistId, pin);
  container.read(toastControllerProvider).show(l10n.libraryParentalPinChanged);
  return true;
}

/// Removes the parental PIN after checking it. Locks stay; without a PIN
/// opening a locked channel asks to create one.
Future<bool> removeParentalPin(
  BuildContext context, {
  required int playlistId,
}) async {
  final l10n = L10n.of(context);
  final container = _container(context);
  final service = container.read(parentalServiceProvider);
  final current = await showPinPad(
    context,
    title: l10n.libraryParentalCurrentPin,
    validate: (pin) => service.verifyPin(playlistId, pin),
  );
  if (current == null) return false;
  await service.clearPin(playlistId);
  container.read(toastControllerProvider).show(l10n.libraryParentalPinRemoved);
  return true;
}

/// Sets, changes or removes the playlist access PIN. [remove]
/// removes it; otherwise a new one is set (after the current one when
/// [hasPin]).
Future<bool> editAccessPin(
  BuildContext context, {
  required int playlistId,
  required bool hasPin,
  bool remove = false,
}) async {
  final l10n = L10n.of(context);
  final container = _container(context);
  final repo = container.read(playlistRepositoryProvider);
  if (hasPin) {
    final current = await showPinPad(
      context,
      title: l10n.libraryAccessPinCurrent,
      validate: (pin) => repo.verifyAccessPin(playlistId, pin),
    );
    if (current == null || !context.mounted) return false;
  }
  if (remove) {
    await repo.removeAccessPin(playlistId);
    container.read(toastControllerProvider).show(l10n.libraryAccessPinRemoved);
    return true;
  }
  final pin = await askNewPin(
    context,
    title: l10n.libraryAccessPinNew,
    subtitle: l10n.libraryAccessPinHint,
  );
  if (pin == null) return false;
  await repo.setAccessPin(playlistId, pin);
  container.read(toastControllerProvider).show(l10n.libraryAccessPinSet);
  return true;
}
