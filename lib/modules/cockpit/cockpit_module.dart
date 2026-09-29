import 'package:flutter/material.dart';

import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_theme.dart';
import '../module_def.dart';

/// Cockpit: the pinned home tab. Its content grows as business modules are
/// added; for now it is a placeholder.
class CockpitModule extends StatelessWidget {
  const CockpitModule(this.ctx, {super.key});

  final ModuleContext ctx;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final spacing = context.spacing;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.dashboard_outlined,
              size: 56,
              color: theme.colorScheme.outline,
            ),
            SizedBox(height: spacing.md),
            Text(l10n.cockpitTitle, style: theme.textTheme.titleLarge),
            SizedBox(height: spacing.sm),
            Text(
              l10n.cockpitPlaceholder,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
