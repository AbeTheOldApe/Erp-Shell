import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session_controller.dart';
import '../../core/storage/key_value_store.dart';
import '../../core/storage/storage_keys.dart';

/// The last [limit] modules the user switched to, most recent first.
/// Persisted per user in `localStorage`.
class RecentModulesController extends Notifier<List<String>> {
  static const limit = 5;

  int? _userId;

  @override
  List<String> build() {
    _userId = ref.watch(currentUserIdProvider);
    final userId = _userId;
    if (userId == null) return const [];
    final raw = ref
        .read(localStoreProvider)
        .read(StorageKeys.recentModules(userId));
    if (raw == null) return const [];
    try {
      return [
        for (final key in jsonDecode(raw) as List<dynamic>) '$key',
      ].take(limit).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Moves [moduleKey] to the front of the list.
  void touch(String moduleKey) {
    final userId = _userId;
    if (userId == null || (state.isNotEmpty && state.first == moduleKey)) {
      return;
    }
    state = [
      moduleKey,
      for (final key in state)
        if (key != moduleKey) key,
    ].take(limit).toList();
    ref
        .read(localStoreProvider)
        .write(StorageKeys.recentModules(userId), jsonEncode(state));
  }
}

final recentModulesProvider =
    NotifierProvider<RecentModulesController, List<String>>(
      RecentModulesController.new,
    );
