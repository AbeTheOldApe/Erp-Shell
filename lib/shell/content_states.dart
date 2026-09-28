import 'package:flutter/material.dart';

import '../core/l10n/locale_controller.dart';
import '../core/theme/app_theme.dart';

/// Centered icon + title + optional message, used for the shell's empty,
/// "no access" and "not found" states.
class ShellMessageView extends StatelessWidget {
  const ShellMessageView({
    required this.icon,
    required this.title,
    this.message,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = context.spacing;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.outline),
            SizedBox(height: spacing.md),
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              SizedBox(height: spacing.sm),
              Text(
                message!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyContentView extends StatelessWidget {
  const EmptyContentView({super.key});

  @override
  Widget build(BuildContext context) => ShellMessageView(
    icon: Icons.touch_app_outlined,
    title: context.l10n.emptyStateSelectModule,
  );
}

class NoAccessView extends StatelessWidget {
  const NoAccessView({super.key});

  @override
  Widget build(BuildContext context) => ShellMessageView(
    icon: Icons.lock_outline,
    title: context.l10n.noAccessTitle,
    message: context.l10n.noAccessMessage,
  );
}

class ModuleNotFoundView extends StatelessWidget {
  const ModuleNotFoundView({required this.moduleKey, super.key});

  final String moduleKey;

  @override
  Widget build(BuildContext context) => ShellMessageView(
    icon: Icons.search_off,
    title: context.l10n.moduleNotFoundTitle,
    message: context.l10n.moduleNotFoundMessage(moduleKey),
  );
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      label: context.l10n.loading,
      child: const CircularProgressIndicator(),
    ),
  );
}
