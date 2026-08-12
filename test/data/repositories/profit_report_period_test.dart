import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/models/product.dart';
import 'package:inventaris_toko/data/models/stock_mutation.dart';
import 'package:inventaris_toko/data/repositories/app_settings_repository.dart';
import 'package:inventaris_toko/data/repositories/product_repository.dart';
import 'package:inventaris_toko/data/repositories/stock_mutation_repository.dart';
import 'package:inventaris_toko/domain/profit_report.dart';
import 'package:isar_community/isar.dart';

import 'test_isar.dart';

/// Covers the date-range half of the profit report: that the selected
/// period actually reaches the query, that its boundaries include the
/// whole of the first and last day, and that two different periods over
/// the same ledger produce different numbers — the direct regression test
/// for "the filter does nothing".
void main() {
  late Isar isar;
  late ProductRepository productRepository;
  late StockMutationRepository mutationRepository;

  setUp(() async {
    isar = await openTestIsar();
    mutationRepository = StockMutationRepository(isar);
    productRepository = ProductRepository(
      isar,
      mutationRepository,
      AppSettingsRepository(isar),
    );
  });

  tearDown(() async {
    await closeTestIsar(isar);
  });

  Future<Product> createProduct({
    String name = 'Chips',
    double sellPrice = 3000,
    double costPrice = 2000,
  }) async {
    return productRepository.create(
      name: name,
      sellPrice: sellPrice,
      unit: 'pcs',
      initialStock: 1000,
      averageCostPrice: costPrice,
    );
  }

  /// Writes a stock-out directly, so the test controls `createdAt` — the
  /// repository always stamps `DateTime.now()`, which can't express "23:59
  /// on the end date". Snapshots are set exactly as `recordMutation` would,
  /// so the rows are indistinguishable from real ones.
  Future<StockMutation> sellAt(
    Product product,
    DateTime createdAt, {
    double quantity = 1,
    double? sellPriceSnapshot,
    double? costPriceSnapshot,
    bool snapshotless = false,
  }) async {
    final mutation = StockMutation()
      ..productId = product.id
      ..type = StockMutationType.stockOut
      ..quantity = quantity
      ..stockAfter = 0
      ..sellPriceSnapshot = snapshotless ? null : (sellPriceSnapshot ?? product.sellPrice)
      ..costPriceSnapshot =
          snapshotless ? null : (costPriceSnapshot ?? product.averageCostPrice)
      ..snapshotBackfilled = false
      ..createdAt = createdAt;

    await isar.writeTxn(() => isar.stockMutations.put(mutation));
    return mutation;
  }

  group('ReportPeriod boundaries', () {
    test('start boundary is local midnight, end boundary is next midnight', () {
      final period = ReportPeriod.days(
        DateTime(2026, 7, 10, 14, 37),
        DateTime(2026, 7, 12, 9, 5),
        today: DateTime(2026, 7, 24),
      );

      // Time-of-day on the inputs is discarded: whole days, either way.
      expect(period.startInclusive, DateTime(2026, 7, 10));
      expect(period.endExclusive, DateTime(2026, 7, 13));
      expect(period.endInclusive, DateTime(2026, 7, 12, 23, 59, 59, 999));
      expect(period.isAllTime, isFalse);
    });

    test('allTime carries no bounds at all, distinct from a wide range', () {
      const period = ReportPeriod.allTime();
      expect(period.isAllTime, isTrue);
      expect(period.startInclusive, isNull);
      expect(period.endExclusive, isNull);
      expect(period.contains(DateTime(1990)), isTrue);
      expect(period.contains(DateTime(2999)), isTrue);
    });

    test('end before start is rejected', () {
      expect(
        () => ReportPeriod.days(
          DateTime(2026, 8, 1),
          DateTime(2026, 7, 24),
          today: DateTime(2026, 8, 2),
        ),
        throwsArgumentError,
      );
    });

    test('a future end date is clamped to today', () {
      final period = ReportPeriod.days(
        DateTime(2026, 7, 1),
        DateTime(2027, 1, 1),
        today: DateTime(2026, 7, 24, 10, 0),
      );
      expect(period.endDay, DateTime(2026, 7, 24));
      expect(period.endExclusive, DateTime(2026, 7, 25));
    });
  });

  group('range filtering', () {
    late Product product;

    setUp(() async {
      product = await createProduct();
    });

    test('a mutation at 23:59:59.999 on the end date is included', () async {
      await sellAt(product, DateTime(2026, 7, 12, 23, 59, 59, 999));

      final report = await mutationRepository.buildProfitReport(
        ReportPeriod.days(
          DateTime(2026, 7, 10),
          DateTime(2026, 7, 12),
          today: DateTime(2026, 7, 24),
        ),
      );

      expect(report.isEmpty, isFalse);
      expect(report.totalProfit, 1000);
    });

    test('a mutation at 00:00:00.000 on the start date is included', () async {
      await sellAt(product, DateTime(2026, 7, 10));

      final report = await mutationRepository.buildProfitReport(
        ReportPeriod.days(
          DateTime(2026, 7, 10),
          DateTime(2026, 7, 12),
          today: DateTime(2026, 7, 24),
        ),
      );

      expect(report.totalProfit, 1000);
    });

    test('one millisecond outside either boundary is excluded', () async {
      // 23:59:59.999 on the day *before* the range starts.
      await sellAt(product, DateTime(2026, 7, 9, 23, 59, 59, 999));
      // Midnight on the day *after* the range ends.
      await sellAt(product, DateTime(2026, 7, 13));

      final period = ReportPeriod.days(
        DateTime(2026, 7, 10),
        DateTime(2026, 7, 12),
        today: DateTime(2026, 7, 24),
      );
      final report = await mutationRepository.buildProfitReport(period);

      expect(report.isEmpty, isTrue);
      expect(report.totalProfit, 0);
      expect(await mutationRepository.getStockOutMutationsInPeriod(period), isEmpty);
    });

    test('a single-day range returns exactly that day and no other', () async {
      await sellAt(product, DateTime(2026, 7, 10, 23, 59, 59, 999), quantity: 5);
      await sellAt(product, DateTime(2026, 7, 11), quantity: 7);
      await sellAt(product, DateTime(2026, 7, 11, 12), quantity: 3);
      await sellAt(product, DateTime(2026, 7, 12), quantity: 9);

      final report = await mutationRepository.buildProfitReport(
        ReportPeriod.days(
          DateTime(2026, 7, 11),
          DateTime(2026, 7, 11),
          today: DateTime(2026, 7, 24),
        ),
      );

      expect(report.lines.single.quantitySold, 10);
      expect(report.totalProfit, 10 * 1000);
    });
  });

  group('aggregation', () {
    test('totals equal the sum of the individual rows in the range', () async {
      final product = await createProduct(sellPrice: 5000, costPrice: 3000);

      await sellAt(product, DateTime(2026, 7, 10), quantity: 2);
      await sellAt(product, DateTime(2026, 7, 11), quantity: 3);
      await sellAt(product, DateTime(2026, 7, 12), quantity: 4);
      await sellAt(product, DateTime(2026, 7, 20), quantity: 100); // outside

      final period = ReportPeriod.days(
        DateTime(2026, 7, 10),
        DateTime(2026, 7, 12),
        today: DateTime(2026, 7, 24),
      );
      final report = await mutationRepository.buildProfitReport(period);
      final rows = await mutationRepository.getStockOutMutationsInPeriod(period);

      final expectedQty = rows.fold<double>(0, (sum, m) => sum + m.quantity);
      expect(expectedQty, 9);
      expect(report.totalRevenue, expectedQty * 5000);
      expect(report.totalCost, expectedQty * 3000);
      expect(report.totalProfit, expectedQty * 2000);
      expect(report.totalProfit, report.totalRevenue - report.totalCost);
    });

    test(
      'two non-overlapping ranges over the same data give different totals',
      () async {
        final product = await createProduct(sellPrice: 5000, costPrice: 3000);

        await sellAt(product, DateTime(2026, 7, 5), quantity: 2);
        await sellAt(product, DateTime(2026, 7, 6), quantity: 1);
        await sellAt(product, DateTime(2026, 7, 20), quantity: 10);

        final first = await mutationRepository.buildProfitReport(
          ReportPeriod.days(
            DateTime(2026, 7, 1),
            DateTime(2026, 7, 10),
            today: DateTime(2026, 7, 24),
          ),
        );
        final second = await mutationRepository.buildProfitReport(
          ReportPeriod.days(
            DateTime(2026, 7, 11),
            DateTime(2026, 7, 24),
            today: DateTime(2026, 7, 24),
          ),
        );
        final all = await mutationRepository.buildProfitReport(
          const ReportPeriod.allTime(),
        );

        expect(first.totalProfit, 3 * 2000);
        expect(second.totalProfit, 10 * 2000);
        expect(first.totalProfit, isNot(second.totalProfit));
        // The whole point: neither range equals all-time.
        expect(all.totalProfit, first.totalProfit + second.totalProfit);
        expect(first.totalProfit, isNot(all.totalProfit));
        expect(second.totalProfit, isNot(all.totalProfit));
      },
    );

    test('profit uses snapshots and survives a later price change', () async {
      final product = await createProduct(sellPrice: 5000, costPrice: 3000);
      await sellAt(product, DateTime(2026, 7, 11), quantity: 4);

      final period = ReportPeriod.days(
        DateTime(2026, 7, 11),
        DateTime(2026, 7, 11),
        today: DateTime(2026, 7, 24),
      );
      final before = await mutationRepository.buildProfitReport(period);
      expect(before.totalProfit, 4 * 2000);

      await productRepository.update(id: product.id, sellPrice: 99000);

      final after = await mutationRepository.buildProfitReport(period);
      expect(after.totalProfit, before.totalProfit);
      expect(after.totalRevenue, before.totalRevenue);
    });

    test('products with zero sales in range are excluded from the list', () async {
      final sold = await createProduct(name: 'Terjual');
      await createProduct(name: 'Tidak Terjual');

      await sellAt(sold, DateTime(2026, 7, 11));

      final report = await mutationRepository.buildProfitReport(
        ReportPeriod.days(
          DateTime(2026, 7, 11),
          DateTime(2026, 7, 11),
          today: DateTime(2026, 7, 24),
        ),
      );

      // "Total Produk" counts products actually sold in the period, not
      // the catalogue — the catalogue here has two products.
      expect(report.productsSold, 1);
      expect(report.lines.single.name, 'Terjual');
      expect(await isar.products.count(), 2);
    });

    test('a deleted product keeps its in-range sales, valued by snapshot', () async {
      final product = await createProduct(sellPrice: 5000, costPrice: 3000);
      await sellAt(product, DateTime(2026, 7, 11), quantity: 2);
      await isar.writeTxn(() => isar.products.delete(product.id));

      final report = await mutationRepository.buildProfitReport(
        ReportPeriod.days(
          DateTime(2026, 7, 11),
          DateTime(2026, 7, 11),
          today: DateTime(2026, 7, 24),
        ),
      );

      expect(report.totalProfit, 2 * 2000);
      expect(report.lines.single.name, contains('terhapus'));
    });

    test('a snapshotless mutation falls back to the product without throwing', () async {
      final product = await createProduct(sellPrice: 5000, costPrice: 3000);
      await sellAt(product, DateTime(2026, 7, 11), quantity: 2, snapshotless: true);

      final report = await mutationRepository.buildProfitReport(
        ReportPeriod.days(
          DateTime(2026, 7, 11),
          DateTime(2026, 7, 11),
          today: DateTime(2026, 7, 24),
        ),
      );

      expect(report.totalProfit, 2 * 2000);
    });

    test(
      'a snapshotless mutation whose product is gone is skipped, not fatal',
      () async {
        final product = await createProduct(sellPrice: 5000, costPrice: 3000);
        await sellAt(product, DateTime(2026, 7, 11), snapshotless: true);
        await isar.writeTxn(() => isar.products.delete(product.id));

        final report = await mutationRepository.buildProfitReport(
          ReportPeriod.days(
            DateTime(2026, 7, 11),
            DateTime(2026, 7, 11),
            today: DateTime(2026, 7, 24),
          ),
        );

        expect(report.isEmpty, isTrue);
        expect(report.totalProfit, 0);
      },
    );

    test('stockIn rows never count towards a profit report', () async {
      final product = await createProduct(sellPrice: 5000, costPrice: 3000);
      await sellAt(product, DateTime(2026, 7, 11), quantity: 2);

      final stockIn = StockMutation()
        ..productId = product.id
        ..type = StockMutationType.stockIn
        ..quantity = 500
        ..stockAfter = 0
        ..sellPriceSnapshot = 5000
        ..costPriceSnapshot = 3000
        ..snapshotBackfilled = false
        ..createdAt = DateTime(2026, 7, 11, 8);
      await isar.writeTxn(() => isar.stockMutations.put(stockIn));

      final report = await mutationRepository.buildProfitReport(
        ReportPeriod.days(
          DateTime(2026, 7, 11),
          DateTime(2026, 7, 11),
          today: DateTime(2026, 7, 24),
        ),
      );

      expect(report.lines.single.quantitySold, 2);
      expect(report.totalProfit, 2 * 2000);
    });
  });

  group('empty and all-time', () {
    test('a range with no mutations returns an empty report, no throw', () async {
      final product = await createProduct();
      await sellAt(product, DateTime(2026, 7, 11));

      final report = await mutationRepository.buildProfitReport(
        ReportPeriod.days(
          DateTime(2026, 6, 1),
          DateTime(2026, 6, 30),
          today: DateTime(2026, 7, 24),
        ),
      );

      expect(report.isEmpty, isTrue);
      expect(report.lines, isEmpty);
      expect(report.productsSold, 0);
      expect(report.totalRevenue, 0);
      expect(report.totalCost, 0);
      expect(report.totalProfit, 0);
      expect(report.totalQuantitySold, 0);
    });

    test('an entirely empty database returns an empty report', () async {
      final report = await mutationRepository.buildProfitReport(
        const ReportPeriod.allTime(),
      );
      expect(report.isEmpty, isTrue);
      expect(report.totalProfit, 0);
    });

    test('"Semua" returns every row including the oldest', () async {
      final product = await createProduct(sellPrice: 5000, costPrice: 3000);
      await sellAt(product, DateTime(2021, 1, 1), quantity: 1);
      await sellAt(product, DateTime(2026, 7, 11), quantity: 1);

      final all = await mutationRepository.buildProfitReport(
        const ReportPeriod.allTime(),
      );

      expect(all.lines.single.quantitySold, 2);
      expect(all.totalProfit, 2 * 2000);

      // And it is not merely a wide range: a range starting after the
      // oldest row misses it, all-time does not.
      final recent = await mutationRepository.buildProfitReport(
        ReportPeriod.days(
          DateTime(2026, 1, 1),
          DateTime(2026, 7, 24),
          today: DateTime(2026, 7, 24),
        ),
      );
      expect(recent.totalProfit, 1 * 2000);
    });
  });

  group('period-scoped repository aggregates', () {
    test('calculateProfitByDate and calculateTotalProfit honour the period', () async {
      final product = await createProduct(sellPrice: 5000, costPrice: 3000);
      await sellAt(product, DateTime(2026, 7, 5), quantity: 2);
      await sellAt(product, DateTime(2026, 7, 20), quantity: 3);

      final period = ReportPeriod.days(
        DateTime(2026, 7, 1),
        DateTime(2026, 7, 10),
        today: DateTime(2026, 7, 24),
      );

      final scoped = await mutationRepository.calculateProfitByDate(period);
      expect(scoped.keys.single, DateTime(2026, 7, 5));
      expect(await mutationRepository.calculateTotalProfit(period), 2 * 2000);

      // Default argument keeps the existing all-time behaviour intact.
      expect(await mutationRepository.calculateTotalProfit(), 5 * 2000);
      expect((await mutationRepository.calculateProfitByDate()).length, 2);
      expect(
        (await mutationRepository.calculateProfitByMonth(period)).keys.single,
        'Juli 2026',
      );
    });
  });
}
