import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session_controller.dart';
import 'tab_item.dart';

@immutable
class TabsState {
  const TabsState({this.tabs = const [], this.activeKey});

  final List<TabItem> tabs;

  /// Key of the visible tab; `null` when the content area shows something
  /// else (empty state, "Yetkiniz yok", ...).
  final String? activeKey;

  int get activeIndex => tabs.indexWhere((t) => t.tabKey == activeKey);

  TabItem? get activeTab {
    final index = activeIndex;
    return index < 0 ? null : tabs[index];
  }

  TabItem? byKey(String key) {
    for (final tab in tabs) {
      if (tab.tabKey == key) return tab;
    }
    return null;
  }

  bool get hasDirtyTabs => tabs.any((t) => t.isDirty);

  /// Titles of the dirty, non-pinned tabs among [keys] (all tabs when null).
  List<String> dirtyTitles([Iterable<String>? keys]) {
    final only = keys?.toSet();
    return [
      for (final tab in tabs)
        if (tab.isDirty && (only == null || only.contains(tab.tabKey)))
          tab.title,
    ];
  }
}

enum TabOpenResult {
  /// A new tab was created and activated.
  opened,

  /// The module was already open; its tab was activated.
  activated,

  /// The tab limit was reached; nothing changed.
  limitReached,
}

/// Open tabs and the active tab. Cleared when the signed-in user changes.
class TabsNotifier extends Notifier<TabsState> {
  @override
  TabsState build() {
    ref.watch(currentUserIdProvider);
    return const TabsState();
  }

  /// Opens [moduleKey] or switches to its existing tab. A non-empty [query]
  /// replaces the query of an existing tab. With `activate: false` the
  /// active tab does not change (used when restoring tabs).
  TabOpenResult open({
    required String moduleKey,
    required String title,
    required int limit,
    Map<String, String> query = const {},
    bool pinned = false,
    bool activate = true,
  }) {
    final existing = state.byKey(moduleKey);
    if (existing != null) {
      final queryChanged =
          query.isNotEmpty && !mapEquals(query, existing.query);
      state = TabsState(
        tabs: [
          for (final tab in state.tabs)
            if (tab.tabKey == moduleKey && queryChanged)
              tab.copyWith(query: query, queryVersion: tab.queryVersion + 1)
            else
              tab,
        ],
        activeKey: activate ? moduleKey : state.activeKey,
      );
      return TabOpenResult.activated;
    }
    if (state.tabs.length >= limit) return TabOpenResult.limitReached;

    final item = TabItem(
      moduleKey: moduleKey,
      title: title,
      pinned: pinned,
      query: query,
    );
    final tabs = [...state.tabs];
    if (pinned) {
      tabs.insert(_pinnedCount(tabs), item);
    } else {
      tabs.add(item);
    }
    state = TabsState(
      tabs: tabs,
      activeKey: activate ? moduleKey : state.activeKey,
    );
    return TabOpenResult.opened;
  }

  /// Shows [key]'s tab, or nothing (`null`).
  void activate(String? key) {
    if (key != null && state.byKey(key) == null) return;
    if (key == state.activeKey) return;
    state = TabsState(tabs: state.tabs, activeKey: key);
  }

  /// Closes a tab. Pinned tabs are not closed. Returns whether it closed.
  bool close(String key) {
    final index = state.tabs.indexWhere((t) => t.tabKey == key);
    if (index < 0 || state.tabs[index].pinned) return false;
    final tabs = [...state.tabs]..removeAt(index);
    var activeKey = state.activeKey;
    if (activeKey == key) {
      activeKey = tabs.isEmpty
          ? null
          : tabs[index < tabs.length ? index : tabs.length - 1].tabKey;
    }
    state = TabsState(tabs: tabs, activeKey: activeKey);
    return true;
  }

  /// Closes every non-pinned tab except [key], which becomes active.
  void closeOthers(String key) {
    if (state.byKey(key) == null) return;
    state = TabsState(
      tabs: [
        for (final tab in state.tabs)
          if (tab.pinned || tab.tabKey == key) tab,
      ],
      activeKey: key,
    );
  }

  /// Closes the non-pinned tabs to the right of [key].
  void closeRight(String key) {
    final index = state.tabs.indexWhere((t) => t.tabKey == key);
    if (index < 0) return;
    final tabs = [
      for (var i = 0; i < state.tabs.length; i++)
        if (i <= index || state.tabs[i].pinned) state.tabs[i],
    ];
    final activeKey = tabs.any((t) => t.tabKey == state.activeKey)
        ? state.activeKey
        : key;
    state = TabsState(tabs: tabs, activeKey: activeKey);
  }

  /// Closes every non-pinned tab.
  void closeAll() {
    final tabs = [
      for (final tab in state.tabs)
        if (tab.pinned) tab,
    ];
    final activeKey = tabs.any((t) => t.tabKey == state.activeKey)
        ? state.activeKey
        : (tabs.isEmpty ? null : tabs.first.tabKey);
    state = TabsState(tabs: tabs, activeKey: activeKey);
  }

  void setDirty(String key, bool value) {
    if (state.byKey(key)?.isDirty == value) return;
    _update(key, (tab) => tab.copyWith(isDirty: value));
  }

  /// "Yenile": the module is rebuilt from scratch.
  void refresh(String key) => _update(
    key,
    (tab) => tab.copyWith(generation: tab.generation + 1, isDirty: false),
  );

  /// Updates tab titles after the menu was (re)loaded.
  void renameAll(String? Function(String moduleKey) titleOf) {
    var changed = false;
    final tabs = <TabItem>[];
    for (final tab in state.tabs) {
      final title = titleOf(tab.moduleKey);
      if (title != null && title != tab.title) {
        changed = true;
        tabs.add(tab.copyWith(title: title));
      } else {
        tabs.add(tab);
      }
    }
    if (changed) state = TabsState(tabs: tabs, activeKey: state.activeKey);
  }

  /// Moves the tab at [oldIndex] so that it ends up at [newIndex]
  /// (`onReorderItem` semantics). Pinned tabs neither move nor get passed by
  /// unpinned ones.
  void reorder(int oldIndex, int newIndex) {
    final tabs = [...state.tabs];
    if (oldIndex < 0 || oldIndex >= tabs.length || tabs[oldIndex].pinned) {
      return;
    }
    final item = tabs.removeAt(oldIndex);
    tabs.insert(newIndex.clamp(_pinnedCount(tabs), tabs.length), item);
    state = TabsState(tabs: tabs, activeKey: state.activeKey);
  }

  /// Key of the tab [offset] positions away from the active one (wraps).
  String? neighbourKey(int offset) {
    final tabs = state.tabs;
    if (tabs.isEmpty) return null;
    final index = state.activeIndex;
    if (index < 0) return (offset > 0 ? tabs.first : tabs.last).tabKey;
    return tabs[(index + offset) % tabs.length].tabKey;
  }

  void _update(String key, TabItem Function(TabItem tab) change) {
    if (state.byKey(key) == null) return;
    state = TabsState(
      tabs: [
        for (final tab in state.tabs)
          if (tab.tabKey == key) change(tab) else tab,
      ],
      activeKey: state.activeKey,
    );
  }

  static int _pinnedCount(List<TabItem> tabs) =>
      tabs.takeWhile((t) => t.pinned).length;
}

final tabsProvider = NotifierProvider<TabsNotifier, TabsState>(
  TabsNotifier.new,
);
