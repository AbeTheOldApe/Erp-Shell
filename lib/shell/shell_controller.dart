import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/router/routes.dart';
import '../data/menu/menu_models.dart';
import '../data/menu/menu_tree.dart';
import '../modules/registry.dart';
import 'side_menu/menu_providers.dart';
import 'tabs/tabs_notifier.dart';

enum ModuleAvailability { available, notFound, noAccess }

/// Resolves whether [moduleKey] can be opened with the current registry and
/// menu. Unknown keys are "not found" even when they appear in the menu.
ModuleAvailability moduleAvailability(
  String moduleKey, {
  required Map<String, Object> registry,
  required List<MenuNode> menu,
}) {
  if (!registry.containsKey(moduleKey)) return ModuleAvailability.notFound;
  final leaf = MenuTree.findLeaf(menu, moduleKey);
  if (leaf == null || !(leaf.permissions?.canView ?? false)) {
    return ModuleAvailability.noAccess;
  }
  return ModuleAvailability.available;
}

/// Shell actions that combine tab state and the URL. Every tab change goes
/// through here so the active tab and `/m/:moduleKey` stay in sync.
class ShellController {
  ShellController({
    required WidgetRef ref,
    required GoRouter router,
    required int Function() tabLimit,
    required void Function() onTabLimitReached,
  }) : _ref = ref,
       _router = router,
       _tabLimit = tabLimit,
       _onTabLimitReached = onTabLimitReached;

  final WidgetRef _ref;
  final GoRouter _router;
  final int Function() _tabLimit;
  final void Function() _onTabLimitReached;

  TabsNotifier get _tabs => _ref.read(tabsProvider.notifier);

  ModuleAvailability availabilityOf(String moduleKey) => moduleAvailability(
    moduleKey,
    registry: _ref.read(moduleRegistryProvider),
    menu: _ref.read(menuNodesProvider),
  );

  /// Opens [moduleKey] in a tab, or switches to its tab if already open.
  /// Unknown or forbidden modules navigate to their URL so the content area
  /// shows "Modül bulunamadı" / "Yetkiniz yok".
  void openModule(String moduleKey, {Map<String, String>? query}) {
    if (availabilityOf(moduleKey) != ModuleAvailability.available) {
      _go(Routes.module(moduleKey, query));
      return;
    }
    final leaf = MenuTree.findLeaf(_ref.read(menuNodesProvider), moduleKey)!;
    final result = _tabs.open(
      moduleKey: moduleKey,
      title: leaf.title,
      query: query ?? const {},
      limit: _tabLimit(),
    );
    if (result == TabOpenResult.limitReached) {
      _onTabLimitReached();
      return;
    }
    _goToActive();
  }

  void activateTab(String key) {
    _tabs.activate(key);
    _goToActive();
  }

  void activateIndex(int index) {
    final tabs = _ref.read(tabsProvider).tabs;
    if (index >= 0 && index < tabs.length) activateTab(tabs[index].tabKey);
  }

  /// Activates the next (`1`) or previous (`-1`) tab.
  void activateNeighbour(int offset) {
    final key = _tabs.neighbourKey(offset);
    if (key != null) activateTab(key);
  }

  void closeTab(String key) {
    if (_tabs.close(key)) _goToActive();
  }

  void closeActiveTab() {
    final key = _ref.read(tabsProvider).activeKey;
    if (key != null) closeTab(key);
  }

  void closeOthers(String key) {
    _tabs.closeOthers(key);
    _goToActive();
  }

  void closeRight(String key) {
    _tabs.closeRight(key);
    _goToActive();
  }

  void closeAll() {
    _tabs.closeAll();
    _goToActive();
  }

  void refreshTab(String key) => _tabs.refresh(key);

  void reorderTabs(int oldIndex, int newIndex) =>
      _tabs.reorder(oldIndex, newIndex);

  void setDirty(String key, bool value) => _tabs.setDirty(key, value);

  /// Applies a URL change that did not come from the shell (browser back /
  /// forward, typed or shared link, reload).
  void syncFromLocation(Uri uri) {
    final key = Routes.moduleKeyOf(uri);
    if (key == null) {
      _tabs.activate(null);
      return;
    }
    if (!_ref.read(menuLoadedProvider)) return; // re-run when the menu loads
    if (availabilityOf(key) != ModuleAvailability.available) {
      _tabs.activate(null);
      return;
    }
    final leaf = MenuTree.findLeaf(_ref.read(menuNodesProvider), key)!;
    final result = _tabs.open(
      moduleKey: key,
      title: leaf.title,
      query: uri.queryParameters,
      limit: _tabLimit(),
    );
    if (result == TabOpenResult.limitReached) {
      _onTabLimitReached();
      _goToActive();
    }
  }

  void _goToActive() {
    final active = _ref.read(tabsProvider).activeTab;
    _go(active == null ? Routes.home : Routes.module(active.tabKey, active.query));
  }

  void _go(String location) {
    final current = _router.routerDelegate.currentConfiguration.uri.toString();
    if (current != location) _router.go(location);
  }
}

/// Makes the [ShellController] available to the shell subtree and to
/// modules (through their `ModuleContext`).
class ShellScope extends InheritedWidget {
  const ShellScope({required this.controller, required super.child, super.key});

  final ShellController controller;

  static ShellController of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<ShellScope>();
    assert(scope != null, 'No ShellScope above this context');
    return scope!.controller;
  }

  @override
  bool updateShouldNotify(ShellScope oldWidget) =>
      controller != oldWidget.controller;
}
