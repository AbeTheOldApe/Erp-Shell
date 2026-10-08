import 'package:flutter/material.dart';

import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_theme.dart';
import '../module_def.dart';
import '../placeholder_module_page.dart';

/// Cari (customer / supplier accounts). Temporary page: shows the module
/// title and the permissions computed from the API grants. The real screens
/// arrive in phase 4.4.
class CariModule extends StatelessWidget {
  const CariModule(this.ctx, {super.key});

  final ModuleContext ctx;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final theme = Theme.of(context);
    final permissions = ctx.permissions;
    return ListView(
      padding: EdgeInsets.all(spacing.lg),
      children: [
        Text(ctx.title, style: theme.textTheme.headlineSmall),
        SizedBox(height: spacing.sm),
        Text(l10n.modulePlaceholderInfo, style: theme.textTheme.bodyMedium),
        SizedBox(height: spacing.lg),
        Text(l10n.modulePermissions, style: theme.textTheme.titleMedium),
        SizedBox(height: spacing.sm),
        Wrap(
          spacing: spacing.sm,
          runSpacing: spacing.sm,
          children: [
            PermissionChip(l10n.permissionView, permissions.canView),
            PermissionChip(l10n.permissionAdd, permissions.canAdd),
            PermissionChip(l10n.permissionEdit, permissions.canEdit),
            PermissionChip(l10n.permissionDelete, permissions.canDelete),
          ],
        ),
      ],
    );
  }
}
