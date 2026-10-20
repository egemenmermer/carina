import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../../data/repositories/parental_service.dart';
import '../../../l10n/gen/app_localizations.dart';

/// PIN gate for "Add to / Remove from Parental Control".
///
/// * No parental PIN yet: adding a lock asks the user to create one (enter
///   it twice) and saves it; removing a lock needs nothing (nothing is
///   protected without a PIN).
/// * With a PIN: adding a lock is free; removing one asks for the PIN.
///
/// Returns whether the change may go ahead.
Future<bool> authorizeParentalChange(
  BuildContext context,
  ProviderContainer container,
  L10n l10n, {
  required int playlistId,
  required bool unlocking,
}) async {
  final parental = container.read(parentalServiceProvider);
  final hasPin = await parental.hasPin(playlistId);
  if (!context.mounted) return false;
  if (hasPin) {
    if (!unlocking) return true;
    final pin = await showPinPad(
      context,
      title: l10n.liveEnterPinTitle,
      subtitle: l10n.liveEnterPinSubtitle,
      validate: (pin) => parental.verifyPin(playlistId, pin),
    );
    return pin != null;
  }
  if (unlocking) return true;
  final pin = await showPinPad(
    context,
    title: l10n.liveCreatePinTitle,
    subtitle: l10n.liveCreatePinSubtitle,
  );
  if (pin == null || !context.mounted) return false;
  final confirmed = await showPinPad(
    context,
    title: l10n.liveConfirmPinTitle,
    subtitle: l10n.liveCreatePinSubtitle,
    validate: (again) async => again == pin,
  );
  if (confirmed == null) return false;
  await parental.setPin(playlistId, pin);
  container.read(toastControllerProvider).show(l10n.liveParentalPinSet);
  return true;
}
