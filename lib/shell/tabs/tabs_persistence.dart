import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/key_value_store.dart';
import '../../core/storage/storage_keys.dart';
import 'tabs_notifier.dart';

/// A tab to restore after a reload: which module and with which query.
/// Titles come from the menu and form contents are not restored.
@immutable
class SavedTab {
  const SavedTab(this.moduleKey, [this.query = const {}]);

  final String moduleKey;
  final Map<String, String> query;
}

/// Saves the open tabs of this browser tab in `sessionStorage` so they come
/// back after F5. Pinned tabs are not saved; the shell re-adds them.
class TabsPersistence {
  const TabsPersistence(this._store);

  final KeyValueStore _store;

  void save(int userId, TabsState state) {
    _store.write(
      StorageKeys.tabs(userId),
      jsonEncode({
        'tabs': [
          for (final tab in state.tabs)
            if (!tab.pinned) {'moduleKey': tab.moduleKey, 'query': tab.query},
        ],
        'activeKey': state.activeKey,
      }),
    );
  }

  List<SavedTab> load(int userId) {
    final raw = _store.read(StorageKeys.tabs(userId));
    if (raw == null) return const [];
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return [
        for (final tab in json['tabs'] as List<dynamic>)
          SavedTab(
            (tab as Map<String, dynamic>)['moduleKey'] as String,
            {
              for (final entry
                  in (tab['query'] as Map<String, dynamic>? ?? {}).entries)
                entry.key: '${entry.value}',
            },
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  void clear(int userId) => _store.remove(StorageKeys.tabs(userId));
}

final tabsPersistenceProvider = Provider<TabsPersistence>(
  (ref) => TabsPersistence(ref.watch(sessionStoreProvider)),
);
