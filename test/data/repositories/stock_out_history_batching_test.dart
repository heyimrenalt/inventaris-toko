import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/models/product.dart';
import 'package:inventaris_toko/data/models/stock_mutation.dart';
import 'package:inventaris_toko/data/repositories/app_settings_repository.dart';
import 'package:inventaris_toko/data/repositories/category_repository.dart';
import 'package:inventaris_toko/data/repositories/product_repository.dart';
import 'package:inventaris_toko/data/repositories/stock_mutation_repository.dart';
import 'package:inventaris_toko/domain/prioritas_kulakan_calculator.dart';
import 'package:isar_community/isar.dart';

import 'test_isar.dart';

/// The per-product loop that [StockMutationRepository.getStockOutHistoryForProducts]
/// replaced across Beranda, Prioritas Kulakan, Frequently Sold, Catat Mutasi
/// and the daily-summary task. Kept here as the reference implementation the
/// batched query is proved equivalent to.
Future<Map<int, List<StockMutation>>> loadViaPerProductLoop(
  StockMutationRepository repository,
  Iterable<int> productIds,
) async {
  final byProduct = <int, List<StockMutation>>{};
  for (final productId in productIds) {
    byProduct[productId] =
        await repository.getStockOutHistoryForProduct(productId);
  }
  return byProduct;
}

/// Reduces a grouping to plain ids so comparisons assert on identity *and*
/// order, not on StockMutation instance equality (which is referential).
Map<int, List<int>> idsByProduct(Map<int, List<StockMutation>> byProduct) {
  return {
    for (final entry in byProduct.entries)
      entry.key: [for (final mutation in entry.value) mutation.id],
  };
}

void main() {
  late Isar isar;
  late ProductRepository productRepository;
  late StockMutationRepository mutationRepository;

  setUp(() async {
    isar = await openTestIsar();
    final categoryRepository = CategoryRepository(isar);
    mutationRepository = StockMutationRepository(isar);
    productRepository = ProductRepository(
      isar,
      mutationRepository,
      AppSettingsRepository(isar),
    );
    await categoryRepository.create('Snacks');
  });

  tearDown(() async {
    await closeTestIsar(isar);
  });

  Future<Product> createProduct(String name, {double initialStock = 100}) {
    return productRepository.create(
      name: name,
      categoryId: null,
      sellPrice: 1000,
      unit: 'pcs',
      initialStock: initialStock,
    );
  }

  group('getStockOutHistoryForProducts matches the per-product loop', () {
    test('across products with many, few, and zero stock-out mutations',
        () async {
      // busy: many stockOut rows. quiet: a single one. idle: none at all.
      // stockIn rows are interleaved throughout to prove type filtering
      // survives batching.
      final busy = await createProduct('Busy');
      final quiet = await createProduct('Quiet');
      final idle = await createProduct('Idle');

      for (var i = 0; i < 12; i++) {
        await mutationRepository.recordMutation(
          productId: busy.id,
          type: StockMutationType.stockOut,
          quantity: 2,
        );
        if (i.isEven) {
          await mutationRepository.recordMutation(
            productId: busy.id,
            type: StockMutationType.stockIn,
            quantity: 5,
          );
        }
      }
      await mutationRepository.recordMutation(
        productId: quiet.id,
        type: StockMutationType.stockOut,
        quantity: 3,
      );
      // idle gets stockIn only — it must still appear, with an empty list.
      await mutationRepository.recordMutation(
        productId: idle.id,
        type: StockMutationType.stockIn,
        quantity: 7,
      );

      final productIds = [busy.id, quiet.id, idle.id];
      final viaLoop = await loadViaPerProductLoop(mutationRepository, productIds);
      final viaBatch =
          await mutationRepository.getStockOutHistoryForProducts(productIds);

      expect(idsByProduct(viaBatch), idsByProduct(viaLoop));
      expect(viaBatch.keys, orderedEquals(viaLoop.keys));
      expect(viaBatch[busy.id], hasLength(12));
      expect(viaBatch[quiet.id], hasLength(1));
      expect(viaBatch[idle.id], isEmpty);
      for (final mutations in viaBatch.values) {
        expect(
          mutations.every((m) => m.type == StockMutationType.stockOut),
          isTrue,
        );
      }
    });

    test('preserves createdAt ordering within each product', () async {
      // Written out of chronological order so a naive implementation that
      // just echoes insertion order can't pass.
      final product = await createProduct('Shuffled');
      final base = DateTime(2026, 3, 1);
      for (final offset in [5, 0, 3, 1, 4, 2]) {
        final mutation = await mutationRepository.recordMutation(
          productId: product.id,
          type: StockMutationType.stockOut,
          quantity: 1,
        );
        await isar.writeTxn(() async {
          await isar.stockMutations
              .put(mutation..createdAt = base.add(Duration(days: offset)));
        });
      }

      final viaLoop = await loadViaPerProductLoop(mutationRepository, [product.id]);
      final viaBatch =
          await mutationRepository.getStockOutHistoryForProducts([product.id]);

      expect(idsByProduct(viaBatch), idsByProduct(viaLoop));
      final dates = viaBatch[product.id]!.map((m) => m.createdAt).toList();
      expect(dates, orderedEquals([...dates]..sort()));
    });

    test('keeps each product\'s mutations separate when timestamps interleave',
        () async {
      // Alternating writes across products: batching reads them in one
      // globally-sorted pass, so mis-grouping would show up here.
      final first = await createProduct('First');
      final second = await createProduct('Second');
      for (var i = 0; i < 6; i++) {
        await mutationRepository.recordMutation(
          productId: i.isEven ? first.id : second.id,
          type: StockMutationType.stockOut,
          quantity: 1,
        );
      }

      final productIds = [first.id, second.id];
      final viaLoop = await loadViaPerProductLoop(mutationRepository, productIds);
      final viaBatch =
          await mutationRepository.getStockOutHistoryForProducts(productIds);

      expect(idsByProduct(viaBatch), idsByProduct(viaLoop));
      expect(viaBatch[first.id], hasLength(3));
      expect(viaBatch[second.id], hasLength(3));
    });

    test('returns only the requested products, e.g. a category subset',
        () async {
      // Frequently Sold passes a filtered product list, not the whole
      // catalog — mutations for the others must not leak into the map.
      final included = await createProduct('Included');
      final excluded = await createProduct('Excluded');
      await mutationRepository.recordMutation(
        productId: included.id,
        type: StockMutationType.stockOut,
        quantity: 1,
      );
      await mutationRepository.recordMutation(
        productId: excluded.id,
        type: StockMutationType.stockOut,
        quantity: 1,
      );

      final viaBatch =
          await mutationRepository.getStockOutHistoryForProducts([included.id]);

      expect(viaBatch.keys, orderedEquals([included.id]));
      expect(viaBatch[included.id], hasLength(1));
    });

    test('returns an empty map for an empty product list', () async {
      expect(
        await mutationRepository.getStockOutHistoryForProducts(const []),
        isEmpty,
      );
    });
  });

  test('prioritas kulakan aggregates are unchanged by batching', () async {
    final fast = await createProduct('Fast mover');
    final slow = await createProduct('Slow mover');
    final none = await createProduct('Never sold');
    final now = DateTime(2026, 4, 1);

    Future<void> recordAt(int productId, double quantity, int daysAgo) async {
      final mutation = await mutationRepository.recordMutation(
        productId: productId,
        type: StockMutationType.stockOut,
        quantity: quantity,
      );
      await isar.writeTxn(() async {
        await isar.stockMutations
            .put(mutation..createdAt = now.subtract(Duration(days: daysAgo)));
      });
    }

    for (var day = 1; day <= 10; day++) {
      await recordAt(fast.id, 4, day);
    }
    await recordAt(slow.id, 1, 3);
    await recordAt(slow.id, 1, 9);

    final products = [fast, slow, none];
    final productIds = products.map((product) => product.id).toList();
    final calculator = PrioritasKulakanCalculator();

    List<PrioritasKulakanResult> calculate(
      Map<int, List<StockMutation>> byProduct,
    ) {
      return calculator.calculateAll(
        products: products,
        stockOutMutationsByProductId: byProduct,
        restockLeadTimeDays: 3,
        restockCoverDays: 7,
        now: now,
      );
    }

    final fromLoop = calculate(
      await loadViaPerProductLoop(mutationRepository, productIds),
    );
    final fromBatch = calculate(
      await mutationRepository.getStockOutHistoryForProducts(productIds),
    );

    expect(fromBatch, hasLength(fromLoop.length));
    for (var i = 0; i < fromLoop.length; i++) {
      expect(fromBatch[i].product.id, fromLoop[i].product.id);
      expect(fromBatch[i].dailyVelocity, fromLoop[i].dailyVelocity);
      expect(fromBatch[i].dataAgeDays, fromLoop[i].dataAgeDays);
      expect(
        fromBatch[i].estimatedDaysRemaining,
        fromLoop[i].estimatedDaysRemaining,
      );
      expect(fromBatch[i].urgency, fromLoop[i].urgency);
      expect(fromBatch[i].suggestedRestockQty, fromLoop[i].suggestedRestockQty);
      expect(fromBatch[i].isOutOfStock, fromLoop[i].isOutOfStock);
    }
    // Guards against the whole comparison passing on empty/degenerate data.
    expect(fromBatch.map((result) => result.dailyVelocity), contains(isPositive));
  });
}
