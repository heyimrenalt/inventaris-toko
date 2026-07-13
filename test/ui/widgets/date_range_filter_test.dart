import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/ui/widgets/date_range_filter.dart';

TextEditingValue _apply(DateInputFormatter formatter, String oldText, String newText) {
  return formatter.formatEditUpdate(
    TextEditingValue(text: oldText),
    TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: newText.length)),
  );
}

void main() {
  group('DateInputFormatter', () {
    final formatter = DateInputFormatter();

    test('inserts "/" after the day and month as digits are typed', () {
      expect(_apply(formatter, '', '0').text, '0');
      expect(_apply(formatter, '0', '01').text, '01');
      expect(_apply(formatter, '01', '011').text, '01/1');
      expect(_apply(formatter, '01/1', '01/12').text, '01/12');
      expect(_apply(formatter, '01/12', '01/122').text, '01/12/2');
      expect(_apply(formatter, '01/12/2', '01/12/2026').text, '01/12/2026');
    });

    test('ignores non-digit characters and caps at 8 digits (DD/MM/YYYY)', () {
      expect(_apply(formatter, '', 'ab01cd12ef2026gh99').text, '01/12/2026');
    });
  });

  group('parseDdMmYyyy', () {
    test('parses a genuine DD/MM/YYYY date', () {
      final date = parseDdMmYyyy('05/03/2026');
      expect(date, DateTime(2026, 3, 5));
    });

    test('rejects a day that never exists in any month', () {
      expect(parseDdMmYyyy('32/01/2026'), isNull);
      expect(parseDdMmYyyy('00/01/2026'), isNull);
    });

    test('rejects a month outside 1-12', () {
      expect(parseDdMmYyyy('01/13/2026'), isNull);
      expect(parseDdMmYyyy('01/00/2026'), isNull);
    });

    test('rejects 30 February and 31 April without a hand-rolled days-per-month table', () {
      expect(parseDdMmYyyy('30/02/2026'), isNull);
      expect(parseDdMmYyyy('31/04/2026'), isNull);
    });

    test('accepts 29 February on a leap year, rejects it otherwise', () {
      expect(parseDdMmYyyy('29/02/2024'), DateTime(2024, 2, 29));
      expect(parseDdMmYyyy('29/02/2026'), isNull);
    });

    test('rejects incomplete or malformed input', () {
      expect(parseDdMmYyyy('01/01/26'), isNull);
      expect(parseDdMmYyyy('01/01'), isNull);
      expect(parseDdMmYyyy(''), isNull);
    });
  });
}
