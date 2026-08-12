import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/models/stock_mutation.dart';
import 'package:inventaris_toko/data/repositories/stock_mutation_repository.dart';
import 'package:isar_community/isar.dart';

import 'test_isar.dart';

/// Covers [StockMutationRepository.getProfitableStockOutDateRange] — the
/// span behind the "Semua" label on Detail Keuntungan. The contract under
/// test is that the range is built from *exactly* the rows the profit
/// calculation counts, never a superset.
void main() {
  late Isar isar;
  late StockMutationRepository repository;

  setUp(() async {
    isar = await openTestIsar();
    repository = StockMutationRepository(isar);
  });

  tearDown(() async => closeTestIsar(isar));

  /// Writes a mutation directly, so its `createdAt` can be an arbitrary
  /// past date (recordMutation always stamps `DateTime.now()`). Snapshots
  /// default to a resolvable pair, which is what makes a row count toward
  /// profit; pass nulls for both to simulate a row profit can't value.
  Future<void> seedMutation({
    required DateTime createdAt,
    StockMutationType type = StockMutationType.stockOut,
    double quantity = 1,
    double? sellPriceSnapshot = 5000,
    double? costPriceSnapshot = 3000,
    int productId = 1,
  }) async {
    final mutation = StockMutation()
      ..productId = productId
      ..type = type
      ..quantity = quantity
      ..stockAfter = 0
      ..sellPriceSnapshot = sellPriceSnapshot
      ..costPriceSnapshot = costPriceSnapshot
      ..createdAt = createdAt;
    await isar.writeTxn(() => isar.stockMutations.put(mutation));
  }

  test('resolves the earliest and latest qualifying sale', () async {
    await seedMutation(createdAt: DateTime(2026, 3, 14, 9, 30));
    await seedMutation(createdAt: DateTime(2026, 1, 3, 8));
    await seedMutation(createdAt: DateTime(2026, 8, 11, 17, 45));
    await seedMutation(createdAt: DateTime(2026, 5, 2, 12));

    final range = await repository.getProfitableStockOutDateRange();

    expect(range, isNotNull);
    expect(range!.earliest, DateTime(2026, 1, 3, 8));
    expect(range.latest, DateTime(2026, 8, 11, 17, 45));
  });

  test('ignores stockIn mutations at both ends', () async {
    // Restocks bracket the sales on both sides; neither may define the
    // range, because neither contributes to profit.
    await seedMutation(
      createdAt: DateTime(2025, 12, 1),
      type: StockMutationType.stockIn,
    );
    await seedMutation(createdAt: DateTime(2026, 2, 4));
    await seedMutation(createdAt: DateTime(2026, 6, 9));
    await seedMutation(
      createdAt: DateTime(2026, 9, 30),
      type: StockMutationType.stockIn,
    );

    final range = await repository.getProfitableStockOutDateRange();

    expect(range!.earliest, DateTime(2026, 2, 4));
    expect(range.latest, DateTime(2026, 6, 9));
  });

  test('ignores stock-outs whose price cannot be resolved, so the range '
      'never starts before the profit total does', () async {
    // No snapshots and no product row: MutationPricing resolves neither
    // price, calculateProfitByDate skips it, and so must this.
    await seedMutation(
      createdAt: DateTime(2025, 11, 5),
      sellPriceSnapshot: null,
      costPriceSnapshot: null,
      productId: 999,
    );
    await seedMutation(
      createdAt: DateTime(2026, 12, 25),
      sellPriceSnapshot: null,
      costPriceSnapshot: null,
      productId: 999,
    );
    await seedMutation(createdAt: DateTime(2026, 4, 1));
    await seedMutation(createdAt: DateTime(2026, 7, 20));

    final range = await repository.getProfitableStockOutDateRange();

    expect(range!.earliest, DateTime(2026, 4, 1));
    expect(range.latest, DateTime(2026, 7, 20));

    // The stated invariant, checked against the profit calculation itself
    // rather than restated: both ends appear as dates in the profit map.
    final profitByDate = await repository.calculateProfitByDate();
    expect(profitByDate.keys, contains(DateTime(2026, 4, 1)));
    expect(profitByDate.keys, contains(DateTime(2026, 7, 20)));
  });

  test('returns null when no sale qualifies', () async {
    final empty = await repository.getProfitableStockOutDateRange();
    expect(empty, isNull);

    // A ledger holding only restocks is still "no sales".
    await seedMutation(
      createdAt: DateTime(2026, 5, 5),
      type: StockMutationType.stockIn,
    );
    expect(await repository.getProfitableStockOutDateRange(), isNull);
  });

  test('a single qualifying sale yields earliest == latest', () async {
    await seedMutation(createdAt: DateTime(2026, 1, 3, 10, 15));

    final range = await repository.getProfitableStockOutDateRange();

    expect(range!.earliest, DateTime(2026, 1, 3, 10, 15));
    expect(range.latest, range.earliest);
  });

  test('a sale just before local midnight keeps its own local date', () async {
    // 23:59:59.999 local on 31 Dec is a different *UTC* date in most of
    // Indonesia (UTC+7/8/9). It must still report as 31 Dec local, and
    // must group under the same local day the profit calculation uses.
    final nearMidnight = DateTime(2025, 12, 31, 23, 59, 59, 999);
    await seedMutation(createdAt: nearMidnight);
    await seedMutation(createdAt: DateTime(2026, 1, 1, 0, 0, 0, 1));

    final range = await repository.getProfitableStockOutDateRange();

    expect(range!.earliest, nearMidnight);
    expect(range.earliest.year, 2025);
    expect(range.earliest.month, 12);
    expect(range.earliest.day, 31);
    expect(range.earliest.isUtc, isFalse);

    // The same local-day boundary the screen groups by.
    final profitByDate = await repository.calculateProfitByDate();
    expect(profitByDate.keys, contains(DateTime(2025, 12, 31)));
    expect(profitByDate.keys, contains(DateTime(2026, 1, 1)));
  });

  test('scans past a full page of unqualifying rows at each end', () async {
    // More unresolvable rows than the internal page size, to prove the
    // scan pages forward instead of giving up after one batch.
    for (var i = 0; i < 120; i++) {
      await seedMutation(
        createdAt: DateTime(2025, 1, 1).add(Duration(minutes: i)),
        sellPriceSnapshot: null,
        costPriceSnapshot: null,
        productId: 999,
      );
      await seedMutation(
        createdAt: DateTime(2027, 1, 1).add(Duration(minutes: i)),
        sellPriceSnapshot: null,
        costPriceSnapshot: null,
        productId: 999,
      );
    }
    await seedMutation(createdAt: DateTime(2026, 6, 1));
    await seedMutation(createdAt: DateTime(2026, 6, 30));

    final range = await repository.getProfitableStockOutDateRange();

    expect(range!.earliest, DateTime(2026, 6, 1));
    expect(range.latest, DateTime(2026, 6, 30));
  });
}
