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

  // Fixed bounds so nothing here depends on the wall clock: "today" is
  // 25 August 2026 for every test below, and the floor is 1 Jan 2020 —
  // the same shape ReportPeriodFilter passes in production.
  final firstDate = DateTime(2020);
  final lastDate = DateTime(2026, 8, 25);

  DateTime? parse(String text, {DateTime? first, DateTime? last}) => parseDdMmYyyy(
        text,
        firstDate: first ?? firstDate,
        lastDate: last ?? lastDate,
      );

  DateInputValidation validate(String text, {DateTime? first, DateTime? last}) => validateDateInput(
        text,
        firstDate: first ?? firstDate,
        lastDate: last ?? lastDate,
      );

  group('parseDdMmYyyy', () {
    test('parses a genuine DD/MM/YYYY date', () {
      expect(parse('05/03/2026'), DateTime(2026, 3, 5));
    });

    test('rejects a day that never exists in any month', () {
      expect(parse('32/01/2026'), isNull);
      expect(parse('00/01/2026'), isNull);
    });

    test('rejects a month outside 1-12', () {
      expect(parse('01/13/2026'), isNull);
      expect(parse('01/00/2026'), isNull);
    });

    test('rejects 30 February and 31 April without a hand-rolled days-per-month table', () {
      expect(parse('30/02/2026'), isNull);
      expect(parse('31/04/2026'), isNull);
    });

    test('rejects every 31st of a 30-day month', () {
      expect(parse('31/09/2025'), isNull);
      expect(parse('31/06/2025'), isNull);
      expect(parse('31/11/2025'), isNull);
      expect(parse('30/09/2025'), DateTime(2025, 9, 30));
    });

    test('accepts 29 February on a leap year, rejects it otherwise', () {
      expect(parse('29/02/2024'), DateTime(2024, 2, 29));
      expect(parse('29/02/2025'), isNull);
      expect(parse('29/02/2026'), isNull);
    });

    test('rejects incomplete or malformed input', () {
      expect(parse('01/01/26'), isNull);
      expect(parse('01/01'), isNull);
      expect(parse(''), isNull);
    });

    test('rejects a date after the caller lastDate, accepts today and yesterday', () {
      expect(parse('26/08/2026'), isNull);
      expect(parse('01/09/2026'), isNull);
      expect(parse('31/12/2026'), isNull);
      expect(parse('25/08/2026'), DateTime(2026, 8, 25));
      expect(parse('24/08/2026'), DateTime(2026, 8, 24));
    });

    test('a lastDate carrying a time-of-day still means the whole day, so '
        'today is accepted rather than cut off at midnight', () {
      expect(
        parse('25/08/2026', last: DateTime(2026, 8, 25, 14, 37)),
        DateTime(2026, 8, 25),
      );
    });

    test('rejects a date before the caller firstDate, accepts the boundary', () {
      expect(parse('31/12/2019'), isNull);
      expect(parse('01/01/2020'), DateTime(2020, 1, 1));
    });

    test('honours each host own lower bound rather than a shared constant', () {
      // Mutasi tab: DateTime(now.year - 2).
      final mutasiFloor = DateTime(2024);
      expect(parse('31/12/2023', first: mutasiFloor), isNull);
      expect(parse('01/01/2024', first: mutasiFloor), DateTime(2024, 1, 1));
      // Riwayat per-produk: DateTime(now.year - 5).
      final historyFloor = DateTime(2021);
      expect(parse('31/12/2020', first: historyFloor), isNull);
      expect(parse('01/01/2021', first: historyFloor), DateTime(2021, 1, 1));
      // The report screens floor, which is still 2020.
      expect(parse('01/01/2020', first: DateTime(kMinValidYear)), DateTime(2020, 1, 1));
    });

    test('rejects a non-numeric segment reaching the parser directly', () {
      expect(parse('aa/01/2026'), isNull);
      expect(parse('01/aa/2026'), isNull);
      expect(parse('01/01/aaaa'), isNull);
    });

    test('rejects a negative day (the leading "-" makes int.tryParse succeed, '
        'so the day<1 bound is what actually rejects it)', () {
      expect(parse('-1/01/2026'), isNull);
    });

    test('rejects malformed slash placement', () {
      expect(parse('01//2026'), isNull);
      expect(parse('0/1/12/2026'), isNull);
    });

    test('rejects leading/trailing whitespace rather than trimming it', () {
      expect(parse(' 05/03/2026'), isNull);
      expect(parse('05/03/2026 '), isNull);
    });
  });

  group('validateDateInput — live prefixes', () {
    test('empty input is neither valid nor an error', () {
      expect(validate('').error, isNull);
      expect(validate('').isValid, isFalse);
    });

    test('a day whose first digit can never lead anywhere fails on that very '
        'keystroke, without waiting for the rest of the date', () {
      // 8 can only reach 80-89, so "82" is doomed the moment the 8 lands.
      expect(validate('8').error, kInvalidDateError);
      expect(validate('82').error, kInvalidDateError);
      expect(validate('4').error, kInvalidDateError);
      expect(validate('42').error, kInvalidDateError);
      expect(validate('9').error, kInvalidDateError);
    });

    test('a day prefix that could still become valid is left alone', () {
      expect(validate('2').error, isNull);
      expect(validate('29').error, isNull);
      expect(validate('1').error, isNull);
      expect(validate('0').error, isNull);
      expect(validate('3').error, isNull);
      expect(validate('31').error, isNull);
    });

    test('a completed day outside 1-31 is flagged at the second digit', () {
      expect(validate('32').error, kInvalidDateError);
      expect(validate('00').error, kInvalidDateError);
    });

    test('the month follows the same rule: a leading digit above 1 is hopeless', () {
      expect(validate('01/2').error, kInvalidDateError);
      expect(validate('01/9').error, kInvalidDateError);
      expect(validate('01/1').error, isNull);
      expect(validate('01/0').error, isNull);
    });

    test('a completed month outside 1-12 is flagged at its second digit', () {
      expect(validate('01/13').error, kInvalidDateError);
      expect(validate('01/00').error, kInvalidDateError);
      expect(validate('01/12').error, isNull);
    });

    test('day-vs-month is caught as soon as the month is complete, long '
        'before the year is typed', () {
      expect(validate('31/09').error, kInvalidDateError);
      expect(validate('31/04').error, kInvalidDateError);
      expect(validate('30/02').error, kInvalidDateError);
      expect(validate('31/06').error, kInvalidDateError);
    });

    test('29/02 waits for the year, because only the year settles it', () {
      expect(validate('29/02').error, isNull);
      expect(validate('29/02/20').error, isNull);
      expect(validate('29/02/2024').isValid, isTrue);
      expect(validate('29/02/2025').error, kInvalidDateError);
    });

    test('a year prefix that rules out every allowed year fails early', () {
      expect(validate('01/01/19').error, yearRangeError(firstDate, lastDate));
      expect(validate('01/01/3').error, yearRangeError(firstDate, lastDate));
      expect(validate('01/01/9').error, yearRangeError(firstDate, lastDate));
    });

    test('a year prefix that could still land in range is left alone', () {
      expect(validate('01/01/2').error, isNull);
      expect(validate('01/01/20').error, isNull);
      expect(validate('01/01/202').error, isNull);
    });

    test('a future date is rejected with its own message, not the generic one', () {
      expect(validate('26/08/2026').error, kFutureDateError);
      expect(validate('01/12/2026').error, kFutureDateError);
    });

    test('today and yesterday are valid', () {
      expect(validate('25/08/2026').isValid, isTrue);
      expect(validate('25/08/2026').error, isNull);
      expect(validate('24/08/2026').isValid, isTrue);
    });

    test('a real date below the floor reports the year range', () {
      expect(validate('01/01/2019').error, yearRangeError(firstDate, lastDate));
    });

    test('typing a valid past date never errors at any point along the way', () {
      const target = '05/03/2026';
      for (var i = 1; i < target.length; i++) {
        expect(validate(target.substring(0, i)).error, isNull, reason: 'errored at "${target.substring(0, i)}"');
      }
      expect(validate(target).date, DateTime(2026, 3, 5));
    });

    test('validation is complete-date-only for isValid, so a partial date is '
        'never reported as valid', () {
      expect(validate('05/03/202').isValid, isFalse);
      expect(validate('05/03').isValid, isFalse);
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
