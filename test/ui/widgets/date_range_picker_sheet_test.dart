import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/ui/widgets/date_range_picker_sheet.dart';

void main() {
  Future<void> openSheet(WidgetTester tester, {DateTimeRange? initialRange}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                await showDateRangePickerSheet(
                  context: context,
                  initialRange: initialRange,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2026, 12, 31),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('Terapkan is disabled until both fields hold valid dates', (tester) async {
    await openSheet(tester);

    final applyButton = tester.widget<ElevatedButton>(find.byKey(const Key('date_range_sheet_apply_button')));
    expect(applyButton.onPressed, isNull);

    await tester.enterText(find.byKey(const Key('date_range_sheet_start_field')), '01012026');
    await tester.pump();
    expect(
      tester.widget<ElevatedButton>(find.byKey(const Key('date_range_sheet_apply_button'))).onPressed,
      isNull,
    );

    await tester.enterText(find.byKey(const Key('date_range_sheet_end_field')), '15012026');
    await tester.pump();
    expect(
      tester.widget<ElevatedButton>(find.byKey(const Key('date_range_sheet_apply_button'))).onPressed,
      isNotNull,
    );
  });

  testWidgets('a valid date shows the green check icon', (tester) async {
    await openSheet(tester);

    expect(find.byKey(const Key('date_range_sheet_start_valid_icon')), findsNothing);

    await tester.enterText(find.byKey(const Key('date_range_sheet_start_field')), '01012026');
    await tester.pump();

    expect(find.byKey(const Key('date_range_sheet_start_valid_icon')), findsOneWidget);
  });

  testWidgets('an invalid complete date shows the validator error text', (tester) async {
    await openSheet(tester);

    await tester.enterText(find.byKey(const Key('date_range_sheet_start_field')), '32132026');
    await tester.pump();

    expect(find.text('Tanggal tidak valid.'), findsOneWidget);
    expect(find.byKey(const Key('date_range_sheet_start_valid_icon')), findsNothing);
  });

  testWidgets('end before start is blocked with a range error and disabled Terapkan', (tester) async {
    await openSheet(tester);

    await tester.enterText(find.byKey(const Key('date_range_sheet_start_field')), '15012026');
    await tester.enterText(find.byKey(const Key('date_range_sheet_end_field')), '01012026');
    await tester.pump();

    expect(find.text('Tanggal akhir harus setelah tanggal mulai.'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byKey(const Key('date_range_sheet_apply_button'))).onPressed,
      isNull,
    );
  });

  testWidgets('tapping the calendar icon opens the native date picker', (tester) async {
    await openSheet(tester);

    await tester.tap(find.byKey(const Key('date_range_sheet_start_calendar_icon')));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets('Batal closes the sheet without returning a range', (tester) async {
    DateTimeRange? result = DateTimeRange(start: DateTime(2020), end: DateTime(2020));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showDateRangePickerSheet(
                  context: context,
                  initialRange: null,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2026, 12, 31),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('date_range_sheet_cancel_button')));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });
}
