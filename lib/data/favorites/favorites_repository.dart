import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session_controller.dart';
import '../../core/config/app_config.dart';
import '../../core/storage/key_value_store.dart';
import '../mock/mock_backend.dart';
import 'local_favorites_repository.dart';
import 'mock_favorites_repository.dart';

/// Favorite modules of the signed-in user (`docs/menu-schema.md` §1):
/// `GET /me/favorites`, `PUT /me/favorites/{moduleKey}`,
/// `DELETE /me/favorites/{moduleKey}`.
abstract class FavoritesRepository {
  /// Module keys in the order they were added.
  Future<List<String>> fetchFavorites();

  Future<void> addFavorite(String moduleKey);

  Future<void> removeFavorite(String moduleKey);
}

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMock) {
    return MockFavoritesRepository(
      backend: ref.watch(mockBackendProvider),
      store: ref.watch(localStoreProvider),
      accessToken: () => ref.read(sessionProvider).session?.accessToken,
    );
  }
  return LocalFavoritesRepository(
    store: ref.watch(localStoreProvider),
    userId: () => ref.read(currentUserIdProvider),
  );
});
