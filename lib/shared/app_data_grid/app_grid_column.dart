import 'package:flutter/foundation.dart';

import '../../core/utils/formatters.dart';

/// How a column's value is shown and aligned: `number` as an integer
/// (`1.234`), `decimal` and `money` with two decimals (`1.234,50`).
enum GridColumnKind { text, number, decimal, money, date }

/// Column definition of an [AppDataGrid] (independent of TrinaGrid).
@immutable
class AppGridColumn<T> {
  const AppGridColumn({
    required this.field,
    required this.title,
    required this.value,
    this.kind = GridColumnKind.text,
    this.width = 160,
    this.sortable = true,
    this.showInCard = true,
    this.cardTitle = false,
  });

  /// Field name used in sort/filter requests and column preferences.
  final String field;
  final String title;

  /// Raw value of the row for this column.
  final Object? Function(T row) value;
  final GridColumnKind kind;
  final double width;
  final bool sortable;

  /// Shown on the phone card layout.
  final bool showInCard;

  /// Used as the card's heading on phones (first such column).
  final bool cardTitle;

  bool get alignEnd =>
      kind == GridColumnKind.number ||
      kind == GridColumnKind.decimal ||
      kind == GridColumnKind.money;

  /// Display text using the app formats (`dd.MM.yyyy`, `1.234,56`).
  String display(T row) {
    final raw = value(row);
    if (raw == null) return '';
    return switch (kind) {
      GridColumnKind.date when raw is DateTime => Formatters.date(raw),
      GridColumnKind.money || GridColumnKind.decimal when raw is num =>
        Formatters.number(raw),
      GridColumnKind.number when raw is num => Formatters.integer(raw),
      _ => '$raw',
    };
  }
}
