import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../data/menu/menu_models.dart';
import '../../data/menu/menu_tree.dart';
import '../personalization/favorites_controller.dart';
import '../shell_controller.dart';
import '../tabs/tabs_notifier.dart';
import 'menu_providers.dart';

/// Collapsed menu (~72px): one icon per top-level node. Groups open their
/// children in a flyout. Tooltips appear on hover or long press.
class SideMenuRail extends ConsumerWidget {
  const SideMenuRail({required this.onExpandRequested, super.key});

  /// Search icon: expands the full menu with the search box focused.
  final VoidCallback onExpandRequested;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodes = ref.watch(menuNodesProvider);
    final activeKey = ref.watch(tabsProvider.select((s) => s.activeKey));
    final spacing = context.spacing;
    final favorites = [
      for (final key in ref.watch(favoriteKeysProvider))
        ?MenuTree.findLeaf(nodes, key),
    ];

    return SizedBox(
      width: spacing.railWidth,
      child: FocusTraversalGroup(
        child: Column(
          children: [
            SizedBox(height: spacing.sm),
            IconButton(
              tooltip: context.l10n.menuSearchHint,
              icon: const Icon(Icons.search),
              onPressed: onExpandRequested,
            ),
            if (favorites.isNotEmpty)
              _RailGroupButton(
                node: MenuNode(
                  id: -1,
                  title: context.l10n.favorites,
                  icon: 'star',
                  children: favorites,
                ),
                active: favorites.any((leaf) => leaf.moduleKey == activeKey),
              ),
            const Divider(),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(vertical: spacing.sm),
                children: [
                  for (final node in nodes)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: spacing.xs),
                      child: node.isLeaf
                          ? _RailLeafButton(
                              node: node,
                              active: node.moduleKey == activeKey,
                            )
                          : _RailGroupButton(
                              node: node,
                              active:
                                  activeKey != null &&
                                  MenuTree.findLeaf(node.children, activeKey) !=
                                      null,
                            ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RailLeafButton extends StatelessWidget {
  const _RailLeafButton({required this.node, required this.active});

  final MenuNode node;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final badge = node.badge;
    return Center(
      child: IconButton(
        tooltip: node.title,
        isSelected: active,
        style: _railButtonStyle(context),
        onPressed: () => ShellScope.of(context).openModule(node.moduleKey!),
        icon: Badge(
          isLabelVisible: badge != null && badge.isNotEmpty,
          label: badge == null ? null : Text(badge),
          child: Icon(IconRegistry.resolve(node.icon)),
        ),
      ),
    );
  }
}

class _RailGroupButton extends StatelessWidget {
  const _RailGroupButton({required this.node, required this.active});

  final MenuNode node;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final controller = ShellScope.of(context);
    final hasBadge = MenuTree.leaves(
      node.children,
    ).any((leaf) => leaf.badge?.isNotEmpty ?? false);

    return Center(
      child: MenuAnchor(
        alignmentOffset: Offset(spacing.railWidth - spacing.sm, -48),
        menuChildren: [
          for (final child in node.children) _flyoutEntry(child, controller),
        ],
        builder: (context, menu, _) => IconButton(
          tooltip: node.title,
          isSelected: active || menu.isOpen,
          style: _railButtonStyle(context),
          onPressed: () => menu.isOpen ? menu.close() : menu.open(),
          icon: Badge(
            smallSize: 8,
            isLabelVisible: hasBadge,
            child: Icon(IconRegistry.resolve(node.icon)),
          ),
        ),
      ),
    );
  }
}

Widget _flyoutEntry(MenuNode node, ShellController controller) {
  final icon = Icon(IconRegistry.resolve(node.icon));
  if (!node.isLeaf) {
    return SubmenuButton(
      leadingIcon: icon,
      menuChildren: [
        for (final child in node.children) _flyoutEntry(child, controller),
      ],
      child: Text(node.title),
    );
  }
  final badge = node.badge;
  return MenuItemButton(
    leadingIcon: icon,
    trailingIcon: badge == null || badge.isEmpty
        ? null
        : Badge(label: Text(badge)),
    onPressed: () => controller.openModule(node.moduleKey!),
    child: Text(node.title),
  );
}

ButtonStyle _railButtonStyle(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return IconButton.styleFrom(minimumSize: const Size(56, 48)).copyWith(
    backgroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? scheme.secondaryContainer
          : null,
    ),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? scheme.onSecondaryContainer
          : scheme.onSurfaceVariant,
    ),
  );
}
