import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/menu/menu_tree.dart';
import '../../modules/module_def.dart';
import '../../modules/registry.dart';
import '../content_states.dart';
import '../shell_controller.dart';
import '../side_menu/menu_providers.dart';
import 'tab_item.dart';
import 'tabs_notifier.dart';

/// Content area. Every open tab stays alive in an [IndexedStack]; background
/// tabs have tickers disabled ([TickerMode]) and are excluded from focus.
/// When no tab is active, [placeholder] is shown on top.
class TabHost extends ConsumerWidget {
  const TabHost({required this.placeholder, super.key});

  final Widget? placeholder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = ref.watch(tabsProvider);
    final activeIndex = tabs.activeIndex;
    final showPlaceholder = activeIndex < 0;

    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(
          offstage: showPlaceholder,
          child: IndexedStack(
            index: showPlaceholder ? null : activeIndex,
            sizing: StackFit.expand,
            children: [
              for (final tab in tabs.tabs)
                KeyedSubtree(
                  key: ValueKey(tab.tabKey),
                  child: _TabContent(
                    tab: tab,
                    active: tab.tabKey == tabs.activeKey,
                  ),
                ),
            ],
          ),
        ),
        if (showPlaceholder) placeholder ?? const EmptyContentView(),
      ],
    );
  }
}

class _TabContent extends StatelessWidget {
  const _TabContent({required this.tab, required this.active});

  final TabItem tab;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return TickerMode(
      enabled: active,
      child: ExcludeFocus(
        excluding: !active,
        child: FocusTraversalGroup(
          child: ModuleHost(key: ValueKey(tab.generation), tab: tab),
        ),
      ),
    );
  }
}

/// Builds one module and gives it its [ModuleContext].
class ModuleHost extends ConsumerStatefulWidget {
  const ModuleHost({required this.tab, super.key});

  final TabItem tab;

  @override
  ConsumerState<ModuleHost> createState() => _ModuleHostState();
}

class _ModuleHostState extends ConsumerState<ModuleHost>
    implements ModuleContext {
  final StreamController<Map<String, String>> _queryChanges =
      StreamController.broadcast();

  @override
  void didUpdateWidget(ModuleHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tab.queryVersion != oldWidget.tab.queryVersion) {
      _queryChanges.add(widget.tab.query);
    }
  }

  @override
  void dispose() {
    _queryChanges.close();
    super.dispose();
  }

  // ModuleContext

  @override
  String get moduleKey => widget.tab.moduleKey;

  @override
  ModulePermissions get permissions {
    // The Cockpit is not in the menu; its permission model is decided later.
    if (ref.read(moduleRegistryProvider)[moduleKey]?.home ?? false) {
      return const ModulePermissions(canView: true);
    }
    return MenuTree.findLeaf(
          ref.read(menuNodesProvider),
          moduleKey,
        )?.permissions ??
        ModulePermissions.none;
  }

  @override
  Map<String, String> get query => widget.tab.query;

  @override
  Stream<Map<String, String>> get queryChanges => _queryChanges.stream;

  @override
  void setDirty(bool value) {
    if (mounted) ShellScope.of(context).setDirty(moduleKey, value);
  }

  @override
  void openModule(String moduleKey, {Map<String, String>? query}) {
    if (mounted) ShellScope.of(context).openModule(moduleKey, query: query);
  }

  @override
  void requestRefresh() {
    if (mounted) ShellScope.of(context).refreshTab(moduleKey);
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild when the menu (and thus permissions) changes.
    ref.watch(menuNodesProvider);
    final def = ref.watch(moduleRegistryProvider)[moduleKey];
    if (def == null) return ModuleNotFoundView(moduleKey: moduleKey);
    return def.builder(this);
  }
}
