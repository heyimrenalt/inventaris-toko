import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/repositories/app_settings_repository.dart';
import 'package:inventaris_toko/data/repositories/category_repository.dart';
import 'package:inventaris_toko/data/repositories/cost_price_adjustment_repository.dart';
import 'package:inventaris_toko/data/repositories/product_repository.dart';
import 'package:inventaris_toko/data/repositories/repository_exceptions.dart';
import 'package:inventaris_toko/data/repositories/stock_mutation_repository.dart';
import 'package:isar_community/isar.dart';

import 'test_isar.dart';

void main() {
  late Isar isar;
  late ProductRepository productRepository;
  late CostPriceAdjustmentRepository costPriceAdjustmentRepository;
  late int productId;

  setUp(() async {
    isar = await openTestIsar();
    final categoryRepository = CategoryRepository(isar);
    productRepository = ProductRepository(
      isar,
      StockMutationRepository(isar),
      AppSettingsRepository(isar),
    );
    costPriceAdjustmentRepository = CostPriceAdjustmentRepository(isar);

    final categoryId = (await categoryRepository.create('Snacks')).id;
    productId = (await productRepository.create(
      name: 'Chips',
      categoryId: categoryId,
      sellPrice: 5000,
      unit: 'pcs',
      averageCostPrice: 3000,
    ))
        .id;
  });

  tearDown(() async {
    await closeTestIsar(isar);
  });

  test('recordAdjustment updates averageCostPrice and writes an audit row', () async {
    await costPriceAdjustmentRepository.recordAdjustment(
      productId: productId,
      newCost: 4200,
      note: 'Koreksi salah input',
    );

    final product = await productRepository.getById(productId);
    expect(product!.averageCostPrice, 4200);

    final history = await costPriceAdjustmentRepository.getHistoryForProduct(productId);
    expect(history, hasLength(1));
    expect(history.first.oldCost, 3000);
    expect(history.first.newCost, 4200);
    expect(history.first.note, 'Koreksi salah input');
  });

  test('recordAdjustment can clear averageCostPrice back to null', () async {
    await costPriceAdjustmentRepository.recordAdjustment(productId: productId, newCost: null);

    final product = await productRepository.getById(productId);
    expect(product!.averageCostPrice, isNull);

    final history = await costPriceAdjustmentRepository.getHistoryForProduct(productId);
    expect(history.first.oldCost, 3000);
    expect(history.first.newCost, isNull);
  });

  test('recordAdjustment leaves currentStock untouched', () async {
    await costPriceAdjustmentRepository.recordAdjustment(productId: productId, newCost: 9999);

    final product = await productRepository.getById(productId);
    expect(product!.currentStock, 0);
  });

  test('recordAdjustment fails when the product does not exist', () async {
    expect(
      () => costPriceAdjustmentRepository.recordAdjustment(productId: 9999, newCost: 100),
      throwsA(isA<NotFoundException>()),
    );
  });
}
