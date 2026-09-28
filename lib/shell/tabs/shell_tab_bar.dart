import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_theme.dart';
import '../shell_controller.dart';
import 'tab_item.dart';
import 'tabs_notifier.dart';

enum TabAction { refresh, close, closeOthers, closeRight, closeAll }

/// Shows the tab context menu (right click / long press) at [position] and
/// runs the chosen action.
Future<void> showTabContextMenu({
  required BuildContext context,
  required ShellController controller,
  required TabItem tab,
  required Offset position,
}) async {
  final l10n = context.l10n;
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final action = await showMenu<TabAction>(
    context: context,
    position: RelativeRect.fromRect(
      position & const Size(1, 1),
      Offset.zero & overlay.size,
    ),
    items: [
      PopupMenuItem(value: TabAction.refresh, child: Text(l10n.tabRefresh)),
      if (!tab.pinned)
        PopupMenuItem(value: TabAction.close, child: Text(l10n.tabClose)),
      PopupMenuItem(
        value: TabAction.closeOthers,
        child: Text(l10n.tabCloseOthers),
      ),
      PopupMenuItem(
        value: TabAction.closeRight,
        child: Text(l10n.tabCloseRight),
      ),
      PopupMenuItem(value: TabAction.closeAll, child: Text(l10n.tabCloseAll)),
    ],
  );
  switch (action) {
    case TabAction.refresh:
      controller.refreshTab(tab.tabKey);
    case TabAction.close:
      controller.closeTab(tab.tabKey);
    case TabAction.closeOthers:
      controller.closeOthers(tab.tabKey);
    case TabAction.closeRight:
      controller.closeRight(tab.tabKey);
    case TabAction.closeAll:
      controller.closeAll();
    case null:
      break;
  }
}

/// Horizontal tab strip for medium and expanded windows. Scroll arrows and
/// an "all tabs" list appear when the tabs overflow; the active tab is
/// always scrolled into view. Drag to reorder when [reorderable].
class ShellTabBar extends ConsumerStatefulWidget {
  const ShellTabBar({required this.reorderable, super.key});

  final bool reorderable;

  @override
  ConsumerState<ShellTabBar> createState() => _ShellTabBarState();
}

class _ShellTabBarState extends ConsumerState<ShellTabBar> {
  final ScrollController _scroll = ScrollController();
  final Map<String, GlobalKey> _tabKeys = {};
  bool _overflow = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(String tabKey) =>
      _tabKeys.putIfAbsent(tabKey, () => GlobalKey(debugLabel: tabKey));

  void _updateOverflow() {
    if (!mounted || !_scroll.hasClients) return;
    final overflow = _scroll.position.maxScrollExtent > 0;
    if (overflow != _overflow) setState(() => _overflow = overflow);
  }

  void _ensureVisible(String? tabKey) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tabContext = tabKey == null ? null : _tabKeys[tabKey]?.currentContext;
      if (tabContext == null || !tabContext.mounted) return;
      Scrollable.ensureVisible(
        tabContext,
        alignment: 0.5,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _scrollBy(double delta) {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    _scroll.animateTo(
      (position.pixels + delta).clamp(0, position.maxScrollExtent),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tabsProvider);
    final controller = ShellScope.of(context);
    final spacing = context.spacing;
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    ref.listen(
      tabsProvider.select((s) => s.activeKey),
      (_, key) => _ensureVisible(key),
    );
    _tabKeys.removeWhere((key, _) => state.byKey(key) == null);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateOverflow());

    Widget buildTab(TabItem tab) => _TabChip(
      key: _keyFor(tab.tabKey),
      tab: tab,
      active: tab.tabKey == state.activeKey,
      onTap: () => controller.activateTab(tab.tabKey),
      onClose: () => controller.closeTab(tab.tabKey),
      onContextMenu: (position) => showTabContextMenu(
        context: context,
        controller: controller,
        tab: tab,
        position: position,
      ),
    );

    final Widget list = widget.reorderable
        ? ReorderableListView.builder(
            scrollDirection: Axis.horizontal,
            scrollController: _scroll,
            buildDefaultDragHandles: false,
            itemCount: state.tabs.length,
            onReorderItem: controller.reorderTabs,
            itemBuilder: (context, index) {
              final tab = state.tabs[index];
              return ReorderableDragStartListener(
                key: ValueKey(tab.tabKey),
                index: index,
                enabled: !tab.pinned,
                child: buildTab(tab),
              );
            },
          )
        : ListView.builder(
            scrollDirection: Axis.horizontal,
            controller: _scroll,
            itemCount: state.tabs.length,
            itemBuilder: (context, index) => buildTab(state.tabs[index]),
          );

    return Material(
      color: scheme.surfaceContainerLow,
      child: SizedBox(
        height: spacing.tabBarHeight,
        child: Row(
          children: [
            if (_overflow)
              IconButton(
                tooltip: l10n.tabScrollLeft,
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _scrollBy(-240),
              ),
            Expanded(
              child: NotificationListener<ScrollMetricsNotification>(
                onNotification: (_) {
                  _updateOverflow();
                  return false;
                },
                child: list,
              ),
            ),
            if (_overflow)
              IconButton(
                tooltip: l10n.tabScrollRight,
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _scrollBy(240),
              ),
            if (_overflow)
              PopupMenuButton<String>(
                tooltip: l10n.tabAllTabs,
                icon: const Icon(Icons.expand_more),
                onSelected: controller.activateTab,
                itemBuilder: (context) => [
                  for (final tab in state.tabs)
                    CheckedPopupMenuItem(
                      value: tab.tabKey,
                      checked: tab.tabKey == state.activeKey,
                      child: Text(tab.title),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.tab,
    required this.active,
    required this.onTap,
    required this.onClose,
    required this.onContextMenu,
    super.key,
  });

  final TabItem tab;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final ValueChanged<Offset> onContextMenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final spacing = context.spacing;
    final l10n = context.l10n;

    return Semantics(
      selected: active,
      button: true,
      label: l10n.tabSemanticLabel(tab.title),
      child: Listener(
        onPointerDown: (event) {
          if (event.kind == PointerDeviceKind.mouse &&
              event.buttons & kMiddleMouseButton != 0 &&
              !tab.pinned) {
            onClose();
          }
        },
        child: GestureDetector(
          onSecondaryTapDown: (details) =>
              onContextMenu(details.globalPosition),
          onLongPressStart: (details) => onContextMenu(details.globalPosition),
          child: Material(
            color: active ? scheme.surface : Colors.transparent,
            shape: Border(
              bottom: BorderSide(
                color: active ? scheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: spacing.tabMaxWidth,
                  minHeight: spacing.tabBarHeight,
                ),
                child: Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: spacing.md,
                    end: tab.pinned ? spacing.md : 0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (tab.isDirty) ...[
                        _DirtyDot(tooltip: l10n.tabUnsavedChanges),
                        SizedBox(width: spacing.sm),
                      ],
                      Flexible(
                        child: Text(
                          tab.title,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: active
                                ? scheme.onSurface
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (!tab.pinned)
                        IconButton(
                          tooltip: l10n.tabClose,
                          iconSize: 18,
                          icon: const Icon(Icons.close),
                          onPressed: onClose,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DirtyDot extends StatelessWidget {
  const _DirtyDot({required this.tooltip});

  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
