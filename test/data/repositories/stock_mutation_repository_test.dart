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

  test('stockOut exceeding currentStock clamps to 0 but records requested quantity', () async {
    final mutation = await stockMutationRepository.recordMutation(
      productId: productId,
      type: StockMutationType.stockOut,
      quantity: 999,
    );

    expect(mutation.quantity, 999);
    expect(mutation.stockAfter, 0);

    final product = await productRepository.getById(productId);
    expect(product!.currentStock, 0);
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
}
