import '../../core/utils/turkish_fold.dart';
import 'grid_query.dart';

/// [GridDataSource] over an in-memory list: filtering, sorting and paging
/// happen locally, with the same semantics as the query API. Also used by
/// the mock repositories.
class LocalGridDataSource<T> implements GridDataSource<T> {
  LocalGridDataSource(this.items, {required this.fieldValue});

  final List<T> items;

  /// Raw value of [field] for a row (String, num, DateTime, ...).
  final Object? Function(T row, String field) fieldValue;

  @override
  Future<GridPage<T>> fetch(GridQuery query) async => apply(query);

  GridPage<T> apply(GridQuery query) {
    final filtered = [
      for (final item in items)
        if (query.filters.every((f) => _matches(fieldValue(item, f.field), f)))
          item,
    ];
    if (query.sort.isNotEmpty) {
      filtered.sort((a, b) {
        for (final sort in query.sort) {
          final result = _compare(
            fieldValue(a, sort.field),
            fieldValue(b, sort.field),
          );
          if (result != 0) return sort.descending ? -result : result;
        }
        return 0;
      });
    }
    final start = (query.page - 1) * query.pageSize;
    return GridPage(
      items: filtered.skip(start).take(query.pageSize).toList(),
      total: filtered.length,
    );
  }

  static bool _matches(Object? value, GridFilter filter) {
    final target = filter.value;
    if (target == null || (target is String && target.isEmpty)) return true;
    switch (filter.op) {
      case FilterOp.contains:
        return turkishContains('${value ?? ''}', '$target');
      case FilterOp.eq:
        return value is String
            ? turkishFold(value) == turkishFold('$target')
            : _compare(value, _coerce(value, target)) == 0;
      case FilterOp.gte:
        return _compare(value, _coerce(value, target)) >= 0;
      case FilterOp.lte:
        return _compare(value, _coerce(value, target)) <= 0;
    }
  }

  /// Parses string filter values (ISO dates, numbers) to the column type.
  static Object? _coerce(Object? sample, Object target) {
    if (target is! String) return target;
    if (sample is DateTime) return DateTime.tryParse(target) ?? target;
    if (sample is num) return num.tryParse(target) ?? target;
    return target;
  }

  static int _compare(Object? a, Object? b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;
    if (a is DateTime && b is DateTime) {
      // Date filters compare by day.
      return DateTime(a.year, a.month, a.day)
          .compareTo(DateTime(b.year, b.month, b.day));
    }
    if (a is num && b is num) return a.compareTo(b);
    return turkishFold('$a').compareTo(turkishFold('$b'));
  }
}
