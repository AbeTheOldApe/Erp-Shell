/// Amounts and quantities as whole numbers of minor units, never as `double`:
/// money in kuruş (2 decimals), quantities in 1/10000 (4 decimals). Sums of
/// such numbers are exact; `0.1 + 0.2` is `30` kuruş, not `0.30000000000000004`.
///
/// Integers are exact up to 2^53 on the web, so [maxUnits] stops there.
library;

const maxUnits = 9007199254740991;

/// Why a typed number could not be turned into units.
enum UnitsError { empty, invalid, tooManyDecimals, tooLarge }

/// Result of [parseUnits]: either a [value] or an [error].
class UnitsParse {
  const UnitsParse.ok(int this.value) : error = null;
  const UnitsParse.fail(UnitsError this.error) : value = null;

  final int? value;
  final UnitsError? error;
}

final _typedNumber = RegExp(r'^-?(\d{1,3}(\.\d{3})+|\d+)?(,\d*)?$');

int _pow10(int decimals) {
  var result = 1;
  for (var i = 0; i < decimals; i++) {
    result *= 10;
  }
  return result;
}

/// Parses a number typed in Turkish format (`1.234,56`, `12,5`, `1234`) into
/// units with [decimals] fraction digits. More fraction digits than
/// [decimals] are an error, never rounded (the server does not round either);
/// trailing zeros do not count (`12,500` is fine for 2 decimals? no: `12,50`
/// is; `12,500` equals it and is accepted).
UnitsParse parseUnits(String input, {required int decimals}) {
  final text = input.trim().replaceAll(' ', '');
  if (text.isEmpty) return const UnitsParse.fail(UnitsError.empty);
  if (!_typedNumber.hasMatch(text) || !RegExp(r'\d').hasMatch(text)) {
    return const UnitsParse.fail(UnitsError.invalid);
  }
  final negative = text.startsWith('-');
  final unsigned = negative ? text.substring(1) : text;
  final parts = unsigned.split(',');
  final whole = parts[0].replaceAll('.', '');
  var fraction = parts.length > 1 ? parts[1] : '';
  fraction = fraction.replaceFirst(RegExp(r'0+$'), '');
  if (fraction.length > decimals) {
    return const UnitsParse.fail(UnitsError.tooManyDecimals);
  }
  final digits =
      '${whole.isEmpty ? '0' : whole}${fraction.padRight(decimals, '0')}'
          .replaceFirst(RegExp(r'^0+(?=\d)'), '');
  // Beyond 16 digits an int could lose precision on the web.
  if (digits.length > 16) return const UnitsParse.fail(UnitsError.tooLarge);
  final value = int.parse(digits);
  if (value > maxUnits) return const UnitsParse.fail(UnitsError.tooLarge);
  return UnitsParse.ok(negative ? -value : value);
}

/// `1.234,56` (Turkish grouping), always with [decimals] fraction digits.
String formatUnits(int units, {required int decimals}) {
  final negative = units < 0;
  final scale = _pow10(decimals);
  final absolute = units.abs();
  final whole = (absolute ~/ scale).toString();
  final grouped = whole.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  final fraction = decimals == 0
      ? ''
      : ',${(absolute % scale).toString().padLeft(decimals, '0')}';
  return '${negative ? '-' : ''}$grouped$fraction';
}

/// Form of [units] for an input field: no grouping, no trailing zeros
/// (`1234,5`).
String editableUnits(int units, {required int decimals}) {
  final negative = units < 0;
  final scale = _pow10(decimals);
  final absolute = units.abs();
  final whole = absolute ~/ scale;
  final fraction = decimals == 0
      ? ''
      : (absolute % scale)
            .toString()
            .padLeft(decimals, '0')
            .replaceFirst(RegExp(r'0+$'), '');
  return '${negative ? '-' : ''}$whole${fraction.isEmpty ? '' : ',$fraction'}';
}

/// The JSON number of [units]. The division is correctly rounded, so the
/// shortest text of the result is the decimal itself (`12345` → `123.45`).
double unitsToJson(int units, {required int decimals}) =>
    units / _pow10(decimals);

/// Units of a JSON number; `null` stays `null`.
int? unitsFromJson(Object? value, {required int decimals}) =>
    value is num ? (value * _pow10(decimals)).round() : null;
