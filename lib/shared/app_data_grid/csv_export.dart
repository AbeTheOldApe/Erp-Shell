import 'app_grid_column.dart';

/// Builds a CSV that Excel opens correctly with Turkish settings:
/// `;` separator (`,` is the decimal separator), CRLF line ends, UTF-8
/// byte order mark, values formatted like on screen.
String buildCsv<T>(List<AppGridColumn<T>> columns, List<T> rows) {
  String escape(String value) {
    final needsQuotes =
        value.contains(';') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    final escaped = value.replaceAll('"', '""');
    return needsQuotes ? '"$escaped"' : escaped;
  }

  final buffer = StringBuffer('﻿')
    ..write(columns.map((c) => escape(c.title)).join(';'))
    ..write('\r\n');
  for (final row in rows) {
    buffer
      ..write(columns.map((c) => escape(c.display(row))).join(';'))
      ..write('\r\n');
  }
  return buffer.toString();
}
