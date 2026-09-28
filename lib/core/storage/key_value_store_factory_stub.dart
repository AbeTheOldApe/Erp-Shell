import 'key_value_store.dart';

KeyValueStore createLocalStore() => MemoryKeyValueStore();

KeyValueStore createSessionStore() => MemoryKeyValueStore();
