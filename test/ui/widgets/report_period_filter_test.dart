import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:inventaris_toko/domain/profit_report.dart';
import 'package:inventaris_toko/ui/widgets/report_period_filter.dart';

void main() {
  // formatReportPeriod renders dates with the 'id_ID' locale, which the
  // app initialises at startup and a test must initialise for itself.
  setUpAll(() => initializeDateFormatting('id_ID'));

  Widget host({
    required ReportPeriod period,
    required ValueChanged<ReportPeriod> onChanged,
    String keyPrefix = 'report_period',
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ReportPeriodFilter(
          keyPrefix: keyPrefix,
          period: period,
          onChanged: onChanged,
        ),
      ),
    );
  }

  group('ReportPeriodFilter', () {
    testWidgets('all-time is a distinct state: no clear button, prompt label',
        (tester) async {
      await tester.pumpWidget(
        host(period: const ReportPeriod.allTime(), onChanged: (_) {}),
      );

      expect(find.text('Pilih Tanggal Range'), findsOneWidget);
      expect(find.byKey(const Key('report_period_clear_range_button')), findsNothing);
    });

    testWidgets('a bounded period shows its label and a "Semua" button that '
        'returns to all-time', (tester) async {
      ReportPeriod? applied;
      await tester.pumpWidget(
        host(
          period: ReportPeriod.days(
            DateTime(2026, 7, 1),
            DateTime(2026, 7, 21),
            today: DateTime(2026, 7, 25),
          ),
          onChanged: (period) => applied = period,
        ),
      );

      expect(find.text('1 Jul 2026 - 21 Jul 2026'), findsOneWidget);

      await tester.tap(find.byKey(const Key('report_period_clear_range_button')));
      await tester.pump();

      expect(applied, const ReportPeriod.allTime());
    });

    testWidgets('keyPrefix scopes the button keys per screen', (tester) async {
      await tester.pumpWidget(
        host(
          period: const ReportPeriod.allTime(),
          onChanged: (_) {},
          keyPrefix: 'recap_period',
        ),
      );

      expect(find.byKey(const Key('recap_period_pick_range_button')), findsOneWidget);
    });
  });

  group('inverted range', () {
    test('ReportPeriod.days rejects an end day before the start day, so the '
        'filter can surface the warning instead of silently swapping', () {
      expect(
        () => ReportPeriod.days(
          DateTime(2026, 7, 22),
          DateTime(2026, 7, 21),
          today: DateTime(2026, 7, 25),
        ),
        throwsArgumentError,
      );
    });

    test('the warning is in Indonesian and names both bounds', () {
      expect(kInvertedRangeWarning, 'Tanggal mulai tidak boleh setelah tanggal akhir');
    });
  });

  group('formatReportPeriod', () {
    test('all-time reads "Semua"', () {
      expect(formatReportPeriod(const ReportPeriod.allTime()), 'Semua');
    });

    test('a single-day period is not rendered as "x - x"', () {
      final period = ReportPeriod.days(
        DateTime(2026, 7, 21),
        DateTime(2026, 7, 21),
        today: DateTime(2026, 7, 25),
      );
      expect(formatReportPeriod(period), '21 Jul 2026');
    });
  });
}
