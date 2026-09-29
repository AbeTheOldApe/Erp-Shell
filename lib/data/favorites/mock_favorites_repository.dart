import 'dart:convert';

import '../../core/storage/key_value_store.dart';
import '../mock/mock_backend.dart';
import 'favorites_repository.dart';

/// Stands in for the favorites API. The "server side" is kept in
/// `localStorage` under `mock.favorites.<username>` so favorites survive
/// sign-out and reload, like the real API will.
class MockFavoritesRepository implements FavoritesRepository {
  MockFavoritesRepository({
    required MockBackend backend,
    required KeyValueStore store,
    required String? Function() accessToken,
  }) : _backend = backend,
       _store = store,
       _accessToken = accessToken;

  final MockBackend _backend;
  final KeyValueStore _store;
  final String? Function() _accessToken;

  @override
  Future<List<String>> fetchFavorites() async {
    await _backend.latency();
    return _read(_backend.authenticate(_accessToken()));
  }

  @override
  Future<void> addFavorite(String moduleKey) async {
    await _backend.latency();
    final username = _backend.authenticate(_accessToken());
    final favorites = _read(username);
    if (!favorites.contains(moduleKey)) {
      _write(username, [...favorites, moduleKey]);
    }
  }

  @override
  Future<void> removeFavorite(String moduleKey) async {
    await _backend.latency();
    final username = _backend.authenticate(_accessToken());
    _write(username, _read(username)..remove(moduleKey));
  }

  static String _key(String username) => 'mock.favorites.$username';

  List<String> _read(String username) {
    final raw = _store.read(_key(username));
    if (raw == null) return [];
    try {
      return [for (final key in jsonDecode(raw) as List<dynamic>) '$key'];
    } catch (_) {
      return [];
    }
  }

  void _write(String username, List<String> favorites) =>
      _store.write(_key(username), jsonEncode(favorites));
}
