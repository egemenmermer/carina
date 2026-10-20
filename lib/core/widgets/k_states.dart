import 'package:flutter/material.dart';
import 'package:carina/core/icons/phosphor_icons.dart';

import 'package:carina/core/strings.dart';
import 'package:carina/core/tokens.dart';
import 'package:carina/core/widgets/k_buttons.dart';
import 'package:carina/core/widgets/k_progress.dart';

/// Centered empty state: optional icon and title, a message, and an
/// optional big red action ("Add your first playlist" → "Add playlist").
class KEmptyState extends StatelessWidget {
  const KEmptyState({
    super.key,
    required this.message,
    this.title,
    this.icon,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  final String message;
  final String? title;
  final IconData? icon;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 52, color: KColors.textTertiary),
                const SizedBox(height: 20),
              ],
              if (title != null) ...[
                Text(
                  title!,
                  textAlign: TextAlign.center,
                  style: KText.largeTitle,
                ),
                const SizedBox(height: 10),
              ],
              Text(
                message,
                textAlign: TextAlign.center,
                style: KText.bodySecondary.copyWith(fontSize: 17),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 28),
                KButton.accent(
                  label: actionLabel!,
                  icon: actionIcon,
                  onPressed: onAction,
                  size: KButtonSize.large,
                  minWidth: 220,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Centered error state: warning icon, message, optional details and a
/// Retry button.
class KErrorState extends StatelessWidget {
  const KErrorState({
    super.key,
    required this.message,
    this.title,
    this.details,
    this.onRetry,
    this.retryLabel,
  });

  final String message;

  /// Defaults to "Something went wrong".
  final String? title;

  /// Smaller secondary text (status code, masked URL).
  final String? details;
  final VoidCallback? onRetry;
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    final strings = KStrings.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                PhosphorIconsLight.warningCircle,
                size: 52,
                color: KColors.accent,
              ),
              const SizedBox(height: 18),
              Text(
                title ?? strings.errorTitle,
                textAlign: TextAlign.center,
                style: KText.title,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: KText.bodySecondary,
              ),
              if (details != null) ...[
                const SizedBox(height: 8),
                Text(
                  details!,
                  textAlign: TextAlign.center,
                  style: KText.caption.copyWith(color: KColors.textTertiary),
                ),
              ],
              if (onRetry != null) ...[
                const SizedBox(height: 26),
                KButton.primaryWhite(
                  label: retryLabel ?? strings.retry,
                  icon: PhosphorIconsBold.arrowClockwise,
                  onPressed: onRetry,
                  minWidth: 160,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Centered loading state: thin spinner and an optional message.
class KLoadingState extends StatelessWidget {
  const KLoadingState({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(child: KSpinner(size: 36, label: message));
  }
}
