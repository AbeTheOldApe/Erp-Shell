import 'package:intl/intl.dart';

/// Display formats: dates as `dd.MM.yyyy`, numbers as `1.234,56`.
abstract final class Formatters {
  static final DateFormat _date = DateFormat('dd.MM.yyyy', 'en_US');
  static final DateFormat _dateTime = DateFormat('dd.MM.yyyy HH:mm', 'en_US');

  static String date(DateTime value) => _date.format(value);

  static String dateTime(DateTime value) => _dateTime.format(value);

  /// Formats [value] with Turkish grouping and [decimals] fraction digits.
  static String number(num value, {int decimals = 2}) {
    final pattern = decimals > 0 ? '#,##0.${'0' * decimals}' : '#,##0';
    return NumberFormat(pattern, 'tr').format(value);
  }

  static String integer(num value) => number(value, decimals: 0);

  /// Parses a number typed in Turkish format (`1.234,56`, `12,5`, `1234`).
  /// Returns null when it is not a number.
  static double? tryParseNumber(String input) {
    final text = input.trim().replaceAll(' ', '');
    if (text.isEmpty) return null;
    if (!RegExp(r'^-?[\d.]*(,\d+)?$').hasMatch(text)) return null;
    return double.tryParse(text.replaceAll('.', '').replaceAll(',', '.'));
  }

  /// Editable form of a number: no grouping, comma decimals (`1234,5`).
  static String editable(num value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString().replaceAll('.', ',');
  }
}
