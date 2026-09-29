import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/session_controller.dart';
import '../core/router/routes.dart';
import '../data/menu/menu_models.dart';
import '../data/menu/menu_tree.dart';
import '../modules/module_def.dart';
import '../modules/registry.dart';
import 'side_menu/menu_providers.dart';
import 'tabs/tab_item.dart';
import 'tabs/tabs_notifier.dart';
import 'tabs/tabs_persistence.dart';

enum ModuleAvailability { available, notFound, noAccess }

/// Resolves whether [moduleKey] can be opened with the current registry and
/// menu. Unknown keys are "not found" even when they appear in the menu.
/// The home module (Cockpit) is always available.
ModuleAvailability moduleAvailability(
  String moduleKey, {
  required Map<String, ModuleDef> registry,
  required List<MenuNode> menu,
}) {
  final def = registry[moduleKey];
  if (def == null) return ModuleAvailability.notFound;
  if (def.home) return ModuleAvailability.available;
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
    required String Function() homeTitle,
    required void Function() onTabLimitReached,
    required Future<bool> Function(List<String> dirtyTitles) confirmDiscard,
  }) : _ref = ref,
       _router = router,
       _tabLimit = tabLimit,
       _homeTitle = homeTitle,
       _onTabLimitReached = onTabLimitReached,
       _confirmDiscard = confirmDiscard;

  /// Restored tabs may exceed the current limit (e.g. the window shrank);
  /// tabs are never closed automatically.
  static const _restoreLimit = 1000;

  final WidgetRef _ref;
  final GoRouter _router;
  final int Function() _tabLimit;
  final String Function() _homeTitle;
  final void Function() _onTabLimitReached;
  final Future<bool> Function(List<String> dirtyTitles) _confirmDiscard;
  int? _restoredForUser;

  /// Whether the tabs saved before a reload have been restored for the
  /// signed-in user.
  bool get tabsRestored =>
      _restoredForUser != null &&
      _restoredForUser == _ref.read(currentUserIdProvider);

  TabsNotifier get _tabs => _ref.read(tabsProvider.notifier);
  TabsState get _state => _ref.read(tabsProvider);
  String? get _homeKey => _ref.read(homeModuleKeyProvider);

  ModuleAvailability availabilityOf(String moduleKey) => moduleAvailability(
    moduleKey,
    registry: _ref.read(moduleRegistryProvider),
    menu: _ref.read(menuNodesProvider),
  );

  /// Title of an available module: from the menu, or the Cockpit title.
  String _titleOf(String moduleKey) => moduleKey == _homeKey
      ? _homeTitle()
      : MenuTree.findLeaf(_ref.read(menuNodesProvider), moduleKey)!.title;

  /// Opens [moduleKey] in a tab, or switches to its tab if already open.
  /// Unknown or forbidden modules navigate to their URL so the content area
  /// shows "Modül bulunamadı" / "Yetkiniz yok".
  void openModule(String moduleKey, {Map<String, String>? query}) {
    if (availabilityOf(moduleKey) != ModuleAvailability.available) {
      _go(Routes.module(moduleKey, query));
      return;
    }
    _ensureHome();
    final result = _tabs.open(
      moduleKey: moduleKey,
      title: _titleOf(moduleKey),
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
    final tabs = _state.tabs;
    if (index >= 0 && index < tabs.length) activateTab(tabs[index].tabKey);
  }

  /// Activates the next (`1`) or previous (`-1`) tab.
  void activateNeighbour(int offset) {
    final key = _tabs.neighbourKey(offset);
    if (key != null) activateTab(key);
  }

  Future<void> closeTab(String key) async {
    final tab = _state.byKey(key);
    if (tab == null || tab.pinned) return;
    if (!await _confirm([key])) return;
    if (_tabs.close(key)) _goToActive();
  }

  Future<void> closeActiveTab() async {
    final key = _state.activeKey;
    if (key != null) await closeTab(key);
  }

  Future<void> closeOthers(String key) async {
    final affected = [
      for (final tab in _state.tabs)
        if (!tab.pinned && tab.tabKey != key) tab.tabKey,
    ];
    if (!await _confirm(affected)) return;
    _tabs.closeOthers(key);
    _goToActive();
  }

  Future<void> closeRight(String key) async {
    final tabs = _state.tabs;
    final index = tabs.indexWhere((t) => t.tabKey == key);
    final affected = [
      for (final tab in tabs.skip(index + 1))
        if (!tab.pinned) tab.tabKey,
    ];
    if (!await _confirm(affected)) return;
    _tabs.closeRight(key);
    _goToActive();
  }

  Future<void> closeAll() async {
    final affected = [
      for (final tab in _state.tabs)
        if (!tab.pinned) tab.tabKey,
    ];
    if (!await _confirm(affected)) return;
    _tabs.closeAll();
    _goToActive();
  }

  /// "Yenile": rebuilds the module (asks first when it has unsaved changes).
  Future<void> refreshTab(String key) async {
    if (!await _confirm([key])) return;
    _tabs.refresh(key);
  }

  /// Signs out, after confirming when any tab has unsaved changes.
  Future<void> logout() async {
    if (!await _confirm(null)) return;
    await _ref.read(sessionProvider.notifier).logout();
  }

  void reorderTabs(int oldIndex, int newIndex) =>
      _tabs.reorder(oldIndex, newIndex);

  void setDirty(String key, bool value) => _tabs.setDirty(key, value);

  /// The module changed its inner page; mirror it in the URL.
  void setModuleQuery(String key, Map<String, String> query) {
    _tabs.setQuery(key, query);
    if (_state.activeKey == key) _goToActive();
  }

  /// Applies a URL change that did not come from the shell (browser back /
  /// forward, typed or shared link, reload). `/` shows the Cockpit.
  void syncFromLocation(Uri uri) {
    _ensureHome();
    final key = Routes.moduleKeyOf(uri) ?? _homeKey;
    if (key == null) {
      _tabs.activate(null);
      return;
    }
    final menuLoaded = _ref.read(menuLoadedProvider);
    if (menuLoaded) _restoreOnce();
    // Menu modules wait for the menu; this runs again once it has loaded.
    if (key != _homeKey && !menuLoaded) return;
    if (availabilityOf(key) != ModuleAvailability.available) {
      _tabs.activate(null);
      return;
    }
    final result = _tabs.open(
      moduleKey: key,
      title: _titleOf(key),
      query: uri.queryParameters,
      limit: _tabLimit(),
      // Browser back from `?id=7` to no query must reach the module.
      replaceQuery: true,
    );
    if (result == TabOpenResult.limitReached) {
      _onTabLimitReached();
      _goToActive();
    }
  }

  /// Keeps the Cockpit as the pinned first tab.
  void _ensureHome() {
    final home = _homeKey;
    if (home == null || _state.byKey(home) != null) return;
    _tabs.open(
      moduleKey: home,
      title: _homeTitle(),
      pinned: true,
      limit: _restoreLimit,
      activate: false,
    );
  }

  /// Reopens the tabs saved before a reload (once per signed-in user).
  void _restoreOnce() {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null || _restoredForUser == userId) return;
    _restoredForUser = userId;
    for (final saved in _ref.read(tabsPersistenceProvider).load(userId)) {
      if (availabilityOf(saved.moduleKey) != ModuleAvailability.available) {
        continue;
      }
      _tabs.open(
        moduleKey: saved.moduleKey,
        title: _titleOf(saved.moduleKey),
        query: saved.query,
        limit: _restoreLimit,
        activate: false,
      );
    }
  }

  /// Asks before discarding unsaved changes in [keys] (all tabs when null).
  Future<bool> _confirm(Iterable<String>? keys) async {
    final dirty = _state.dirtyTitles(keys);
    return dirty.isEmpty || await _confirmDiscard(dirty);
  }

  void _goToActive() {
    final TabItem? active = _state.activeTab;
    if (active == null || active.tabKey == _homeKey) {
      _go(Routes.home);
    } else {
      _go(Routes.module(active.tabKey, active.query));
    }
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
