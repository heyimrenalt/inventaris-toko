import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/repositories/app_settings_repository.dart';
import 'package:inventaris_toko/data/repositories/category_repository.dart';
import 'package:inventaris_toko/data/repositories/product_repository.dart';
import 'package:inventaris_toko/data/repositories/repository_exceptions.dart';
import 'package:inventaris_toko/data/repositories/restock_list_repository.dart';
import 'package:inventaris_toko/data/repositories/stock_mutation_repository.dart';
import 'package:isar_community/isar.dart';

import 'test_isar.dart';

void main() {
  late Isar isar;
  late ProductRepository productRepository;
  late RestockListRepository restockListRepository;
  late int categoryId;

  setUp(() async {
    isar = await openTestIsar();
    final categoryRepository = CategoryRepository(isar);
    productRepository = ProductRepository(
      isar,
      StockMutationRepository(isar),
      AppSettingsRepository(isar),
    );
    restockListRepository = RestockListRepository(isar);
    categoryId = (await categoryRepository.create('Snacks')).id;
  });

  tearDown(() async {
    await closeTestIsar(isar);
  });

  test('create persists supplierName (trimmed) and items', () async {
    final product = await productRepository.create(
      name: 'Gula Pasir',
      categoryId: categoryId,
      sellPrice: 15000,
      unit: 'pcs',
    );

    final list = await restockListRepository.create(
      supplierName: '  Toko Pak Adi  ',
      items: [
        RestockListItemInput(
          productId: product.id,
          productName: product.name,
          qtyInPcs: 10,
          inputUnitWasPack: false,
        ),
      ],
    );

    expect(list.supplierName, 'Toko Pak Adi');
    expect(list.completedAt, isNull);
    expect(list.items, hasLength(1));
    expect(list.items.first.productId, product.id);
    expect(list.items.first.productNameSnapshot, 'Gula Pasir');
    expect(list.items.first.qtyInPcs, 10);
    expect(list.items.first.isChecked, isFalse);
  });

  test('create normalizes a blank supplierName to null', () async {
    final list = await restockListRepository.create(supplierName: '   ', items: []);
    expect(list.supplierName, isNull);
  });

  test('updateItemQty updates the matching item only', () async {
    final a = await productRepository.create(
      name: 'A', categoryId: categoryId, sellPrice: 1000, unit: 'pcs',
    );
    final b = await productRepository.create(
      name: 'B', categoryId: categoryId, sellPrice: 1000, unit: 'pcs',
    );

    final list = await restockListRepository.create(
      items: [
        RestockListItemInput(productId: a.id, productName: a.name, qtyInPcs: 5, inputUnitWasPack: false),
        RestockListItemInput(productId: b.id, productName: b.name, qtyInPcs: 8, inputUnitWasPack: false),
      ],
    );

    await restockListRepository.updateItemQty(
      listId: list.id,
      productId: b.id,
      qtyInPcs: 24,
      inputUnitWasPack: true,
    );

    final reloaded = await restockListRepository.getById(list.id);
    final itemA = reloaded!.items.firstWhere((i) => i.productId == a.id);
    final itemB = reloaded.items.firstWhere((i) => i.productId == b.id);
    expect(itemA.qtyInPcs, 5);
    expect(itemB.qtyInPcs, 24);
    expect(itemB.inputUnitWasPack, isTrue);
  });

  test('toggleChecked flips isChecked for the matching item', () async {
    final product = await productRepository.create(
      name: 'Gula', categoryId: categoryId, sellPrice: 1000, unit: 'pcs',
    );
    final list = await restockListRepository.create(
      items: [
        RestockListItemInput(
          productId: product.id,
          productName: product.name,
          qtyInPcs: 5,
          inputUnitWasPack: false,
        ),
      ],
    );

    await restockListRepository.toggleChecked(list.id, product.id);
    var reloaded = await restockListRepository.getById(list.id);
    expect(reloaded!.items.first.isChecked, isTrue);

    await restockListRepository.toggleChecked(list.id, product.id);
    reloaded = await restockListRepository.getById(list.id);
    expect(reloaded!.items.first.isChecked, isFalse);
  });

  group('complete', () {
    test('writes qtyInPcs into Product.lastRestockQty only for checked items', () async {
      final bought = await productRepository.create(
        name: 'Dibeli', categoryId: categoryId, sellPrice: 1000, unit: 'pcs',
      );
      final skipped = await productRepository.create(
        name: 'Dilewati', categoryId: categoryId, sellPrice: 1000, unit: 'pcs',
      );

      final list = await restockListRepository.create(
        items: [
          RestockListItemInput(
            productId: bought.id,
            productName: bought.name,
            qtyInPcs: 20,
            inputUnitWasPack: false,
          ),
          RestockListItemInput(
            productId: skipped.id,
            productName: skipped.name,
            qtyInPcs: 15,
            inputUnitWasPack: false,
          ),
        ],
      );
      await restockListRepository.toggleChecked(list.id, bought.id);

      await restockListRepository.complete(list.id);

      final reloadedBought = await productRepository.getById(bought.id);
      final reloadedSkipped = await productRepository.getById(skipped.id);
      expect(reloadedBought!.lastRestockQty, 20);
      expect(reloadedSkipped!.lastRestockQty, isNull);
    });

    test('sets completedAt', () async {
      final list = await restockListRepository.create(items: []);
      final completed = await restockListRepository.complete(list.id);
      expect(completed.completedAt, isNotNull);
    });

    test('never touches Product.currentStock', () async {
      final product = await productRepository.create(
        name: 'Beras', categoryId: categoryId, sellPrice: 1000, unit: 'pcs', initialStock: 3,
      );
      final list = await restockListRepository.create(
        items: [
          RestockListItemInput(
            productId: product.id,
            productName: product.name,
            qtyInPcs: 50,
            inputUnitWasPack: false,
          ),
        ],
      );
      await restockListRepository.toggleChecked(list.id, product.id);

      await restockListRepository.complete(list.id);

      final reloaded = await productRepository.getById(product.id);
      expect(reloaded!.currentStock, 3);
    });
  });

  test('getActive excludes completed lists', () async {
    final list1 = await restockListRepository.create(items: []);
    final list2 = await restockListRepository.create(items: []);
    await restockListRepository.complete(list1.id);

    final active = await restockListRepository.getActive();

    expect(active.map((l) => l.id), [list2.id]);
  });

  test('operating on a nonexistent list throws NotFoundException', () async {
    expect(
      () => restockListRepository.updateSupplierName(9999, 'X'),
      throwsA(isA<NotFoundException>()),
    );
  });
}
