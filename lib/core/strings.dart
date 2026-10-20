import 'package:flutter/widgets.dart';

import 'package:carina/l10n/gen/app_localizations.dart';

/// Strings used inside core widgets.
///
/// Looks up [L10n] without asserting, so core widgets still render (in
/// English) when a test or a tool pumps them without the localization
/// delegates. Feature code should keep using `L10n.of(context)` directly.
class KStrings {
  const KStrings._(this._l);

  final L10n? _l;

  /// The strings for [context]'s locale (English when [L10n] is missing).
  static KStrings of(BuildContext context) =>
      KStrings._(Localizations.of<L10n>(context, L10n));

  String get cancel => _l?.cancel ?? 'Cancel';
  String get close => _l?.close ?? 'Close';
  String get retry => _l?.retry ?? 'Retry';
  String get seeAll => _l?.seeAll ?? 'See All';
  String get loading => _l?.loading ?? 'Loading…';
  String get ok => _l?.ok ?? 'Ok';

  String get live => _l?.coreLive ?? 'LIVE';
  String buffering(int percent) =>
      _l?.coreBuffering(percent) ?? 'Buffering $percent%';
  String get newMovie => _l?.coreNewMovie ?? 'NEW MOVIE';
  String get newShow => _l?.coreNewShow ?? 'NEW SHOW';
  String get newEpisodes => _l?.coreNewEpisodes ?? 'NEW EPISODES';
  String get scrollLeft => _l?.coreScrollLeft ?? 'Scroll left';
  String get scrollRight => _l?.coreScrollRight ?? 'Scroll right';
  String get showPassword => _l?.coreShowPassword ?? 'Show password';
  String get hidePassword => _l?.coreHidePassword ?? 'Hide password';
  String get checking => _l?.coreChecking ?? 'Checking…';
  String get pinWrong => _l?.corePinWrong ?? 'Wrong PIN. Try again.';
  String get pinDeleteDigit => _l?.corePinDeleteDigit ?? 'Delete last digit';
  String get windowMinimize => _l?.coreWindowMinimize ?? 'Minimize';
  String get windowMaximize => _l?.coreWindowMaximize ?? 'Maximize';
  String get windowRestore => _l?.coreWindowRestore ?? 'Restore Down';
  String get windowClose => _l?.coreWindowClose ?? 'Close';
  String get categories => _l?.coreCategories ?? 'Categories';
  String get switchPlaylist => _l?.coreSwitchPlaylist ?? 'Switch playlist';
  String get dismiss => _l?.coreDismiss ?? 'Dismiss';
  String get errorTitle => _l?.coreErrorTitle ?? 'Something went wrong';
  String get decrease => _l?.coreDecrease ?? 'Decrease';
  String get increase => _l?.coreIncrease ?? 'Increase';
  String get avatarCharacters => _l?.coreAvatarCharacters ?? 'Characters';
  String get avatarAnimals => _l?.coreAvatarAnimals ?? 'Animals';
  String get avatarCars => _l?.coreAvatarCars ?? 'Cars';
  String get avatarObjects => _l?.coreAvatarObjects ?? 'Objects';
  String get avatarAbstract => _l?.coreAvatarAbstract ?? 'Abstract';
  String get avatarInitials => _l?.coreAvatarInitials ?? 'Initials';
}
