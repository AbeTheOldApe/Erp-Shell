import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../data/menu/menu_models.dart';
import '../../data/menu/menu_tree.dart';
import '../content_states.dart';
import '../shell_controller.dart';
import '../tabs/tabs_notifier.dart';
import 'menu_providers.dart';

/// Full menu: search box and tree. Used as the expanded desktop menu, the
/// tablet overlay and the phone drawer.
class SideMenuPanel extends ConsumerStatefulWidget {
  const SideMenuPanel({
    this.onModuleSelected,
    this.autofocusSearch = false,
    super.key,
  });

  /// Called after a module was chosen (closes the drawer / overlay).
  final VoidCallback? onModuleSelected;
  final bool autofocusSearch;

  @override
  ConsumerState<SideMenuPanel> createState() => _SideMenuPanelState();
}

class _SideMenuPanelState extends ConsumerState<SideMenuPanel> {
  late final TextEditingController _search = TextEditingController(
    text: ref.read(menuSearchProvider),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _revealActive(ref.read(tabsProvider).activeKey);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Opens the groups above the active module.
  void _revealActive(String? moduleKey) {
    if (moduleKey == null) return;
    final ancestors = MenuTree.ancestorIds(
      ref.read(menuNodesProvider),
      moduleKey,
    );
    ref.read(menuExpansionProvider.notifier).expandAll(ancestors);
  }

  void _select(MenuNode node) {
    ShellScope.of(context).openModule(node.moduleKey!);
    widget.onModuleSelected?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final menu = ref.watch(menuProvider);
    final nodes = ref.watch(menuNodesProvider);
    final query = ref.watch(menuSearchProvider);
    final expansion = ref.watch(menuExpansionProvider);
    final activeKey = ref.watch(tabsProvider.select((s) => s.activeKey));

    ref.listen(
      tabsProvider.select((s) => s.activeKey),
      (_, key) => _revealActive(key),
    );
    ref.listen(menuNodesProvider, (_, _) {
      _revealActive(ref.read(tabsProvider).activeKey);
    });
    ref.listen(menuSearchProvider, (_, value) {
      if (_search.text != value) _search.text = value;
    });

    final searching = query.trim().isNotEmpty;
    final visible = searching ? MenuTree.filter(nodes, query) : nodes;
    final openGroups = searching ? MenuTree.groupIds(visible) : expansion;
    final rows = _flatten(visible, openGroups);

    final Widget body;
    if (!menu.hasValue && menu.hasError) {
      body = _MenuError(onRetry: () => ref.invalidate(menuProvider));
    } else if (!menu.hasValue || (menu.isLoading && nodes.isEmpty)) {
      body = const LoadingView();
    } else if (rows.isEmpty) {
      body = Padding(
        padding: EdgeInsets.all(spacing.md),
        child: Text(l10n.menuSearchNoResult),
      );
    } else {
      body = ListView.builder(
        padding: EdgeInsets.only(bottom: spacing.md),
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final row = rows[index];
          final node = row.node;
          return MenuTreeRow(
            key: ValueKey(node.id),
            node: node,
            depth: row.depth,
            expanded: openGroups.contains(node.id),
            active: node.moduleKey != null && node.moduleKey == activeKey,
            onTap: node.isLeaf
                ? () => _select(node)
                : searching
                ? null
                : () => ref
                      .read(menuExpansionProvider.notifier)
                      .toggle(node.id),
          );
        },
      );
    }

    return FocusTraversalGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(spacing.sm),
            child: TextField(
              controller: _search,
              autofocus: widget.autofocusSearch,
              onChanged: ref.read(menuSearchProvider.notifier).set,
              decoration: InputDecoration(
                isDense: true,
                hintText: l10n.menuSearchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searching
                    ? IconButton(
                        tooltip: l10n.close,
                        icon: const Icon(Icons.clear),
                        onPressed: () =>
                            ref.read(menuSearchProvider.notifier).set(''),
                      )
                    : null,
              ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _Row {
  const _Row(this.node, this.depth);

  final MenuNode node;
  final int depth;
}

List<_Row> _flatten(List<MenuNode> nodes, Set<int> openGroups, [int depth = 0]) {
  return [
    for (final node in nodes) ...[
      _Row(node, depth),
      if (!node.isLeaf && openGroups.contains(node.id))
        ..._flatten(node.children, openGroups, depth + 1),
    ],
  ];
}

/// One row of the menu tree: icon, title, optional badge and, for groups,
/// an expand indicator.
class MenuTreeRow extends StatelessWidget {
  const MenuTreeRow({
    required this.node,
    required this.depth,
    required this.expanded,
    required this.active,
    required this.onTap,
    super.key,
  });

  final MenuNode node;
  final int depth;
  final bool expanded;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final spacing = context.spacing;
    final badge = node.badge;

    return Semantics(
      selected: active,
      expanded: node.isLeaf ? null : expanded,
      button: true,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: spacing.sm),
        child: Material(
          color: active ? scheme.secondaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(spacing.lg),
          child: InkWell(
            borderRadius: BorderRadius.circular(spacing.lg),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  start: spacing.md + depth * spacing.md,
                  end: spacing.sm,
                ),
                child: Row(
                  children: [
                    Icon(
                      IconRegistry.resolve(node.icon),
                      size: 20,
                      color: active
                          ? scheme.onSecondaryContainer
                          : scheme.onSurfaceVariant,
                    ),
                    SizedBox(width: spacing.md),
                    Expanded(
                      child: Text(
                        node.title,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: active
                              ? scheme.onSecondaryContainer
                              : scheme.onSurface,
                          fontWeight: node.isLeaf ? null : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (badge != null && badge.isNotEmpty)
                      Padding(
                        padding: EdgeInsetsDirectional.only(start: spacing.sm),
                        child: Badge(label: Text(badge)),
                      ),
                    if (!node.isLeaf)
                      Icon(
                        expanded ? Icons.expand_less : Icons.expand_more,
                        color: scheme.onSurfaceVariant,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuError extends StatelessWidget {
  const _MenuError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    return Padding(
      padding: EdgeInsets.all(spacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.menuLoadError),
          SizedBox(height: spacing.sm),
          OutlinedButton(onPressed: onRetry, child: Text(l10n.retry)),
        ],
      ),
    );
  }
}
