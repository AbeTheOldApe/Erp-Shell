import 'package:flutter/material.dart';

import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/breakpoints.dart';

/// An action of a module page. Actions the user may not perform are not
/// passed at all (hidden, not disabled).
@immutable
class PageAction {
  const PageAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  /// Emphasized; on phones it stays visible as an icon button.
  final bool primary;
  final bool destructive;
}

/// Frame of a module page: title (text or breadcrumb), action bar, body.
/// On phones only the primary action stays in the bar; the rest move to an
/// overflow menu.
class ResponsiveScaffold extends StatelessWidget {
  const ResponsiveScaffold({
    required this.title,
    required this.body,
    this.actions = const [],
    super.key,
  });

  final Widget title;
  final List<PageAction> actions;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final compact = Breakpoints.of(context) == WindowSizeClass.compact;
    final scheme = Theme.of(context).colorScheme;

    final List<Widget> bar;
    if (compact) {
      final primary = actions.where((a) => a.primary).toList();
      final rest = actions.where((a) => !a.primary).toList();
      bar = [
        for (final action in primary)
          IconButton.filledTonal(
            tooltip: action.label,
            icon: Icon(action.icon),
            onPressed: action.onPressed,
          ),
        if (rest.isNotEmpty)
          PopupMenuButton<PageAction>(
            tooltip: context.l10n.moreActions,
            onSelected: (action) => action.onPressed?.call(),
            itemBuilder: (context) => [
              for (final action in rest)
                PopupMenuItem(
                  value: action,
                  enabled: action.onPressed != null,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      action.icon,
                      color: action.destructive ? scheme.error : null,
                    ),
                    title: Text(action.label),
                  ),
                ),
            ],
          ),
      ];
    } else {
      bar = [
        for (final action in actions)
          Padding(
            padding: EdgeInsets.only(left: spacing.sm),
            child: action.primary
                ? FilledButton.icon(
                    onPressed: action.onPressed,
                    icon: Icon(action.icon),
                    label: Text(action.label),
                  )
                : OutlinedButton.icon(
                    style: action.destructive
                        ? OutlinedButton.styleFrom(
                            foregroundColor: scheme.error,
                          )
                        : null,
                    onPressed: action.onPressed,
                    icon: Icon(action.icon),
                    label: Text(action.label),
                  ),
          ),
      ];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            spacing.md,
            spacing.sm,
            spacing.md,
            spacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Align(alignment: Alignment.centerLeft, child: title),
              ),
              ...bar,
            ],
          ),
        ),
        Expanded(child: body),
      ],
    );
  }
}
