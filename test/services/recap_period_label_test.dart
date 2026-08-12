import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:inventaris_toko/data/models/stock_mutation.dart';
import 'package:inventaris_toko/data/repositories/stock_mutation_repository.dart';
import 'package:inventaris_toko/domain/profit_report.dart';
import 'package:inventaris_toko/services/recap_pdf_builder.dart';
import 'package:isar_community/isar.dart';

import '../data/repositories/test_isar.dart';

/// Covers the PDF header's period line: that "Semua" is resolved into a
/// real date range (earliest mutation .. today) instead of the
/// informationless "Semua Periode", that an empty ledger says so honestly
/// rather than fabricating a date, and that a *selected* range is printed
/// exactly as chosen and never overridden by the earliest-mutation lookup.
void main() {
  late Isar isar;
  late StockMutationRepository mutationRepository;

  setUpAll(() async {
    // DateFormat('d MMM yyyy', 'id_ID') needs Indonesian locale symbols.
    await initializeDateFormatting('id_ID');
  });

  setUp(() async {
    isar = await openTestIsar();
    mutationRepository = StockMutationRepository(isar);
  });

  tearDown(() async {
    await closeTestIsar(isar);
  });

  /// Writes a mutation directly so the test owns `createdAt` — the
  /// repository always stamps `DateTime.now()`.
  Future<void> mutationAt(DateTime createdAt) async {
    final mutation = StockMutation()
      ..productId = 1
      ..type = StockMutationType.stockOut
      ..quantity = 1
      ..stockAfter = 0
      ..sellPriceSnapshot = 3000
      ..costPriceSnapshot = 2000
      ..snapshotBackfilled = false
      ..createdAt = createdAt;
    await isar.writeTxn(() => isar.stockMutations.put(mutation));
  }

  group('getEarliestMutationDate', () {
    test('returns the oldest createdAt regardless of insertion order', () async {
      // Inserted newest-first on purpose: the answer must come from the
      // createdAt index, not from row order.
      await mutationAt(DateTime(2026, 7, 20, 9));
      await mutationAt(DateTime(2004, 11, 2, 21, 45));
      await mutationAt(DateTime(2020, 1, 15, 12));

      expect(
        await mutationRepository.getEarliestMutationDate(),
        DateTime(2004, 11, 2, 21, 45),
      );
    });

    test('returns null on an empty ledger', () async {
      expect(await mutationRepository.getEarliestMutationDate(), isNull);
    });
  });

  group('recapPeriodLabel — all time', () {
    test('resolves to earliest mutation day .. today', () async {
      await mutationAt(DateTime(2004, 11, 2, 21, 45));
      await mutationAt(DateTime(2026, 7, 20, 9));

      final earliest = await mutationRepository.getEarliestMutationDate();
      final label = recapPeriodLabel(
        const ReportPeriod.allTime(),
        earliestMutationAt: earliest,
        today: DateTime(2026, 7, 25, 16, 30),
      );

      // The evening time-of-day on the earliest mutation is reduced to its
      // own local calendar day, not rolled forward.
      expect(label, '2 Nov 2004 - 25 Jul 2026');
    });

    test('empty database prints the no-transaction period, no crash', () async {
      final earliest = await mutationRepository.getEarliestMutationDate();
      expect(earliest, isNull);

      final label = recapPeriodLabel(
        const ReportPeriod.allTime(),
        earliestMutationAt: earliest,
        today: DateTime(2026, 7, 25),
      );

      expect(label, kRecapNoTransactionsPeriod);
      expect(label, 'Belum ada transaksi');
    });

    test('a single mutation today collapses to one date', () async {
      await mutationAt(DateTime(2026, 7, 25, 8, 15));

      final label = recapPeriodLabel(
        const ReportPeriod.allTime(),
        earliestMutationAt: await mutationRepository.getEarliestMutationDate(),
        today: DateTime(2026, 7, 25, 19, 0),
      );

      expect(label, '25 Jul 2026');
    });

    test('a single old mutation still spans through today', () async {
      await mutationAt(DateTime(2026, 7, 1, 10));

      final label = recapPeriodLabel(
        const ReportPeriod.allTime(),
        earliestMutationAt: await mutationRepository.getEarliestMutationDate(),
        today: DateTime(2026, 7, 25),
      );

      expect(label, '1 Jul 2026 - 25 Jul 2026');
    });
  });

  group('recapPeriodLabel — selected range', () {
    test('prints the selected range unchanged, ignoring the earliest lookup',
        () async {
      await mutationAt(DateTime(2004, 11, 2));

      final period = ReportPeriod.days(
        DateTime(2026, 7, 10),
        DateTime(2026, 7, 12),
        today: DateTime(2026, 7, 25),
      );

      // Even when an earliest date is supplied, a bounded period must not
      // be widened by it.
      expect(
        recapPeriodLabel(
          period,
          earliestMutationAt: await mutationRepository.getEarliestMutationDate(),
          today: DateTime(2026, 7, 25),
        ),
        '10 Jul 2026 - 12 Jul 2026',
      );
    });

    test('a single-day selection collapses to one date', () {
      final period = ReportPeriod.days(
        DateTime(2026, 7, 12),
        DateTime(2026, 7, 12),
        today: DateTime(2026, 7, 25),
      );

      expect(
        recapPeriodLabel(
          period,
          earliestMutationAt: DateTime(2004, 11, 2),
          today: DateTime(2026, 7, 25),
        ),
        '12 Jul 2026',
      );
    });
  });
}
