import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/storage/key_value_store.dart';

/// Column order, widths and hidden columns of one grid, stored per user
/// under `ui.grid.<userId>.<moduleKey>.<gridId>` in `localStorage`.
@immutable
class GridPreferences {
  const GridPreferences({
    this.order = const [],
    this.widths = const {},
    this.hidden = const {},
  });

  factory GridPreferences.fromJson(Map<String, dynamic> json) =>
      GridPreferences(
        order: [for (final f in json['order'] as List<dynamic>? ?? []) '$f'],
        widths: {
          for (final e
              in (json['widths'] as Map<String, dynamic>? ?? {}).entries)
            e.key: (e.value as num).toDouble(),
        },
        hidden: {for (final f in json['hidden'] as List<dynamic>? ?? []) '$f'},
      );

  static String storageKey(int? userId, String moduleKey, String gridId) =>
      'ui.grid.${userId ?? 'anon'}.$moduleKey.$gridId';

  static GridPreferences load(KeyValueStore store, String key) {
    final raw = store.read(key);
    if (raw == null) return const GridPreferences();
    try {
      return GridPreferences.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const GridPreferences();
    }
  }

  final List<String> order;
  final Map<String, double> widths;
  final Set<String> hidden;

  void save(KeyValueStore store, String key) =>
      store.write(key, jsonEncode(toJson()));

  Map<String, dynamic> toJson() => {
    'order': order,
    'widths': widths,
    'hidden': hidden.toList(),
  };

  /// [fields] reordered by the saved order; unknown saved fields are
  /// ignored and new fields keep their place at the end.
  List<String> applyOrder(List<String> fields) {
    final known = [
      for (final f in order)
        if (fields.contains(f)) f,
    ];
    return [
      ...known,
      for (final f in fields)
        if (!known.contains(f)) f,
    ];
  }

  @override
  bool operator ==(Object other) =>
      other is GridPreferences &&
      listEquals(other.order, order) &&
      mapEquals(other.widths, widths) &&
      setEquals(other.hidden, hidden);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(order),
    Object.hashAllUnordered(
      widths.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    Object.hashAllUnordered(hidden),
  );
}
