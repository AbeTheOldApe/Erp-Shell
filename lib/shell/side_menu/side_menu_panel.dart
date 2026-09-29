import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../data/menu/menu_models.dart';
import '../../data/menu/menu_tree.dart';
import '../../core/network/api_exception.dart';
import '../content_states.dart';
import '../personalization/favorites_controller.dart';
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

  /// Adding or removing a favorite resizes the Favorites section above the
  /// tree, so rows move under the pointer. The section animates its size to
  /// make the movement visible, and a removal can be undone from a snackbar
  /// in case the next click hit the wrong star.
  Future<void> _toggleFavorite(MenuNode leaf, {bool undoable = true}) async {
    final moduleKey = leaf.moduleKey!;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final favorites = ref.read(favoritesProvider.notifier);
    final removing = favorites.isFavorite(moduleKey);
    try {
      await favorites.toggle(moduleKey);
    } on SessionExpiredException {
      // The session dialog takes over.
      return;
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.favoriteUpdateFailed)));
      return;
    }
    if (removing && undoable) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.favoriteRemoved(leaf.title)),
            action: SnackBarAction(
              label: l10n.undo,
              onPressed: () {
                if (mounted) _toggleFavorite(leaf, undoable: false);
              },
            ),
          ),
        );
    }
  }

  Widget _buildRow(
    MenuNode node, {
    required int depth,
    required bool inFavorites,
    required Set<int> openGroups,
    required List<String> favoriteKeys,
    required String? activeKey,
    required bool searching,
  }) {
    final moduleKey = node.moduleKey;
    return MenuTreeRow(
      key: ValueKey('${inFavorites ? 'fav' : 'tree'}-${node.id}'),
      node: node,
      depth: depth,
      expanded: openGroups.contains(node.id),
      active: moduleKey != null && moduleKey == activeKey,
      favorite: moduleKey == null ? null : favoriteKeys.contains(moduleKey),
      onToggleFavorite: moduleKey == null ? null : () => _toggleFavorite(node),
      onTap: node.isLeaf
          ? () => _select(node)
          : searching
          ? null
          : () => ref.read(menuExpansionProvider.notifier).toggle(node.id),
    );
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

    final favoriteKeys = ref.watch(favoriteKeysProvider);
    final searching = query.trim().isNotEmpty;
    final visible = searching ? MenuTree.filter(nodes, query) : nodes;
    final openGroups = searching ? MenuTree.groupIds(visible) : expansion;
    final favoriteLeaves = searching
        ? const <MenuNode>[]
        : [
            for (final key in favoriteKeys)
              ?MenuTree.findLeaf(nodes, key),
          ];
    final tree = _flatten(visible, openGroups);
    Widget row(MenuNode node, int depth, {bool inFavorites = false}) =>
        _buildRow(
          node,
          depth: depth,
          inFavorites: inFavorites,
          openGroups: openGroups,
          favoriteKeys: favoriteKeys,
          activeKey: activeKey,
          searching: searching,
        );

    final Widget body;
    if (!menu.hasValue && menu.hasError) {
      body = _MenuError(onRetry: () => ref.invalidate(menuProvider));
    } else if (!menu.hasValue || (menu.isLoading && nodes.isEmpty)) {
      body = const LoadingView();
    } else if (tree.isEmpty) {
      body = Padding(
        padding: EdgeInsets.all(spacing.md),
        child: Text(l10n.menuSearchNoResult),
      );
    } else {
      // Item 0 is the Favorites section; it stays in the list (possibly
      // empty) so that it can animate its size in and out.
      body = ListView.builder(
        padding: EdgeInsets.only(bottom: spacing.md),
        itemCount: tree.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: favoriteLeaves.isEmpty
                  ? const SizedBox(width: double.infinity)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SectionHeader(l10n.favorites),
                        for (final leaf in favoriteLeaves)
                          row(leaf, 0, inFavorites: true),
                        const Divider(),
                      ],
                    ),
            );
          }
          final item = tree[index - 1];
          return row(item.node, item.depth);
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

/// A visible node of the tree with its indentation level.
class _Row {
  const _Row(this.node, this.depth);

  final MenuNode node;
  final int depth;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = context.spacing;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        spacing.lg,
        spacing.sm,
        spacing.md,
        spacing.xs,
      ),
      child: Text(
        title,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
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

/// One row of the menu tree: icon, title, optional badge, a favorite star
/// for leaves and, for groups, an expand indicator.
class MenuTreeRow extends StatelessWidget {
  const MenuTreeRow({
    required this.node,
    required this.depth,
    required this.expanded,
    required this.active,
    required this.onTap,
    this.favorite,
    this.onToggleFavorite,
    super.key,
  });

  final MenuNode node;
  final int depth;
  final bool expanded;
  final bool active;
  final VoidCallback? onTap;

  /// Whether the leaf is a favorite; `null` hides the star.
  final bool? favorite;
  final VoidCallback? onToggleFavorite;

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
                    if (favorite != null && onToggleFavorite != null)
                      IconButton(
                        tooltip: favorite!
                            ? context.l10n.removeFavorite
                            : context.l10n.addFavorite,
                        isSelected: favorite,
                        icon: const Icon(Icons.star_border),
                        selectedIcon: const Icon(Icons.star),
                        color: scheme.onSurfaceVariant,
                        onPressed: onToggleFavorite,
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
