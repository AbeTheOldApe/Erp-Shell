import 'dart:async';

import 'package:flutter/material.dart';

import '../core/l10n/locale_controller.dart';
import '../core/theme/app_theme.dart';
import 'module_def.dart';

/// Temporary page for mock modules: shows the module key, permissions and
/// query, plus a note field to verify that tab state is preserved.
class PlaceholderModulePage extends StatefulWidget {
  const PlaceholderModulePage({required this.ctx, super.key});

  final ModuleContext ctx;

  @override
  State<PlaceholderModulePage> createState() => _PlaceholderModulePageState();
}

class _PlaceholderModulePageState extends State<PlaceholderModulePage> {
  late Map<String, String> _query = widget.ctx.query;
  late final StreamSubscription<Map<String, String>> _querySubscription;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _querySubscription = widget.ctx.queryChanges.listen(
      (query) => setState(() => _query = query),
    );
  }

  @override
  void dispose() {
    _querySubscription.cancel();
    super.dispose();
  }

  void _setDirty(bool value) {
    setState(() => _dirty = value);
    widget.ctx.setDirty(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final theme = Theme.of(context);
    final permissions = widget.ctx.permissions;

    return SelectionArea(
      child: ListView(
        padding: EdgeInsets.all(spacing.lg),
        children: [
          Text(widget.ctx.moduleKey, style: theme.textTheme.headlineSmall),
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
          SizedBox(height: spacing.lg),
          Text(l10n.moduleQuery, style: theme.textTheme.titleMedium),
          SizedBox(height: spacing.sm),
          Text(
            _query.isEmpty
                ? l10n.moduleQueryEmpty
                : _query.entries.map((e) => '${e.key}=${e.value}').join(', '),
          ),
          SizedBox(height: spacing.lg),
          TextField(
            decoration: InputDecoration(labelText: l10n.moduleNoteLabel),
            maxLines: 3,
          ),
          SizedBox(height: spacing.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.moduleMarkDirty),
            value: _dirty,
            onChanged: _setDirty,
          ),
        ],
      ),
    );
  }
}

class PermissionChip extends StatelessWidget {
  const PermissionChip(this.label, this.granted, {super.key});

  final String label;
  final bool granted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      avatar: Icon(
        granted ? Icons.check_circle_outline : Icons.block,
        color: granted ? scheme.primary : scheme.error,
      ),
      label: Text(label),
    );
  }
}
