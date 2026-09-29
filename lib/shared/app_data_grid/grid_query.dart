import 'package:flutter/foundation.dart';

/// Filter operators of the query contract (`docs/menu-schema.md`).
enum FilterOp {
  eq,
  contains,

  /// Greater than or equal (dates, numbers).
  gte,

  /// Less than or equal (dates, numbers).
  lte,
}

@immutable
class GridSort {
  const GridSort(this.field, {this.descending = false});

  factory GridSort.fromJson(Map<String, dynamic> json) => GridSort(
    json['field'] as String,
    descending: json['dir'] == 'desc',
  );

  final String field;
  final bool descending;

  Map<String, dynamic> toJson() => {
    'field': field,
    'dir': descending ? 'desc' : 'asc',
  };

  @override
  bool operator ==(Object other) =>
      other is GridSort &&
      other.field == field &&
      other.descending == descending;

  @override
  int get hashCode => Object.hash(field, descending);
}

@immutable
class GridFilter {
  const GridFilter(this.field, this.op, this.value);

  factory GridFilter.fromJson(Map<String, dynamic> json) => GridFilter(
    json['field'] as String,
    FilterOp.values.byName(json['op'] as String),
    json['value'],
  );

  final String field;
  final FilterOp op;

  /// String, number or ISO date string (`yyyy-MM-dd`).
  final Object? value;

  Map<String, dynamic> toJson() => {
    'field': field,
    'op': op.name,
    'value': value,
  };

  @override
  bool operator ==(Object other) =>
      other is GridFilter &&
      other.field == field &&
      other.op == op &&
      other.value == value;

  @override
  int get hashCode => Object.hash(field, op, value);
}

/// Body of `POST /<resource>/query`:
/// `{ page, pageSize, sort: [{field, dir}], filters: [{field, op, value}] }`.
/// Pages start at 1.
@immutable
class GridQuery {
  const GridQuery({
    this.page = 1,
    this.pageSize = 25,
    this.sort = const [],
    this.filters = const [],
  });

  factory GridQuery.fromJson(Map<String, dynamic> json) => GridQuery(
    page: json['page'] as int? ?? 1,
    pageSize: json['pageSize'] as int? ?? 25,
    sort: [
      for (final s in json['sort'] as List<dynamic>? ?? [])
        GridSort.fromJson(s as Map<String, dynamic>),
    ],
    filters: [
      for (final f in json['filters'] as List<dynamic>? ?? [])
        GridFilter.fromJson(f as Map<String, dynamic>),
    ],
  );

  final int page;
  final int pageSize;
  final List<GridSort> sort;
  final List<GridFilter> filters;

  GridQuery copyWith({
    int? page,
    int? pageSize,
    List<GridSort>? sort,
    List<GridFilter>? filters,
  }) => GridQuery(
    page: page ?? this.page,
    pageSize: pageSize ?? this.pageSize,
    sort: sort ?? this.sort,
    filters: filters ?? this.filters,
  );

  Map<String, dynamic> toJson() => {
    'page': page,
    'pageSize': pageSize,
    'sort': [for (final s in sort) s.toJson()],
    'filters': [for (final f in filters) f.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      other is GridQuery &&
      other.page == page &&
      other.pageSize == pageSize &&
      listEquals(other.sort, sort) &&
      listEquals(other.filters, filters);

  @override
  int get hashCode => Object.hash(
    page,
    pageSize,
    Object.hashAll(sort),
    Object.hashAll(filters),
  );
}

/// Response of a query: `{ items: [...], total }`.
@immutable
class GridPage<T> {
  const GridPage({required this.items, required this.total});

  final List<T> items;

  /// Number of records matching the filters (all pages).
  final int total;
}

/// Loads pages of [T]. Remote sources call the API; [LocalGridDataSource]
/// works on an in-memory list.
abstract class GridDataSource<T> {
  Future<GridPage<T>> fetch(GridQuery query);
}
