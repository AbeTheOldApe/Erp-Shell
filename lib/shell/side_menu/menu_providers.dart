import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session_controller.dart';
import '../../core/storage/key_value_store.dart';
import '../../core/storage/storage_keys.dart';
import '../../data/menu/menu_models.dart';
import '../../data/menu/menu_repository.dart';
import '../../data/menu/menu_tree.dart';
import '../tabs/tab_access_warnings.dart';

/// Menu tree of the signed-in user. Fetched once per sign-in; [reload]
/// implements "Menüyü yenile".
class MenuTreeController extends AsyncNotifier<List<MenuNode>> {
  @override
  Future<List<MenuNode>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const [];
    return _fetch();
  }

  /// Fetches the menu again. On failure the current menu is kept and the
  /// error is rethrown to the caller.
  Future<void> reload() async {
    final menu = await _fetch();
    state = AsyncData(menu);
    // Fresh permissions: earlier "permissions may have changed" warnings
    // no longer apply.
    ref.read(tabAccessWarningsProvider.notifier).clear();
  }

  Future<List<MenuNode>> _fetch() async {
    final session = ref.read(sessionProvider.notifier);
    final repository = ref.read(menuRepositoryProvider);
    final menu = await session.guard(repository.fetchMenu);
    return MenuTree.normalize(menu);
  }
}

final menuProvider = AsyncNotifierProvider<MenuTreeController, List<MenuNode>>(
  MenuTreeController.new,
);

/// Loaded menu (kept while reloading), or an empty list.
final menuNodesProvider = Provider<List<MenuNode>>((ref) {
  final menu = ref.watch(menuProvider);
  return menu.hasValue ? menu.requireValue : const [];
});

/// Whether the menu has been loaded for the current user.
final menuLoadedProvider = Provider<bool>((ref) {
  final menu = ref.watch(menuProvider);
  return menu.hasValue && !menu.isLoading;
});

/// Text in the menu search box. Survives layout changes.
class MenuSearchController extends Notifier<String> {
  @override
  String build() {
    ref.watch(currentUserIdProvider);
    return '';
  }

  void set(String value) => state = value;
}

final menuSearchProvider = NotifierProvider<MenuSearchController, String>(
  MenuSearchController.new,
);

/// Open groups of the tree, persisted per user in `localStorage`.
class MenuExpansionController extends Notifier<Set<int>> {
  int? _userId;

  @override
  Set<int> build() {
    _userId = ref.watch(currentUserIdProvider);
    final userId = _userId;
    if (userId == null) return const {};
    final stored = ref
        .read(localStoreProvider)
        .read(StorageKeys.menuExpanded(userId));
    if (stored == null) return const {};
    try {
      return {for (final id in jsonDecode(stored) as List<dynamic>) id as int};
    } catch (_) {
      return const {};
    }
  }

  void toggle(int groupId) {
    final next = {...state};
    if (!next.remove(groupId)) next.add(groupId);
    _set(next);
  }

  /// Opens [groupIds] (e.g. the ancestors of the active module).
  void expandAll(Iterable<int> groupIds) {
    if (state.containsAll(groupIds)) return;
    _set({...state, ...groupIds});
  }

  void _set(Set<int> value) {
    state = value;
    final userId = _userId;
    if (userId != null) {
      ref
          .read(localStoreProvider)
          .write(StorageKeys.menuExpanded(userId), jsonEncode(value.toList()));
    }
  }
}

final menuExpansionProvider =
    NotifierProvider<MenuExpansionController, Set<int>>(
      MenuExpansionController.new,
    );

/// Desktop preference: menu collapsed to the icon rail.
class MenuCollapsedController extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(localStoreProvider).read(StorageKeys.menuCollapsed) == 'true';

  void toggle() {
    state = !state;
    ref
        .read(localStoreProvider)
        .write(StorageKeys.menuCollapsed, state.toString());
  }
}

final menuCollapsedProvider = NotifierProvider<MenuCollapsedController, bool>(
  MenuCollapsedController.new,
);
