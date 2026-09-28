import 'package:erp_shell/core/utils/breakpoints.dart';
import 'package:erp_shell/core/utils/formatters.dart';
import 'package:erp_shell/core/utils/turkish_fold.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('turkishFold', () {
    test('ignores case and the İ/ı/I/i distinction', () {
      expect(turkishFold('İŞ EMRİ'), 'is emri');
      expect(turkishFold('iş emri'), 'is emri');
      expect(turkishFold('IŞIK'), turkishFold('ışık'));
      expect(turkishFold('Iİıi'), 'iiii');
    });

    test('ignores Turkish letters and accents', () {
      expect(turkishFold('ÇĞÖŞÜ çğöşü'), 'cgosu cgosu');
      expect(turkishFold('Kâr'), 'kar');
    });

    test('turkishContains matches folded text', () {
      expect(turkishContains('Satış Raporu', 'SATIS'), isTrue);
      expect(turkishContains('Müşteriler', 'muster'), isTrue);
      expect(turkishContains('Stok', 'sevk'), isFalse);
    });
  });

  group('Breakpoints', () {
    test('classifies by window width', () {
      expect(Breakpoints.classify(400), WindowSizeClass.compact);
      expect(Breakpoints.classify(599), WindowSizeClass.compact);
      expect(Breakpoints.classify(600), WindowSizeClass.medium);
      expect(Breakpoints.classify(1199), WindowSizeClass.medium);
      expect(Breakpoints.classify(1200), WindowSizeClass.expanded);
    });

    test('tab limits', () {
      expect(Breakpoints.tabLimit(WindowSizeClass.compact), 5);
      expect(Breakpoints.tabLimit(WindowSizeClass.medium), 10);
      expect(Breakpoints.tabLimit(WindowSizeClass.expanded), 15);
    });
  });

  group('Formatters', () {
    test('date is dd.MM.yyyy', () {
      expect(Formatters.date(DateTime(2026, 3, 7)), '07.03.2026');
    });

    test('number uses Turkish separators', () {
      expect(Formatters.number(1234.56), '1.234,56');
      expect(Formatters.integer(1234567), '1.234.567');
    });
  });
}
