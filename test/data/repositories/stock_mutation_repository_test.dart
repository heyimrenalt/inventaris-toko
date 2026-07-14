import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/models/stock_mutation.dart';
import 'package:inventaris_toko/data/repositories/app_settings_repository.dart';
import 'package:inventaris_toko/data/repositories/category_repository.dart';
import 'package:inventaris_toko/data/repositories/product_repository.dart';
import 'package:inventaris_toko/data/repositories/repository_exceptions.dart';
import 'package:inventaris_toko/data/repositories/stock_mutation_repository.dart';
import 'package:isar_community/isar.dart';

import 'test_isar.dart';

void main() {
  late Isar isar;
  late ProductRepository productRepository;
  late StockMutationRepository stockMutationRepository;
  late int productId;

  setUp(() async {
    isar = await openTestIsar();
    final categoryRepository = CategoryRepository(isar);
    stockMutationRepository = StockMutationRepository(isar);
    final appSettingsRepository = AppSettingsRepository(isar);
    productRepository = ProductRepository(
      isar,
      stockMutationRepository,
      appSettingsRepository,
    );

    final categoryId = (await categoryRepository.create('Snacks')).id;
    productId = (await productRepository.create(
      name: 'Chips',
      categoryId: categoryId,
      sellPrice: 1000,
      unit: 'pcs',
      initialStock: 10,
    ))
        .id;
  });

  tearDown(() async {
    await closeTestIsar(isar);
  });

  test('rejects quantity <= 0', () async {
    expect(
      () => stockMutationRepository.recordMutation(
        productId: productId,
        type: StockMutationType.stockIn,
        quantity: 0,
      ),
      throwsA(isA<ValidationException>()),
    );
    expect(
      () => stockMutationRepository.recordMutation(
        productId: productId,
        type: StockMutationType.stockIn,
        quantity: -5,
      ),
      throwsA(isA<ValidationException>()),
    );
  });

  test('fails when the product does not exist', () async {
    expect(
      () => stockMutationRepository.recordMutation(
        productId: 9999,
        type: StockMutationType.stockIn,
        quantity: 5,
      ),
      throwsA(isA<NotFoundException>()),
    );
  });

  test('stockIn increases currentStock', () async {
    await stockMutationRepository.recordMutation(
      productId: productId,
      type: StockMutationType.stockIn,
      quantity: 15,
      note: 'Restock',
    );

    final product = await productRepository.getById(productId);
    expect(product!.currentStock, 25);
  });

  test('stockOut with sufficient stock decreases currentStock', () async {
    await stockMutationRepository.recordMutation(
      productId: productId,
      type: StockMutationType.stockOut,
      quantity: 4,
    );

    final product = await productRepository.getById(productId);
    expect(product!.currentStock, 6);
  });

  test('stockOut exceeding currentStock is rejected and leaves stock/history untouched', () async {
    final historyBefore = await stockMutationRepository.getHistoryForProduct(productId);

    expect(
      () => stockMutationRepository.recordMutation(
        productId: productId,
        type: StockMutationType.stockOut,
        quantity: 999,
      ),
      throwsA(isA<InsufficientStockException>()),
    );

    final product = await productRepository.getById(productId);
    expect(product!.currentStock, 10);

    final historyAfter = await stockMutationRepository.getHistoryForProduct(productId);
    expect(historyAfter, hasLength(historyBefore.length));
  });

  test('history and recent mutations are ordered newest first', () async {
    await stockMutationRepository.recordMutation(
      productId: productId,
      type: StockMutationType.stockIn,
      quantity: 5,
    );
    await stockMutationRepository.recordMutation(
      productId: productId,
      type: StockMutationType.stockOut,
      quantity: 2,
    );

    final history = await stockMutationRepository.getHistoryForProduct(productId);
    // "Stok awal" + stockIn + stockOut = 3 entries.
    expect(history, hasLength(3));
    expect(history.first.type, StockMutationType.stockOut);

    final recent = await stockMutationRepository.getRecentMutations(2);
    expect(recent, hasLength(2));
  });

  test('getTotalsSince sums stockIn and stockOut separately, excluding mutations outside the window', () async {
    final now = DateTime.now();

    // Within the window (setUp's "Stok awal" of 10 already counts too).
    await stockMutationRepository.recordMutation(
      productId: productId,
      type: StockMutationType.stockIn,
      quantity: 5,
    );
    await stockMutationRepository.recordMutation(
      productId: productId,
      type: StockMutationType.stockOut,
      quantity: 2,
    );

    // Outside the window: recordMutation always stamps `createdAt` with
    // the real current time, so an old mutation has to be inserted
    // directly to simulate one that happened long ago.
    final oldMutation = StockMutation()
      ..productId = productId
      ..type = StockMutationType.stockIn
      ..quantity = 100
      ..stockAfter = 999
      ..createdAt = now.subtract(const Duration(days: 30));
    await isar.writeTxn(() async {
      await isar.stockMutations.put(oldMutation);
    });

    final totals = await stockMutationRepository.getTotalsSince(
      now.subtract(const Duration(days: 7)),
    );

    // setUp's "Stok awal" (10) + this test's stockIn (5) = 15; the
    // 30-day-old 100 must not be included.
    expect(totals.stockIn, 15);
    expect(totals.stockOut, 2);
  });

  group('undoMutation', () {
    test('undoing a stockOut creates a compensating stockIn with the same quantity and a note', () async {
      final outMutation = await stockMutationRepository.recordMutation(
        productId: productId,
        type: StockMutationType.stockOut,
        quantity: 4,
        note: 'Terjual',
      );

      await stockMutationRepository.undoMutation(outMutation.id);

      final history = await stockMutationRepository.getHistoryForProduct(productId);
      final undoEntry = history.firstWhere((m) => m.id != outMutation.id && m.note != null && m.note!.startsWith('Dibatalkan'));
      expect(undoEntry.type, StockMutationType.stockIn);
      expect(undoEntry.quantity, 4);
      expect(undoEntry.note, 'Dibatalkan: Terjual');

      final product = await productRepository.getById(productId);
      // setUp's initial stock (10) - 4 (stockOut) + 4 (undo stockIn) = 10.
      expect(product!.currentStock, 10);
    });

    test('undoing a stockIn creates a compensating stockOut', () async {
      final inMutation = await stockMutationRepository.recordMutation(
        productId: productId,
        type: StockMutationType.stockIn,
        quantity: 5,
      );

      await stockMutationRepository.undoMutation(inMutation.id);

      final history = await stockMutationRepository.getHistoryForProduct(productId);
      final undoEntry = history.firstWhere((m) => m.id != inMutation.id && m.note != null && m.note!.startsWith('Dibatalkan'));
      expect(undoEntry.type, StockMutationType.stockOut);
      expect(undoEntry.quantity, 5);

      final product = await productRepository.getById(productId);
      // setUp's initial stock (10) + 5 (stockIn) - 5 (undo stockOut) = 10.
      expect(product!.currentStock, 10);
    });

    test('falls back to the product name in the note when the original mutation has no note', () async {
      final inMutation = await stockMutationRepository.recordMutation(
        productId: productId,
        type: StockMutationType.stockIn,
        quantity: 5,
      );

      await stockMutationRepository.undoMutation(inMutation.id);

      final history = await stockMutationRepository.getHistoryForProduct(productId);
      final undoEntry = history.firstWhere((m) => m.id != inMutation.id && m.type == StockMutationType.stockOut);
      expect(undoEntry.note, 'Dibatalkan: Chips');
    });

    test(
      'undoing an already-undone mutation produces a clean single "Dibatalkan: X" note, not a nested one',
      () async {
        final outMutation = await stockMutationRepository.recordMutation(
          productId: productId,
          type: StockMutationType.stockOut,
          quantity: 3,
          note: 'Buku',
        );

        // First undo: "Buku" -> "Dibatalkan: Buku".
        await stockMutationRepository.undoMutation(outMutation.id);
        final historyAfterFirstUndo = await stockMutationRepository.getHistoryForProduct(productId);
        final firstUndoEntry = historyAfterFirstUndo.firstWhere((m) => m.id != outMutation.id);
        expect(firstUndoEntry.note, 'Dibatalkan: Buku');

        // Second undo (of the undo itself): must not nest into
        // "Dibatalkan: Dibatalkan: Buku" — the existing prefix is
        // stripped before re-prepending it.
        await stockMutationRepository.undoMutation(firstUndoEntry.id);
        final historyAfterSecondUndo = await stockMutationRepository.getHistoryForProduct(productId);
        final secondUndoEntry = historyAfterSecondUndo.firstWhere(
          (m) => m.id != outMutation.id && m.id != firstUndoEntry.id,
        );
        expect(secondUndoEntry.note, 'Dibatalkan: Buku');
      },
    );

    test('undoing a non-existent mutation id throws NotFoundException', () async {
      expect(
        () => stockMutationRepository.undoMutation(999999),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('the original mutation record still exists after being undone (append-only ledger)', () async {
      final outMutation = await stockMutationRepository.recordMutation(
        productId: productId,
        type: StockMutationType.stockOut,
        quantity: 4,
      );
      final historyBefore = await stockMutationRepository.getHistoryForProduct(productId);

      await stockMutationRepository.undoMutation(outMutation.id);

      final historyAfter = await stockMutationRepository.getHistoryForProduct(productId);
      expect(historyAfter, hasLength(historyBefore.length + 1));
      expect(historyAfter.any((m) => m.id == outMutation.id), isTrue);
    });
  });

  group('getMostRecentMutationForProduct', () {
    test('returns the most recently created mutation for the given product', () async {
      await stockMutationRepository.recordMutation(
        productId: productId,
        type: StockMutationType.stockIn,
        quantity: 5,
      );
      final latest = await stockMutationRepository.recordMutation(
        productId: productId,
        type: StockMutationType.stockOut,
        quantity: 2,
      );

      final result = await stockMutationRepository.getMostRecentMutationForProduct(productId);
      expect(result!.id, latest.id);
    });

    test('returns null when the product has no mutation history', () async {
      final category = (await CategoryRepository(isar).create('Drinks')).id;
      final id = (await productRepository.create(
        name: 'Teh Botol',
        categoryId: category,
        sellPrice: 5000,
        unit: 'pcs',
      ))
          .id;

      final result = await stockMutationRepository.getMostRecentMutationForProduct(id);
      expect(result, isNull);
    });
  });

  group('HPP (averageCostPrice)', () {
    test('stockIn from zero stock sets HPP directly to the incoming cost price', () async {
      final category = (await CategoryRepository(isar).create('Drinks')).id;
      final id = (await productRepository.create(
        name: 'Teh Botol',
        categoryId: category,
        sellPrice: 5000,
        unit: 'pcs',
      ))
          .id;

      await stockMutationRepository.recordMutation(
        productId: id,
        type: StockMutationType.stockIn,
        quantity: 10,
        costPricePerUnit: 5000,
      );

      final product = await productRepository.getById(id);
      expect(product!.averageCostPrice, 5000);
    });

    test('stockIn with costPricePerUnit computes the weighted average against existing HPP', () async {
      final category = (await CategoryRepository(isar).create('Drinks')).id;
      final id = (await productRepository.create(
        name: 'Teh Botol',
        categoryId: category,
        sellPrice: 5000,
        unit: 'pcs',
      ))
          .id;

      await stockMutationRepository.recordMutation(
        productId: id,
        type: StockMutationType.stockIn,
        quantity: 10,
        costPricePerUnit: 5000,
      );
      await stockMutationRepository.recordMutation(
        productId: id,
        type: StockMutationType.stockIn,
        quantity: 5,
        costPricePerUnit: 8000,
      );

      // (10 units @ 5000 + 5 units @ 8000) / 15 = 6000.
      final product = await productRepository.getById(id);
      expect(product!.averageCostPrice, 6000);
      // Stock update and HPP update land in the same write transaction, so
      // both reflect the second batch together.
      expect(product.currentStock, 15);
    });

    test('stockIn without costPricePerUnit leaves averageCostPrice unchanged', () async {
      await stockMutationRepository.recordMutation(
        productId: productId,
        type: StockMutationType.stockIn,
        quantity: 5,
      );

      final product = await productRepository.getById(productId);
      expect(product!.averageCostPrice, isNull);
      expect(product.currentStock, 15);
    });

    test('stockOut never modifies averageCostPrice, even if a cost price were somehow supplied', () async {
      final category = (await CategoryRepository(isar).create('Drinks')).id;
      final id = (await productRepository.create(
        name: 'Teh Botol',
        categoryId: category,
        sellPrice: 5000,
        unit: 'pcs',
        initialStock: 10,
        averageCostPrice: 4000,
      ))
          .id;

      await stockMutationRepository.recordMutation(
        productId: id,
        type: StockMutationType.stockOut,
        quantity: 4,
        costPricePerUnit: 9999,
      );

      final product = await productRepository.getById(id);
      expect(product!.averageCostPrice, 4000);
      expect(product.currentStock, 6);
    });
  });
}
