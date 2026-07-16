import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/ui/widgets/time_picker_sheet.dart';

void main() {
  TimeOfDay? result;
  var resultCaptured = false;

  Future<void> pumpSheet(WidgetTester tester, {required TimeOfDay initialTime}) async {
    result = null;
    resultCaptured = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  final picked = await TimePickerSheet.show(context, initialTime: initialTime);
                  result = picked;
                  resultCaptured = true;
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('defaults to scroll wheel mode', (tester) async {
    await pumpSheet(tester, initialTime: const TimeOfDay(hour: 20, minute: 0));

    expect(find.byKey(const Key('time_picker_sheet_scroll')), findsOneWidget);
    expect(find.byKey(const Key('time_picker_sheet_hour_field')), findsNothing);
    expect(find.byKey(const Key('time_picker_sheet_minute_field')), findsNothing);
    expect(find.text('Ketik manual'), findsOneWidget);
  });

  testWidgets('tapping OK in scroll mode without scrolling returns the initial time', (tester) async {
    await pumpSheet(tester, initialTime: const TimeOfDay(hour: 20, minute: 15));

    await tester.tap(find.byKey(const Key('time_picker_sheet_ok')));
    await tester.pumpAndSettle();

    expect(resultCaptured, isTrue);
    expect(result, const TimeOfDay(hour: 20, minute: 15));
  });

  testWidgets('toggle switches to manual mode pre-filled with the current time', (tester) async {
    await pumpSheet(tester, initialTime: const TimeOfDay(hour: 7, minute: 5));

    await tester.tap(find.byKey(const Key('time_picker_sheet_mode_toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('time_picker_sheet_scroll')), findsNothing);
    expect(find.byKey(const Key('time_picker_sheet_hour_field')), findsOneWidget);
    expect(find.byKey(const Key('time_picker_sheet_minute_field')), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(const Key('time_picker_sheet_hour_field'))).controller!.text,
      '07',
    );
    expect(
      tester.widget<TextField>(find.byKey(const Key('time_picker_sheet_minute_field'))).controller!.text,
      '05',
    );
    expect(find.text('Gunakan scroll'), findsOneWidget);
  });

  testWidgets('entering a valid manual time and tapping OK returns that time', (tester) async {
    await pumpSheet(tester, initialTime: const TimeOfDay(hour: 20, minute: 0));

    await tester.tap(find.byKey(const Key('time_picker_sheet_mode_toggle')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('time_picker_sheet_hour_field')), '6');
    await tester.enterText(find.byKey(const Key('time_picker_sheet_minute_field')), '45');
    await tester.tap(find.byKey(const Key('time_picker_sheet_ok')));
    await tester.pumpAndSettle();

    expect(resultCaptured, isTrue);
    expect(result, const TimeOfDay(hour: 6, minute: 45));
  });

  testWidgets('invalid manual hour shows an inline error and does not close the sheet', (tester) async {
    await pumpSheet(tester, initialTime: const TimeOfDay(hour: 20, minute: 0));

    await tester.tap(find.byKey(const Key('time_picker_sheet_mode_toggle')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('time_picker_sheet_hour_field')), '99');
    await tester.tap(find.byKey(const Key('time_picker_sheet_ok')));
    await tester.pumpAndSettle();

    expect(find.text('Jam 0-23, menit 0-59'), findsOneWidget);
    expect(resultCaptured, isFalse);
    expect(find.byKey(const Key('time_picker_sheet_hour_field')), findsOneWidget);
  });

  testWidgets('switching manual -> scroll -> OK carries over a valid manual edit', (tester) async {
    await pumpSheet(tester, initialTime: const TimeOfDay(hour: 20, minute: 0));

    await tester.tap(find.byKey(const Key('time_picker_sheet_mode_toggle')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('time_picker_sheet_hour_field')), '14');
    await tester.enterText(find.byKey(const Key('time_picker_sheet_minute_field')), '30');

    // Back to scroll mode without touching the wheel itself.
    await tester.tap(find.byKey(const Key('time_picker_sheet_mode_toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('time_picker_sheet_scroll')), findsOneWidget);

    await tester.tap(find.byKey(const Key('time_picker_sheet_ok')));
    await tester.pumpAndSettle();

    expect(result, const TimeOfDay(hour: 14, minute: 30));
  });

  testWidgets('Batal dismisses without a result', (tester) async {
    await pumpSheet(tester, initialTime: const TimeOfDay(hour: 20, minute: 0));

    await tester.tap(find.byKey(const Key('time_picker_sheet_cancel')));
    await tester.pumpAndSettle();

    expect(resultCaptured, isTrue);
    expect(result, isNull);
  });
}
