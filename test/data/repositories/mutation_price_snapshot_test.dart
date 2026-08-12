import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/migrations/mutation_snapshot_backfill.dart';
import 'package:inventaris_toko/data/models/product.dart';
import 'package:inventaris_toko/data/models/stock_mutation.dart';
import 'package:inventaris_toko/data/repositories/app_settings_repository.dart';
import 'package:inventaris_toko/data/repositories/product_repository.dart';
import 'package:inventaris_toko/data/repositories/stock_mutation_repository.dart';
import 'package:inventaris_toko/domain/mutation_pricing.dart';
import 'package:isar_community/isar.dart';

import 'test_isar.dart';

/// Covers the price-snapshot half of the ledger: that every mutation
/// freezes the prices in force at the moment it was written, that
/// [MutationPricing] is the only rule for reading them back, and that the
/// one-time [MutationSnapshotBackfill] fills legacy rows without ever
/// touching rows that already have snapshots.
void main() {
  late Isar isar;
  late ProductRepository productRepository;
  late StockMutationRepository mutationRepository;
  late AppSettingsRepository appSettingsRepository;

  setUp(() async {
    isar = await openTestIsar();
    mutationRepository = StockMutationRepository(isar);
    appSettingsRepository = AppSettingsRepository(isar);
    productRepository = ProductRepository(
      isar,
      mutationRepository,
      appSettingsRepository,
    );
  });

  tearDown(() async {
    await closeTestIsar(isar);
  });

  Future<Product> createProduct({
    String name = 'Chips',
    double sellPrice = 10000,
    double? averageCostPrice,
    double initialStock = 0,
  }) {
    return productRepository.create(
      name: name,
      sellPrice: sellPrice,
      unit: 'pcs',
      averageCostPrice: averageCostPrice,
      initialStock: initialStock,
    );
  }

  group('recordMutation snapshots', () {
    test('stockOut stores the sellPrice and averageCostPrice current at that moment', () async {
      final product = await createProduct(
        sellPrice: 10000,
        averageCostPrice: 6000,
        initialStock: 20,
      );

      final mutation = await mutationRepository.recordMutation(
        productId: product.id,
        type: StockMutationType.stockOut,
        quantity: 5,
      );

      expect(mutation.sellPriceSnapshot, 10000);
      expect(mutation.costPriceSnapshot, 6000);
      expect(mutation.snapshotBackfilled, isFalse);
    });

    test('stockIn stores the POST-recalculation average, not the pre-value', () async {
      // 10 units @ Rp5000 already on hand, 5 more coming in @ Rp8000:
      // the new weighted average is (50000 + 40000) / 15 = 6000.
      final product = await createProduct(
        sellPrice: 12000,
        averageCostPrice: 5000,
        initialStock: 10,
      );

      final mutation = await mutationRepository.recordMutation(
        productId: product.id,
        type: StockMutationType.stockIn,
        quantity: 5,
        costPricePerUnit: 8000,
      );

      expect(mutation.costPriceSnapshot, 6000);
      expect(mutation.costPriceSnapshot, isNot(5000)); // not the pre-value
      expect(mutation.sellPriceSnapshot, 12000);

      // And the product itself agrees — both were written in the same
      // transaction, so they can never disagree.
      final reloaded = await productRepository.getById(product.id);
      expect(reloaded!.averageCostPrice, 6000);
    });

    test('stockIn without a cost price snapshots the unchanged average', () async {
      final product = await createProduct(
        sellPrice: 12000,
        averageCostPrice: 5000,
        initialStock: 10,
      );

      final mutation = await mutationRepository.recordMutation(
        productId: product.id,
        type: StockMutationType.stockIn,
        quantity: 5,
      );

      // No HPP recalculation happened, so the snapshot is simply the
      // average still in force — which is genuinely the cost basis of the
      // stock after this batch, as far as the app knows.
      expect(mutation.costPriceSnapshot, 5000);
      expect((await productRepository.getById(product.id))!.averageCostPrice, 5000);
    });

    test('a null averageCostPrice snapshots null, never 0', () async {
      final product = await createProduct(sellPrice: 10000, initialStock: 20);
      expect(product.averageCostPrice, isNull);

      final mutation = await mutationRepository.recordMutation(
        productId: product.id,
        type: StockMutationType.stockOut,
        quantity: 5,
      );

      expect(mutation.costPriceSnapshot, isNull);
      expect(mutation.sellPriceSnapshot, 10000);
      // "Unknown cost" must not read as "free", which would report the
      // entire sale price as profit.
      expect(MutationPricing.profit(mutation, product), isNull);
    });

    test('changing sellPrice afterwards does NOT alter the stored snapshot', () async {
      final product = await createProduct(
        sellPrice: 10000,
        averageCostPrice: 6000,
        initialStock: 20,
      );

      final mutation = await mutationRepository.recordMutation(
        productId: product.id,
        type: StockMutationType.stockOut,
        quantity: 5,
      );

      await productRepository.update(id: product.id, sellPrice: 25000);

      final stored = await isar.stockMutations.get(mutation.id);
      expect(stored!.sellPriceSnapshot, 10000);
      expect(stored.costPriceSnapshot, 6000);
    });
  });

  group('MutationPricing', () {
    test('uses the snapshot when present, ignoring current product prices', () async {
      final product = await createProduct(
        sellPrice: 10000,
        averageCostPrice: 6000,
        initialStock: 20,
      );
      final mutation = await mutationRepository.recordMutation(
        productId: product.id,
        type: StockMutationType.stockOut,
        quantity: 5,
      );

      final drifted = (await productRepository.getById(product.id))!
        ..sellPrice = 99999
        ..averageCostPrice = 1;

      final prices = MutationPricing.resolve(mutation, drifted);
      expect(prices.sellPrice, 10000);
      expect(prices.costPrice, 6000);
      expect(MutationPricing.profit(mutation, drifted), (10000 - 6000) * 5);
    });

    test('falls back to current product prices when the snapshot is null', () async {
      final product = await createProduct(
        sellPrice: 10000,
        averageCostPrice: 6000,
        initialStock: 20,
      );
      final mutation = await mutationRepository.recordMutation(
        productId: product.id,
        type: StockMutationType.stockOut,
        quantity: 5,
      );

      // Simulates a row written before the snapshot fields existed.
      await isar.writeTxn(() async {
        await isar.stockMutations.put(
          mutation
            ..sellPriceSnapshot = null
            ..costPriceSnapshot = null,
        );
      });

      final legacy = (await isar.stockMutations.get(mutation.id))!;
      final prices = MutationPricing.resolve(
        legacy,
        (await productRepository.getById(product.id))!,
      );
      expect(prices.sellPrice, 10000);
      expect(prices.costPrice, 6000);
    });

    test('does not throw when the product is gone and there is no snapshot', () async {
      final orphan = StockMutation()
        ..productId = 4242
        ..type = StockMutationType.stockOut
        ..quantity = 3
        ..stockAfter = 0
        ..createdAt = DateTime.now();

      final prices = MutationPricing.resolve(orphan, null);
      expect(prices.sellPrice, isNull);
      expect(prices.costPrice, isNull);
      expect(prices.profitFor(3), isNull);
      expect(MutationPricing.profit(orphan, null), isNull);
    });

    test('preserves negative profit when the sell price is below cost', () async {
      final product = await createProduct(
        sellPrice: 4000,
        averageCostPrice: 6000,
        initialStock: 20,
      );
      final mutation = await mutationRepository.recordMutation(
        productId: product.id,
        type: StockMutationType.stockOut,
        quantity: 5,
      );

      expect(MutationPricing.profit(mutation, product), -10000);
      expect(await mutationRepository.calculateTotalProfit(), -10000);
    });

    test('a historical mutation keeps its profit after a later price change', () async {
      // The whole point of the snapshots: profit already booked must not
      // move when today's prices move.
      final product = await createProduct(
        sellPrice: 10000,
        averageCostPrice: 6000,
        initialStock: 100,
      );
      await mutationRepository.recordMutation(
        productId: product.id,
        type: StockMutationType.stockOut,
        quantity: 10,
      );

      final profitBefore = await mutationRepository.calculateTotalProfit();
      expect(profitBefore, (10000 - 6000) * 10);

      await productRepository.update(id: product.id, sellPrice: 30000);
      await mutationRepository.recordMutation(
        productId: product.id,
        type: StockMutationType.stockIn,
        quantity: 10,
        costPricePerUnit: 20000,
      );

      // The old stock-out still contributes exactly what it did before;
      // the new stock-in contributes nothing (only stock-outs earn).
      expect(await mutationRepository.calculateTotalProfit(), profitBefore);
    });
  });

  group('MutationSnapshotBackfill', () {
    /// Blanks [mutationId]'s snapshots to simulate a row written before
    /// the fields existed.
    Future<void> makeLegacy(int mutationId) async {
      final mutation = (await isar.stockMutations.get(mutationId))!;
      await isar.writeTxn(() async {
        await isar.stockMutations.put(
          mutation
            ..sellPriceSnapshot = null
            ..costPriceSnapshot = null
            ..snapshotBackfilled = false,
        );
      });
    }

    test('fills only null-snapshot rows and leaves existing snapshots untouched', () async {
      final product = await createProduct(
        sellPrice: 10000,
        averageCostPrice: 6000,
        initialStock: 50,
      );

      final legacy = await mutationRepository.recordMutation(
        productId: product.id,
        type: StockMutationType.stockOut,
        quantity: 5,
      );
      final snapshotted = await mutationRepository.recordMutation(
        productId: product.id,
        type: StockMutationType.stockOut,
        quantity: 5,
      );
      await makeLegacy(legacy.id);

      // Prices drift after the legacy row was recorded — the backfill can
      // only approximate it with these, which is exactly why it marks the
      // row.
      await productRepository.update(id: product.id, sellPrice: 15000);

      final written = await MutationSnapshotBackfill(isar).runIfNeeded();
      expect(written, 1);

      final filled = (await isar.stockMutations.get(legacy.id))!;
      expect(filled.sellPriceSnapshot, 15000);
      expect(filled.costPriceSnapshot, 6000);
      expect(filled.snapshotBackfilled, isTrue);

      final untouched = (await isar.stockMutations.get(snapshotted.id))!;
      expect(untouched.sellPriceSnapshot, 10000);
      expect(untouched.costPriceSnapshot, 6000);
      expect(untouched.snapshotBackfilled, isFalse);
    });

    test('is idempotent across two runs', () async {
      final product = await createProduct(
        sellPrice: 10000,
        averageCostPrice: 6000,
        initialStock: 50,
      );
      final legacy = await mutationRepository.recordMutation(
        productId: product.id,
        type: StockMutationType.stockOut,
        quantity: 5,
      );
      await makeLegacy(legacy.id);

      final backfill = MutationSnapshotBackfill(isar);
      expect(await backfill.runIfNeeded(), 1);

      final afterFirst = (await isar.stockMutations.get(legacy.id))!;
      final countAfterFirst = await isar.stockMutations.count();

      // Guarded second call is skipped by the persisted flag...
      expect(await backfill.runIfNeeded(), 0);
      expect((await appSettingsRepository.get()).mutationPriceSnapshotBackfillDone, isTrue);

      // ...and even forcing the pass past the flag writes nothing, since
      // no null-snapshot rows remain. Prices are changed in between to
      // prove a second pass couldn't silently re-approximate.
      await productRepository.update(id: product.id, sellPrice: 77000);
      expect(await backfill.run(), 0);

      final afterSecond = (await isar.stockMutations.get(legacy.id))!;
      expect(afterSecond.sellPriceSnapshot, afterFirst.sellPriceSnapshot);
      expect(afterSecond.costPriceSnapshot, afterFirst.costPriceSnapshot);
      expect(afterSecond.snapshotBackfilled, isTrue);
      expect(await isar.stockMutations.count(), countAfterFirst);
    });

    test('does not crash on a mutation whose product was deleted', () async {
      final product = await createProduct(
        sellPrice: 10000,
        averageCostPrice: 6000,
        initialStock: 50,
      );
      final orphaned = await mutationRepository.recordMutation(
        productId: product.id,
        type: StockMutationType.stockOut,
        quantity: 5,
      );
      await makeLegacy(orphaned.id);

      // Hard-deleted straight through Isar: ProductRepository.delete
      // refuses to remove a product that still has mutation history, so
      // this is the only way to reach the orphaned-row state the
      // migration must survive.
      await isar.writeTxn(() async {
        await isar.products.delete(product.id);
      });

      expect(await MutationSnapshotBackfill(isar).runIfNeeded(), 0);

      final stillNull = (await isar.stockMutations.get(orphaned.id))!;
      expect(stillNull.sellPriceSnapshot, isNull);
      expect(stillNull.costPriceSnapshot, isNull);
      expect(stillNull.snapshotBackfilled, isFalse);

      // And profit reporting skips it rather than throwing.
      expect(await mutationRepository.calculateTotalProfit(), 0);
    });
  });
}
