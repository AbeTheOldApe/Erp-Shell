import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Module keys whose tab shows "Yetkiniz değişmiş olabilir" (the API
/// answered one of their requests with 403). Cleared when the menu and the
/// permissions are refreshed.
class TabAccessWarnings extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void flag(String moduleKey) {
    if (!state.contains(moduleKey)) state = {...state, moduleKey};
  }

  void dismiss(String moduleKey) {
    if (state.contains(moduleKey)) {
      state = {...state}..remove(moduleKey);
    }
  }

  void clear() {
    if (state.isNotEmpty) state = const {};
  }
}

final tabAccessWarningsProvider =
    NotifierProvider<TabAccessWarnings, Set<String>>(TabAccessWarnings.new);
