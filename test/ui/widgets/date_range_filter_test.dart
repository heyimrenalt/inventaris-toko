import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/ui/widgets/date_range_filter.dart';

TextEditingValue _apply(DateInputFormatter formatter, String oldText, String newText) {
  return formatter.formatEditUpdate(
    TextEditingValue(text: oldText),
    TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: newText.length)),
  );
}

TextEditingValue _at(DateInputFormatter formatter, String oldText, String newText, int caret) {
  return formatter.formatEditUpdate(
    TextEditingValue(text: oldText),
    TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: caret)),
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

    test('leaves the caret at the end when typing left to right', () {
      expect(_apply(formatter, '', '0').selection.baseOffset, 1);
      expect(_apply(formatter, '0', '01').selection.baseOffset, 2);
      // The third digit pushes the caret past the "/" the formatter inserts.
      expect(_apply(formatter, '01', '011').selection.baseOffset, 4);
      expect(_apply(formatter, '01/1', '01/12').selection.baseOffset, 5);
      expect(_apply(formatter, '01/12', '01/122').selection.baseOffset, 7);
      expect(_apply(formatter, '01/12/2', '01/12/2026').selection.baseOffset, 10);
    });

    test('keeps the caret in place when a digit is typed in the middle', () {
      // "12/07/2026" with the caret after "12/0"; typing 9 there gives
      // "12/09" + the rest, and the caret must sit after the new 9.
      final result = _at(formatter, '12/07/2026', '12/097/2026', 5);
      expect(result.text, '12/09/7202');
      expect(result.selection.baseOffset, 5);
    });

    test('keeps the caret in place when a digit is deleted in the middle', () {
      // Backspace over the "7" of "12/07/2026".
      final result = _at(formatter, '12/07/2026', '12/0/2026', 4);
      expect(result.text, '12/02/026');
      expect(result.selection.baseOffset, 4);
    });

    test('handles a caret sitting on either side of a "/"', () {
      // Typed against the "/" from the left — the digit belongs to the day
      // side, so the caret follows it across the separator.
      final before = _at(formatter, '12/07/2026', '129/07/2026', 3);
      expect(before.text, '12/90/7202');
      expect(before.selection.baseOffset, 4);

      // Typed against it from the right: same three digits precede the
      // caret, so it lands in the same place.
      final after = _at(formatter, '12/07/2026', '12/907/2026', 4);
      expect(after.text, '12/90/7202');
      expect(after.selection.baseOffset, 4);

      // Deleting the separator itself removes no digit, so the text is
      // unchanged and the caret rests before the restored "/".
      final slashDeleted = _at(formatter, '12/07/2026', '1207/2026', 2);
      expect(slashDeleted.text, '12/07/2026');
      expect(slashDeleted.selection.baseOffset, 2);
    });

    test('handles the caret at position 0', () {
      final result = _at(formatter, '12/07/2026', '312/07/2026', 1);
      expect(result.text, '31/20/7202');
      expect(result.selection.baseOffset, 1);
    });

    test('caps the caret when a full field overflows', () {
      // Eight digits already; the ninth is truncated away, and the caret
      // never runs past the formatted text.
      final result = _at(formatter, '12/07/2026', '12/097/2026', 5);
      expect(result.text.length, 10);
      expect(result.selection.baseOffset, lessThanOrEqualTo(result.text.length));

      // Truncation at the tail: digits beyond the caret are the ones lost,
      // so a caret past the cut is clamped to the end of the field.
      final tail = _at(formatter, '12/07/2026', '12/07/20269', 11);
      expect(tail.text, '12/07/2026');
      expect(tail.selection.baseOffset, 10);
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
      expect(parse('01/01/2020', first: DateTime(2020)), DateTime(2020, 1, 1));
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
      expect(validate('01/01/19').error, dateRangeError(firstDate, lastDate));
      expect(validate('01/01/3').error, dateRangeError(firstDate, lastDate));
      expect(validate('01/01/9').error, dateRangeError(firstDate, lastDate));
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
      expect(validate('01/01/2019').error, dateRangeError(firstDate, lastDate));
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

  group('dateRangeError granularity follows the bounds', () {
    test('bounds in different years name the years', () {
      expect(
        dateRangeError(DateTime(2024, 3, 4), DateTime(2026, 9, 1)),
        'Tahun harus antara 2024\u20132026',
      );
    });

    test('bounds inside one year name the months instead', () {
      // The case the old year-only message made useless: with a floor
      // derived from the oldest real mutation, both bounds routinely sit
      // in the same year and "antara 2026-2026" told the user nothing.
      expect(
        dateRangeError(DateTime(2026, 8, 19), DateTime(2026, 9, 1)),
        'Tanggal harus antara Agu 2026 \u2013 Sep 2026',
      );
    });

    test('bounds inside one month name that single month', () {
      expect(
        dateRangeError(DateTime(2026, 8, 19), DateTime(2026, 8, 31)),
        'Tanggal harus di bulan Agu 2026',
      );
    });

    test('the month form is what a rejected year prefix actually shows', () {
      final validation = validateDateInput(
        '01/01/1999',
        firstDate: DateTime(2026, 8, 19),
        lastDate: DateTime(2026, 9, 1),
      );
      expect(validation.error, 'Tanggal harus antara Agu 2026 \u2013 Sep 2026');
    });
  });

  group('error messages render in full instead of being truncated', () {
    // The longest message the field can show, and the shape that was
    // being clipped before errorMaxLines was set. Since the bound became
    // data-derived this is the *month* form, not the year form: bounds
    // inside one year now report months, which is several characters
    // longer than "Tahun harus antara 2020–2026" ever was.
    final longest = dateRangeError(DateTime(2026, 8, 19), DateTime(2026, 9, 1));

    Future<void> pumpBar(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateRangeFilterBar(
              selectedRange: null,
              onChanged: (_) {},
              firstDate: DateTime(2026, 8, 19),
              lastDate: DateTime(2026, 9, 1),
            ),
          ),
        ),
      );
    }

    for (final field in const ['mutasi_date_start_field', 'mutasi_date_end_field']) {
      testWidgets('$field shows the whole out-of-range message across lines', (tester) async {
        // A narrow phone width is what made the single line overflow.
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await pumpBar(tester);
        // "01/01/19…" — the year prefix rules every allowed year out.
        await tester.enterText(find.byKey(Key(field)), '01011999');
        await tester.pump();

        final error = tester.widget<Text>(find.text(longest));
        expect(error.data, longest);
        expect(error.maxLines, isNot(1));
        expect(error.maxLines, greaterThan(1));
        // The rendered paragraph must not have been ellipsized away.
        expect(tester.renderObject<RenderParagraph>(find.text(longest)).didExceedMaxLines, isFalse);
      });
    }

  });
}
