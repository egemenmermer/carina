import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../../data/db/database.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/repository_models.dart';
import '../../../l10n/gen/app_localizations.dart';

/// "Change category's name": a small sheet with the current name, the
/// provider's original name and Reset / Cancel / Save. The rename is local
/// (survives reloads). Resolves to true when the name changed.
Future<bool> showRenameCategorySheet(
  BuildContext context, {
  required int playlistId,
  required String categoryId,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final repo = container.read(categoryRepositoryProvider);
  final category = await repo.category(
    playlistId,
    SectionKind.live,
    categoryId,
  );
  if (category == null || !context.mounted) return false;
  final l10n = L10n.of(context);
  final result = await showKSheet<_RenameResult>(
    context,
    width: 520,
    child: RenameCategoryForm(category: category),
  );
  if (result == null) return false;
  final original = category.providerName ?? category.name;
  final name = result.name?.trim();
  final reset = name == null || name.isEmpty || name == original;
  if (reset && !category.isRenamed) return false;
  if (!reset && name == category.name) return false;
  await repo.rename(
    playlistId,
    SectionKind.live,
    categoryId,
    reset ? null : name,
  );
  container
      .read(toastControllerProvider)
      .show(reset ? l10n.liveCategoryNameReset : l10n.liveCategoryRenamed);
  return true;
}

class _RenameResult {
  const _RenameResult(this.name);

  /// Null = reset to the provider name.
  final String? name;
}

/// The form inside the rename sheet.
class RenameCategoryForm extends StatefulWidget {
  const RenameCategoryForm({super.key, required this.category});

  final CategoryView category;

  @override
  State<RenameCategoryForm> createState() => _RenameCategoryFormState();
}

class _RenameCategoryFormState extends State<RenameCategoryForm> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.category.name,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => Navigator.of(context).pop(_RenameResult(_controller.text));

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final category = widget.category;
    final original = category.providerName ?? category.name;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 40),
              child: Text(l10n.liveRenameCategory, style: KText.title),
            ),
            const SizedBox(height: 18),
            KTextField(
              controller: _controller,
              label: l10n.liveRenameHint,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.liveRenameOriginal(original),
              style: KText.caption.copyWith(color: KColors.textTertiary),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                if (category.isRenamed)
                  KButton.secondary(
                    label: l10n.liveReset,
                    icon: PhosphorIconsLight.arrowCounterClockwise,
                    onPressed: () =>
                        Navigator.of(context).pop(const _RenameResult(null)),
                  ),
                const Spacer(),
                KButton.secondary(
                  label: l10n.cancel,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 10),
                KButton.primaryWhite(
                  label: l10n.save,
                  minWidth: 110,
                  onPressed: _save,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
