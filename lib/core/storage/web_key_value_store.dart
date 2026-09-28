import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'key_value_store.dart';

KeyValueStore createLocalStore() => WebKeyValueStore.named('localStorage');

KeyValueStore createSessionStore() => WebKeyValueStore.named('sessionStorage');

/// [KeyValueStore] backed by a browser `Storage` object.
///
/// Storage may be unavailable (private mode, blocked site data); in that case
/// it falls back to memory so the app keeps working.
class WebKeyValueStore implements KeyValueStore {
  WebKeyValueStore._(this._storage);

  factory WebKeyValueStore.named(String globalName) {
    try {
      return WebKeyValueStore._(
        globalContext.getProperty<JSObject?>(globalName.toJS),
      );
    } catch (_) {
      return WebKeyValueStore._(null);
    }
  }

  final JSObject? _storage;
  final MemoryKeyValueStore _fallback = MemoryKeyValueStore();

  @override
  String? read(String key) {
    final storage = _storage;
    if (storage == null) return _fallback.read(key);
    try {
      return storage.callMethod<JSString?>('getItem'.toJS, key.toJS)?.toDart;
    } catch (_) {
      return _fallback.read(key);
    }
  }

  @override
  void write(String key, String value) {
    final storage = _storage;
    if (storage == null) return _fallback.write(key, value);
    try {
      storage.callMethod<JSAny?>('setItem'.toJS, key.toJS, value.toJS);
    } catch (_) {
      _fallback.write(key, value);
    }
  }

  @override
  void remove(String key) {
    final storage = _storage;
    if (storage == null) return _fallback.remove(key);
    try {
      storage.callMethod<JSAny?>('removeItem'.toJS, key.toJS);
    } catch (_) {
      _fallback.remove(key);
    }
  }
}
