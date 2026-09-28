import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'key_value_store_factory_stub.dart'
    if (dart.library.js_interop) 'web_key_value_store.dart'
    as platform;

/// Minimal synchronous key-value storage.
///
/// On the web it is backed by `localStorage` or `sessionStorage`.
abstract class KeyValueStore {
  String? read(String key);
  void write(String key, String value);
  void remove(String key);
}

/// In-memory store; used in tests and on platforms without web storage.
class MemoryKeyValueStore implements KeyValueStore {
  MemoryKeyValueStore([Map<String, String>? initial])
    : _values = {...?initial};

  final Map<String, String> _values;

  @override
  String? read(String key) => _values[key];

  @override
  void write(String key, String value) => _values[key] = value;

  @override
  void remove(String key) => _values.remove(key);
}

/// Persistent, shared across browser tabs (`localStorage`).
final localStoreProvider = Provider<KeyValueStore>(
  (ref) => platform.createLocalStore(),
);

/// Per browser tab (`sessionStorage`).
final sessionStoreProvider = Provider<KeyValueStore>(
  (ref) => platform.createSessionStore(),
);
