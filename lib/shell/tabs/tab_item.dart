import 'package:flutter/foundation.dart';

/// An open module tab. `tabKey == moduleKey`: a module has at most one tab.
@immutable
class TabItem {
  const TabItem({
    required this.moduleKey,
    required this.title,
    this.pinned = false,
    this.isDirty = false,
    this.query = const {},
    this.queryVersion = 0,
    this.generation = 0,
  });

  final String moduleKey;
  final String title;

  /// Pinned tabs cannot be closed and always stay on the left (Cockpit,
  /// phase 2).
  final bool pinned;

  /// The module reported unsaved changes.
  final bool isDirty;

  /// Query parameters the module was last opened with.
  final Map<String, String> query;

  /// Incremented whenever [query] changes for an already open tab.
  final int queryVersion;

  /// Incremented by "Yenile"; the module is rebuilt from scratch.
  final int generation;

  String get tabKey => moduleKey;

  TabItem copyWith({
    String? title,
    bool? isDirty,
    Map<String, String>? query,
    int? queryVersion,
    int? generation,
  }) => TabItem(
    moduleKey: moduleKey,
    title: title ?? this.title,
    pinned: pinned,
    isDirty: isDirty ?? this.isDirty,
    query: query ?? this.query,
    queryVersion: queryVersion ?? this.queryVersion,
    generation: generation ?? this.generation,
  );
}
