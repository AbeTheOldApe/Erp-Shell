import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session_controller.dart';
import '../../data/favorites/favorites_repository.dart';

/// Favorite module keys of the signed-in user, in the order they were
/// added. Changes are applied optimistically and rolled back on failure.
class FavoritesController extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const [];
    return ref
        .read(sessionProvider.notifier)
        .guard(ref.read(favoritesRepositoryProvider).fetchFavorites);
  }

  bool isFavorite(String moduleKey) =>
      (state.hasValue ? state.requireValue : const <String>[]).contains(
        moduleKey,
      );

  /// Adds or removes [moduleKey]. Rethrows when the API call fails.
  Future<void> toggle(String moduleKey) async {
    final previous = state.hasValue ? state.requireValue : const <String>[];
    final adding = !previous.contains(moduleKey);
    state = AsyncData(
      adding
          ? [...previous, moduleKey]
          : [
              for (final key in previous)
                if (key != moduleKey) key,
            ],
    );
    final repository = ref.read(favoritesRepositoryProvider);
    try {
      await ref
          .read(sessionProvider.notifier)
          .guard(
            () => adding
                ? repository.addFavorite(moduleKey)
                : repository.removeFavorite(moduleKey),
          );
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
  }
}

final favoritesProvider =
    AsyncNotifierProvider<FavoritesController, List<String>>(
      FavoritesController.new,
    );

/// Favorites as a plain list (empty while loading or on error).
final favoriteKeysProvider = Provider<List<String>>((ref) {
  final favorites = ref.watch(favoritesProvider);
  return favorites.hasValue ? favorites.requireValue : const [];
});
