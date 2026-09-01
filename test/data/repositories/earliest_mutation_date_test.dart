import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/models/stock_mutation.dart';
import 'package:inventaris_toko/data/repositories/stock_mutation_repository.dart';
import 'package:isar_community/isar.dart';

import 'test_isar.dart';

/// Covers [StockMutationRepository.getEarliestMutationDate] — the lower
/// bound the Mutasi tab and Riwayat per produk hand to their date
/// filters. The contract is the minimum `createdAt` in the whole ledger,
/// or null when there is nothing to bound.
void main() {
  late Isar isar;
  late StockMutationRepository repository;

  setUp(() async {
    isar = await openTestIsar();
    repository = StockMutationRepository(isar);
  });

  tearDown(() async => closeTestIsar(isar));

  /// Writes a mutation directly so `createdAt` can be an arbitrary past
  /// date — recordMutation always stamps `DateTime.now()`.
  Future<void> seedMutation(DateTime createdAt, {int productId = 1}) async {
    final mutation = StockMutation()
      ..productId = productId
      ..type = StockMutationType.stockOut
      ..quantity = 1
      ..stockAfter = 0
      ..createdAt = createdAt;
    await isar.writeTxn(() => isar.stockMutations.put(mutation));
  }

  test('an empty ledger has no bound', () async {
    expect(await repository.getEarliestMutationDate(), isNull);
  });

  test('a single mutation is its own bound', () async {
    await seedMutation(DateTime(2023, 4, 17, 9, 30));
    expect(await repository.getEarliestMutationDate(), DateTime(2023, 4, 17, 9, 30));
  });

  test('several mutations resolve to the minimum, not the first written', () async {
    // Deliberately inserted out of order, and spread across products, so
    // neither insertion order nor a per-product scope could pass this.
    await seedMutation(DateTime(2025, 6, 1));
    await seedMutation(DateTime(2022, 1, 9, 14), productId: 2);
    await seedMutation(DateTime(2026, 2, 28));
    await seedMutation(DateTime(2024, 11, 3), productId: 3);

    expect(await repository.getEarliestMutationDate(), DateTime(2022, 1, 9, 14));
  });

  test('the bound is a local DateTime, matching how the filters compare', () async {
    final nearMidnight = DateTime(2025, 12, 31, 23, 45);
    await seedMutation(nearMidnight);

    final earliest = await repository.getEarliestMutationDate();
    expect(earliest, nearMidnight);
    expect(earliest!.isUtc, isFalse);
    expect(earliest.day, 31);
  });
}
