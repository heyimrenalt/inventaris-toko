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

    test('rejects a year outside kMinValidYear..maxValidYear, accepts the boundaries', () {
      expect(parseDdMmYyyy('01/01/${kMinValidYear - 1}'), isNull);
      expect(parseDdMmYyyy('01/01/${maxValidYear() + 1}'), isNull);
      expect(parseDdMmYyyy('01/01/$kMinValidYear'), DateTime(kMinValidYear, 1, 1));
      expect(parseDdMmYyyy('01/01/${maxValidYear()}'), DateTime(maxValidYear(), 1, 1));
    });

    test('rejects a non-numeric segment reaching the parser directly', () {
      expect(parseDdMmYyyy('aa/01/2026'), isNull);
      expect(parseDdMmYyyy('01/aa/2026'), isNull);
      expect(parseDdMmYyyy('01/01/aaaa'), isNull);
    });

    test('rejects a negative day (the leading "-" makes int.tryParse succeed, '
        'so the day<1 bound is what actually rejects it)', () {
      expect(parseDdMmYyyy('-1/01/2026'), isNull);
    });

    test('rejects malformed slash placement', () {
      expect(parseDdMmYyyy('01//2026'), isNull);
      expect(parseDdMmYyyy('0/1/12/2026'), isNull);
    });

    test('rejects leading/trailing whitespace rather than trimming it', () {
      expect(parseDdMmYyyy(' 05/03/2026'), isNull);
      expect(parseDdMmYyyy('05/03/2026 '), isNull);
    });
  });

  group('DateInputFormatter backspace', () {
    final formatter = DateInputFormatter();

    test('deleting the literal last character at each step reformats cleanly, '
        'including the boundary where deleting an auto-inserted slash drops it '
        'instead of leaving a dangling separator', () {
      // Platform backspace removes exactly the last character of the
      // currently displayed (already-formatted) text and hands the
      // formatter oldValue=displayed, newValue=displayed-minus-last-char —
      // this walks that sequence one keystroke at a time from a full date.
      var current = '01/12/2026';
      expect(current.length, 10);

      current = _apply(formatter, current, current.substring(0, current.length - 1)).text;
      expect(current, '01/12/202'); // dropped the trailing digit '6'

      current = _apply(formatter, current, current.substring(0, current.length - 1)).text;
      expect(current, '01/12/20');

      current = _apply(formatter, current, current.substring(0, current.length - 1)).text;
      expect(current, '01/12/2');

      // Deleting the last digit of the year here also removes the slash
      // before it, since with only 4 digits left the grouping rule no
      // longer places a separator after the (now-last) 4th digit.
      current = _apply(formatter, current, current.substring(0, current.length - 1)).text;
      expect(current, '01/12');

      current = _apply(formatter, current, current.substring(0, current.length - 1)).text;
      expect(current, '01/1');

      current = _apply(formatter, current, current.substring(0, current.length - 1)).text;
      expect(current, '01');

      current = _apply(formatter, current, current.substring(0, current.length - 1)).text;
      expect(current, '0');

      current = _apply(formatter, current, current.substring(0, current.length - 1)).text;
      expect(current, '');
    });

    test('re-typing after backspacing to empty reformats from scratch', () {
      final retyped = _apply(formatter, '', 'ab01cd12ef2026gh99').text;
      expect(retyped, '01/12/2026');
    });
  });
}
