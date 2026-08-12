import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:inventaris_toko/data/models/stock_mutation.dart';
import 'package:inventaris_toko/domain/profit_report.dart';
import 'package:inventaris_toko/ui/screens/keuntungan/keuntungan_detail_screen.dart';
import 'package:inventaris_toko/ui/widgets/report_period_filter.dart';
import 'package:isar_community/isar.dart';

import '../../../data/repositories/test_isar.dart';

/// The "Semua" header on Detail Keuntungan: when no range is selected the
/// title is joined by a sub-text naming the real span the total covers, so
/// "Semua" isn't a label without dates.
void main() {
  // The sub-text is formatted with the 'id_ID' locale the app initialises
  // at startup; a test has to initialise it for itself.
  setUpAll(() => initializeDateFormatting('id_ID'));

  late Isar isar;

  StockMutation sale(
    DateTime createdAt, {
    double? sellPriceSnapshot = 5000,
    double? costPriceSnapshot = 3000,
    StockMutationType type = StockMutationType.stockOut,
  }) {
    return StockMutation()
      ..productId = 1
      ..type = type
      ..quantity = 1
      ..stockAfter = 0
      ..sellPriceSnapshot = sellPriceSnapshot
      ..costPriceSnapshot = costPriceSnapshot
      ..createdAt = createdAt;
  }

  /// Opens the throwaway database and seeds it. Every Isar call in a
  /// widget test has to happen inside [WidgetTester.runAsync]: Isar's
  /// async API is driven by the real event loop, which `testWidgets`'
  /// fake-async zone otherwise never lets run (an `await` on it simply
  /// hangs). The same rule is why [settle] exists.
  Future<void> openWith(WidgetTester tester, List<StockMutation> mutations) async {
    await tester.runAsync(() async {
      isar = await openTestIsar();
      if (mutations.isNotEmpty) {
        await isar.writeTxn(() => isar.stockMutations.putAll(mutations));
      }
    });
  }

  /// Lets the screen's in-flight Isar queries actually complete, then
  /// draws the result. The screen holds a 2-second periodic refresh, so
  /// `pumpAndSettle` would never settle; the real work is given a slice of
  /// the real event loop and the resulting frame is produced with pumps.
  Future<void> settle(WidgetTester tester) async {
    // Each hand-off to the real loop advances the screen's chain of awaits
    // by roughly one step (query → product lookup → next query), so this
    // pumps repeatedly rather than waiting once for a guessed duration.
    for (var i = 0; i < 60; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.idle();
      await tester.pump();
    }
  }

  /// Disposes the screen (cancelling its timer and watchLazy subscription)
  /// before closing the database out from under it.
  Future<void> teardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => closeTestIsar(isar));
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: KeuntunganDetailScreen(isar: isar)));
    await settle(tester);
  }

  Finder rangeText() => find.byKey(const Key('keuntungan_all_time_range'));

  String rangeLabel(WidgetTester tester) =>
      tester.widget<Text>(rangeText()).data!;

  testWidgets('"Semua" shows the span from the earliest to the latest sale',
      (tester) async {
    await openWith(tester, [
      sale(DateTime(2026, 1, 3, 9)),
      sale(DateTime(2026, 4, 18, 14)),
      sale(DateTime(2026, 8, 11, 20)),
    ]);

    await pumpScreen(tester);

    expect(find.text('Total Keuntungan Keseluruhan'), findsOneWidget);
    expect(rangeLabel(tester), '3 Jan 2026 - 11 Agu 2026 (Semua)');

    await teardown(tester);
  });

  testWidgets('no qualifying sale: the title stands alone, with no range '
      'sub-text and no error', (tester) async {
    // A restock only — nothing that feeds profit.
    await openWith(tester, [
      sale(DateTime(2026, 5, 5), type: StockMutationType.stockIn),
    ]);

    await pumpScreen(tester);

    expect(find.text('Total Keuntungan Keseluruhan'), findsOneWidget);
    expect(rangeText(), findsNothing);
    expect(find.byKey(const Key('keuntungan_empty_period')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await teardown(tester);
  });

  testWidgets('an entirely empty ledger renders without a range sub-text',
      (tester) async {
    await openWith(tester, []);

    await pumpScreen(tester);

    expect(find.text('Total Keuntungan Keseluruhan'), findsOneWidget);
    expect(rangeText(), findsNothing);
    expect(tester.takeException(), isNull);

    await teardown(tester);
  });

  testWidgets('exactly one sale collapses to a single date', (tester) async {
    await openWith(tester, [sale(DateTime(2026, 1, 3, 10, 15))]);

    await pumpScreen(tester);

    expect(rangeLabel(tester), '3 Jan 2026 (Semua)');

    await teardown(tester);
  });

  testWidgets('a span crossing new year shows both years', (tester) async {
    await openWith(tester, [
      sale(DateTime(2025, 12, 28, 19)),
      sale(DateTime(2026, 1, 5, 11)),
    ]);

    await pumpScreen(tester);

    expect(rangeLabel(tester), '28 Des 2025 - 5 Jan 2026 (Semua)');

    await teardown(tester);
  });

  testWidgets('a sale a millisecond before local midnight is labelled with '
      'its own local date', (tester) async {
    // 31 Dec 23:59:59.999 local is already 1 Jan in UTC across Indonesia.
    // The label must follow the shop's local day, exactly like the day
    // boundaries the rest of the screen groups by.
    await openWith(tester, [
      sale(DateTime(2025, 12, 31, 23, 59, 59, 999)),
      sale(DateTime(2026, 1, 1, 0, 0, 0, 1)),
    ]);

    await pumpScreen(tester);

    expect(rangeLabel(tester), '31 Des 2025 - 1 Jan 2026 (Semua)');

    await teardown(tester);
  });

  testWidgets('selecting a specific range leaves the header unchanged: the '
      'title carries the range and no sub-text appears', (tester) async {
    await openWith(tester, [
      sale(DateTime(2026, 1, 3, 9)),
      sale(DateTime(2026, 4, 18, 14)),
      sale(DateTime(2026, 8, 11, 20)),
    ]);

    await pumpScreen(tester);
    expect(rangeText(), findsOneWidget);

    // Drives the screen's own onChanged — the exact callback the picker
    // sheet fires — rather than re-enacting the picker's UI.
    tester.widget<ReportPeriodFilter>(find.byType(ReportPeriodFilter)).onChanged(
          ReportPeriod.days(
            DateTime(2026, 4, 1),
            DateTime(2026, 4, 30),
            today: DateTime(2026, 8, 11),
          ),
        );
    await settle(tester);

    expect(find.text('Total Keuntungan 1 Apr 2026 - 30 Apr 2026'), findsOneWidget);
    expect(rangeText(), findsNothing);

    // And returning to "Semua" brings the span back.
    tester.widget<ReportPeriodFilter>(find.byType(ReportPeriodFilter)).onChanged(
          const ReportPeriod.allTime(),
        );
    await settle(tester);

    expect(rangeLabel(tester), '3 Jan 2026 - 11 Agu 2026 (Semua)');

    await teardown(tester);
  });
}
