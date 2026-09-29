import 'package:flutter/material.dart';

import '../core/l10n/locale_controller.dart';
import '../core/theme/app_theme.dart';

/// Asks whether unsaved changes in [dirtyTitles] may be discarded.
Future<bool> confirmDiscardChanges(
  BuildContext context,
  List<String> dirtyTitles,
) async {
  final l10n = context.l10n;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.warning_amber_outlined),
      title: Text(l10n.discardChangesTitle),
      content: Text(l10n.discardChangesMessage(dirtyTitles.join(', '))),
      actions: [
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.discardChangesConfirm),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Lists the keyboard shortcuts.
Future<void> showShortcutsHelp(BuildContext context) {
  final l10n = context.l10n;
  final shortcuts = [
    ('Alt + W', l10n.shortcutCloseTab),
    ('Alt + ← / →', l10n.shortcutPreviousNextTab),
    ('Alt + 1 … 9', l10n.shortcutGoToTab),
    ('Ctrl + K', l10n.shortcutCommandPalette),
    ('Esc', l10n.shortcutEscape),
  ];
  return showDialog<void>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      final spacing = context.spacing;
      return AlertDialog(
        title: Text(l10n.shortcutsHelp),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (keys, description) in shortcuts)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: spacing.xs),
                  child: Row(
                    children: [
                      Container(
                        constraints: const BoxConstraints(minWidth: 120),
                        padding: EdgeInsets.symmetric(
                          horizontal: spacing.sm,
                          vertical: spacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(spacing.xs),
                        ),
                        child: Text(keys, style: theme.textTheme.labelLarge),
                      ),
                      SizedBox(width: spacing.md),
                      Expanded(child: Text(description)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.close),
          ),
        ],
      );
    },
  );
}
