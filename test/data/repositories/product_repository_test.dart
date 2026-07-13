import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/repositories/app_settings_repository.dart';
import 'package:inventaris_toko/data/repositories/category_repository.dart';
import 'package:inventaris_toko/data/repositories/product_repository.dart';
import 'package:inventaris_toko/data/repositories/repository_exceptions.dart';
import 'package:inventaris_toko/data/repositories/stock_mutation_repository.dart';
import 'package:isar_community/isar.dart';

import 'test_isar.dart';

void main() {
  late Isar isar;
  late CategoryRepository categoryRepository;
  late ProductRepository productRepository;
  late StockMutationRepository stockMutationRepository;
  late AppSettingsRepository appSettingsRepository;
  late int categoryId;

  setUp(() async {
    isar = await openTestIsar();
    categoryRepository = CategoryRepository(isar);
    stockMutationRepository = StockMutationRepository(isar);
    appSettingsRepository = AppSettingsRepository(isar);
    productRepository = ProductRepository(
      isar,
      stockMutationRepository,
      appSettingsRepository,
    );
    categoryId = (await categoryRepository.create('Snacks')).id;
  });

  tearDown(() async {
    await closeTestIsar(isar);
  });

  group('ProductRepository.create validation', () {
    test('rejects empty name', () async {
      expect(
        () => productRepository.create(
          name: '',
          categoryId: categoryId,
          sellPrice: 1000,
          unit: 'pcs',
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('rejects empty unit', () async {
      expect(
        () => productRepository.create(
          name: 'Chips',
          categoryId: categoryId,
          sellPrice: 1000,
          unit: '  ',
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('rejects negative sellPrice', () async {
      expect(
        () => productRepository.create(
          name: 'Chips',
          categoryId: categoryId,
          sellPrice: -1,
          unit: 'pcs',
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('rejects a categoryId that does not exist', () async {
      expect(
        () => productRepository.create(
          name: 'Chips',
          categoryId: 9999,
          sellPrice: 1000,
          unit: 'pcs',
        ),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('creates successfully with categoryId: null (uncategorized)', () async {
      final product = await productRepository.create(
        name: 'Chips',
        sellPrice: 1000,
        unit: 'pcs',
      );

      expect(product.categoryId, isNull);
    });
  });

  group('Product.code uniqueness', () {
    test('two products can both have a null code', () async {
      await productRepository.create(
        name: 'Chips A',
        categoryId: categoryId,
        sellPrice: 1000,
        unit: 'pcs',
      );
      await productRepository.create(
        name: 'Chips B',
        categoryId: categoryId,
        sellPrice: 1000,
        unit: 'pcs',
      );

      expect((await productRepository.getAll()).length, 2);
    });

    test('two products can both have an empty-string code (treated as null)', () async {
      await productRepository.create(
        name: 'Chips A',
        categoryId: categoryId,
        sellPrice: 1000,
        unit: 'pcs',
        code: '',
      );
      await productRepository.create(
        name: 'Chips B',
        categoryId: categoryId,
        sellPrice: 1000,
        unit: 'pcs',
        code: '   ',
      );

      expect((await productRepository.getAll()).length, 2);
    });

    test('two products cannot share the same non-empty code', () async {
      await productRepository.create(
        name: 'Chips A',
        categoryId: categoryId,
        sellPrice: 1000,
        unit: 'pcs',
        code: '12345',
      );

      expect(
        () => productRepository.create(
          name: 'Chips B',
          categoryId: categoryId,
          sellPrice: 1000,
          unit: 'pcs',
          code: '12345',
        ),
        throwsA(isA<DuplicateProductCodeException>()),
      );
    });
  });

  group('ProductRepository.create with initial stock', () {
    test('records a "Stok awal" stockIn mutation and sets currentStock', () async {
      final product = await productRepository.create(
        name: 'Chips',
        categoryId: categoryId,
        sellPrice: 1000,
        unit: 'pcs',
        initialStock: 20,
      );

      expect(product.currentStock, 20);

      final history = await stockMutationRepository.getHistoryForProduct(product.id);
      expect(history, hasLength(1));
      expect(history.first.note, 'Stok awal');
      expect(history.first.quantity, 20);
      expect(history.first.stockAfter, 20);
    });

    test('no initial stock means no mutation and currentStock stays 0', () async {
      final product = await productRepository.create(
        name: 'Chips',
        categoryId: categoryId,
        sellPrice: 1000,
        unit: 'pcs',
      );

      expect(product.currentStock, 0);
      expect(await stockMutationRepository.getHistoryForProduct(product.id), isEmpty);
    });

    test('minStockThreshold defaults from AppSettings when not provided', () async {
      final settings = await appSettingsRepository.get();
      final product = await productRepository.create(
        name: 'Chips',
        categoryId: categoryId,
        sellPrice: 1000,
        unit: 'pcs',
      );

      expect(product.minStockThreshold, settings.defaultMinStockThreshold);
    });
  });

  group('ProductRepository.update', () {
    test('never changes currentStock (no such parameter exists)', () async {
      final product = await productRepository.create(
        name: 'Chips',
        categoryId: categoryId,
        sellPrice: 1000,
        unit: 'pcs',
        initialStock: 10,
      );

      final updated = await productRepository.update(id: product.id, name: 'Chips XL');

      // The signature of `update` has no `currentStock` parameter at
      // all, so this is enforced at compile time; this assertion just
      // confirms the stored value is untouched by an unrelated update.
      expect(updated.currentStock, 10);
      expect(updated.name, 'Chips XL');
    });
  });

  group('ProductRepository.delete', () {
    test('is blocked when the product has stock mutation history', () async {
      final product = await productRepository.create(
        name: 'Chips',
        categoryId: categoryId,
        sellPrice: 1000,
        unit: 'pcs',
        initialStock: 5,
      );

      expect(
        () => productRepository.delete(product.id),
        throwsA(isA<ProductHasHistoryException>()),
      );
    });

    test('succeeds when the product has no mutation history', () async {
      final product = await productRepository.create(
        name: 'Chips',
        categoryId: categoryId,
        sellPrice: 1000,
        unit: 'pcs',
      );

      await productRepository.delete(product.id);
      expect(await productRepository.getById(product.id), isNull);
    });
  });

  group('ProductRepository search/lookup', () {
    test('searchByName is case-insensitive substring match', () async {
      await productRepository.create(
        name: 'Indomie Goreng',
        categoryId: categoryId,
        sellPrice: 3000,
        unit: 'pcs',
      );

      final results = await productRepository.searchByName('goreng');
      expect(results, hasLength(1));
    });

    test('getByCategory returns only products in that category', () async {
      final otherCategoryId = (await categoryRepository.create('Drinks')).id;
      await productRepository.create(
        name: 'Chips',
        categoryId: categoryId,
        sellPrice: 1000,
        unit: 'pcs',
      );
      await productRepository.create(
        name: 'Water',
        categoryId: otherCategoryId,
        sellPrice: 3000,
        unit: 'pcs',
      );

      final snacks = await productRepository.getByCategory(categoryId);
      expect(snacks, hasLength(1));
      expect(snacks.first.name, 'Chips');
    });

    test('getUncategorized returns only products with a null category', () async {
      await productRepository.create(
        name: 'Chips',
        categoryId: categoryId,
        sellPrice: 1000,
        unit: 'pcs',
      );
      final uncategorized = await productRepository.create(
        name: 'Misc Item',
        sellPrice: 1000,
        unit: 'pcs',
      );

      final results = await productRepository.getUncategorized();
      expect(results.map((p) => p.id), [uncategorized.id]);
    });

    test(
      'getByCategoryIncludingDescendants returns products from the category and its '
      'descendants, excluding unrelated categories',
      () async {
        final alatTulis = await categoryRepository.create('Alat Tulis');
        final pulpen = await categoryRepository.create('Pulpen', parentId: alatTulis.id);
        final unrelated = await categoryRepository.create('Drinks');

        final direct = await productRepository.create(
          name: 'Buku Tulis',
          categoryId: alatTulis.id,
          sellPrice: 3000,
          unit: 'pcs',
        );
        final nested = await productRepository.create(
          name: 'Pulpen Merah',
          categoryId: pulpen.id,
          sellPrice: 2000,
          unit: 'pcs',
        );
        await productRepository.create(
          name: 'Water',
          categoryId: unrelated.id,
          sellPrice: 3000,
          unit: 'pcs',
        );

        final results = await productRepository.getByCategoryIncludingDescendants(alatTulis.id);
        expect(results.map((p) => p.id).toSet(), {direct.id, nested.id});
      },
    );
  });

  group('ProductRepository archive/unarchive', () {
    test('archive() sets isArchived true and archivedAt to a non-null value', () async {
      final product = await productRepository.create(
        name: 'Chips',
        categoryId: categoryId,
        sellPrice: 1000,
        unit: 'pcs',
      );

      final archived = await productRepository.archive(product.id);

      expect(archived.isArchived, isTrue);
      expect(archived.archivedAt, isNotNull);
    });

    test('unarchive() resets isArchived to false and archivedAt to null', () async {
      final product = await productRepository.create(
        name: 'Chips',
        categoryId: categoryId,
        sellPrice: 1000,
        unit: 'pcs',
      );
      await productRepository.archive(product.id);

      final restored = await productRepository.unarchive(product.id);

      expect(restored.isArchived, isFalse);
      expect(restored.archivedAt, isNull);
    });

    test('getAll() excludes archived by default, includes with includeArchived: true', () async {
      final active = await productRepository.create(
        name: 'Active',
        categoryId: categoryId,
        sellPrice: 1000,
        unit: 'pcs',
      );
      final archived = await productRepository.create(
        name: 'Archived',
        categoryId: categoryId,
        sellPrice: 1000,
        unit: 'pcs',
      );
      await productRepository.archive(archived.id);

      final defaultList = await productRepository.getAll();
      expect(defaultList.map((p) => p.id), [active.id]);

      final fullList = await productRepository.getAll(includeArchived: true);
      expect(fullList, hasLength(2));
    });

    test('getArchived() returns only archived products', () async {
      final active = await productRepository.create(
        name: 'Active',
        categoryId: categoryId,
        sellPrice: 1000,
        unit: 'pcs',
      );
      final archived = await productRepository.create(
        name: 'Archived',
        categoryId: categoryId,
        sellPrice: 1000,
        unit: 'pcs',
      );
      await productRepository.archive(archived.id);

      final archivedList = await productRepository.getArchived();
      expect(archivedList.map((p) => p.id), [archived.id]);
      expect(archivedList.any((p) => p.id == active.id), isFalse);
    });

    test('archiving a product with mutation history succeeds', () async {
      final product = await productRepository.create(
        name: 'Chips',
        categoryId: categoryId,
        sellPrice: 1000,
        unit: 'pcs',
        initialStock: 5,
      );

      final archived = await productRepository.archive(product.id);
      expect(archived.isArchived, isTrue);
    });

    test('delete() is still blocked by ProductHasHistoryException whether archived or not', () async {
      final product = await productRepository.create(
        name: 'Chips',
        categoryId: categoryId,
        sellPrice: 1000,
        unit: 'pcs',
        initialStock: 5,
      );
      await productRepository.archive(product.id);

      expect(
        () => productRepository.delete(product.id),
        throwsA(isA<ProductHasHistoryException>()),
      );
    });
  });
}
