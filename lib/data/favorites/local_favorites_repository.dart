import 'dart:convert';

import '../../core/storage/key_value_store.dart';
import 'favorites_repository.dart';

/// Favorites of the real mode, kept in `localStorage` per user until they
/// move to the API (`CLAUDE.md`, "Favoriler (gerçek mod)").
class LocalFavoritesRepository implements FavoritesRepository {
  LocalFavoritesRepository({
    required KeyValueStore store,
    required int? Function() userId,
  }) : _store = store,
       _userId = userId;

  final KeyValueStore _store;
  final int? Function() _userId;

  @override
  Future<List<String>> fetchFavorites() async => _read();

  @override
  Future<void> addFavorite(String moduleKey) async {
    final favorites = _read();
    if (!favorites.contains(moduleKey)) _write([...favorites, moduleKey]);
  }

  @override
  Future<void> removeFavorite(String moduleKey) async =>
      _write(_read()..remove(moduleKey));

  String? get _key {
    final id = _userId();
    return id == null ? null : 'favorites.$id';
  }

  List<String> _read() {
    final key = _key;
    final raw = key == null ? null : _store.read(key);
    if (raw == null) return [];
    try {
      return [for (final item in jsonDecode(raw) as List<dynamic>) '$item'];
    } catch (_) {
      return [];
    }
  }

  void _write(List<String> favorites) {
    final key = _key;
    if (key != null) _store.write(key, jsonEncode(favorites));
  }
}
