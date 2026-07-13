import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/repositories/category_repository.dart';
import 'package:inventaris_toko/data/repositories/product_repository.dart';
import 'package:inventaris_toko/data/repositories/app_settings_repository.dart';
import 'package:inventaris_toko/data/repositories/repository_exceptions.dart';
import 'package:inventaris_toko/data/repositories/stock_mutation_repository.dart';
import 'package:isar_community/isar.dart';

import 'test_isar.dart';

void main() {
  late Isar isar;
  late CategoryRepository categoryRepository;
  late ProductRepository productRepository;

  setUp(() async {
    isar = await openTestIsar();
    categoryRepository = CategoryRepository(isar);
    final stockMutationRepository = StockMutationRepository(isar);
    final appSettingsRepository = AppSettingsRepository(isar);
    productRepository = ProductRepository(
      isar,
      stockMutationRepository,
      appSettingsRepository,
    );
  });

  tearDown(() async {
    await closeTestIsar(isar);
  });

  group('CategoryRepository.create', () {
    test('rejects empty/whitespace-only names', () async {
      expect(() => categoryRepository.create(''), throwsA(isA<ValidationException>()));
      expect(() => categoryRepository.create('   '), throwsA(isA<ValidationException>()));
    });

    test('rejects duplicate names case-insensitively', () async {
      await categoryRepository.create('Snacks');
      expect(
        () => categoryRepository.create('snacks'),
        throwsA(isA<DuplicateCategoryNameException>()),
      );
      expect(
        () => categoryRepository.create('SNACKS'),
        throwsA(isA<DuplicateCategoryNameException>()),
      );
    });

    test('allows distinct names', () async {
      await categoryRepository.create('Snacks');
      final drinks = await categoryRepository.create('Drinks');
      expect(drinks.name, 'Drinks');
      expect((await categoryRepository.getAll()).length, 2);
    });

    test('created root category has a null parentId', () async {
      final category = await categoryRepository.create('Snacks');
      expect(category.parentId, isNull);
    });

    test('allows the same name under two different parents', () async {
      final alatTulis = await categoryRepository.create('Alat Tulis');
      final mainan = await categoryRepository.create('Mainan');

      final a = await categoryRepository.create('Pulpen', parentId: alatTulis.id);
      final b = await categoryRepository.create('Pulpen', parentId: mainan.id);

      expect(a.name, 'Pulpen');
      expect(b.name, 'Pulpen');
    });

    test('rejects the same name (case-insensitive) under the same parent', () async {
      final alatTulis = await categoryRepository.create('Alat Tulis');
      await categoryRepository.create('Pulpen', parentId: alatTulis.id);

      expect(
        () => categoryRepository.create('pulpen', parentId: alatTulis.id),
        throwsA(isA<DuplicateCategoryNameException>()),
      );
    });

    test('a root-level name does not collide with the same name nested elsewhere', () async {
      final alatTulis = await categoryRepository.create('Alat Tulis');
      await categoryRepository.create('Pulpen', parentId: alatTulis.id);

      // "Pulpen" as a root category is a different sibling scope
      // (parentId: null) so it must not collide with the nested one.
      final rootPulpen = await categoryRepository.create('Pulpen');
      expect(rootPulpen.parentId, isNull);
    });
  });

  group('CategoryRepository.rename', () {
    test('rejects empty names and case-insensitive duplicates', () async {
      final a = await categoryRepository.create('Snacks');
      await categoryRepository.create('Drinks');

      expect(
        () => categoryRepository.rename(a.id, ''),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => categoryRepository.rename(a.id, 'drinks'),
        throwsA(isA<DuplicateCategoryNameException>()),
      );
    });

    test('allows renaming to its own current name (case change)', () async {
      final a = await categoryRepository.create('Snacks');
      final renamed = await categoryRepository.rename(a.id, 'SNACKS');
      expect(renamed.name, 'SNACKS');
    });

    test('renaming to a name only taken under a different parent is allowed', () async {
      final alatTulis = await categoryRepository.create('Alat Tulis');
      final mainan = await categoryRepository.create('Mainan');
      await categoryRepository.create('Pulpen', parentId: alatTulis.id);
      final pensil = await categoryRepository.create('Pensil', parentId: mainan.id);

      final renamed = await categoryRepository.rename(pensil.id, 'Pulpen');
      expect(renamed.name, 'Pulpen');
    });
  });

  group('CategoryRepository tree queries', () {
    test('getRootCategories returns only categories with a null parentId', () async {
      final snacks = await categoryRepository.create('Snacks');
      await categoryRepository.create('Pulpen', parentId: snacks.id);

      final roots = await categoryRepository.getRootCategories();
      expect(roots.map((c) => c.id), [snacks.id]);
    });

    test('getChildren returns only the direct children of the given parent', () async {
      final alatTulis = await categoryRepository.create('Alat Tulis');
      final pulpen = await categoryRepository.create('Pulpen', parentId: alatTulis.id);
      await categoryRepository.create('Gel', parentId: pulpen.id); // grandchild, not a direct child
      await categoryRepository.create('Mainan'); // unrelated root

      final children = await categoryRepository.getChildren(alatTulis.id);
      expect(children.map((c) => c.id), [pulpen.id]);
    });

    test('getDescendantIds returns all descendants across 3+ levels of depth', () async {
      final alatTulis = await categoryRepository.create('Alat Tulis');
      final tulisMenulis = await categoryRepository.create('Tulis Menulis', parentId: alatTulis.id);
      final pulpen = await categoryRepository.create('Pulpen', parentId: tulisMenulis.id);
      final pulpenGel = await categoryRepository.create('Pulpen Gel', parentId: pulpen.id);
      await categoryRepository.create('Mainan'); // unrelated root, must not appear

      final descendantIds = await categoryRepository.getDescendantIds(alatTulis.id);
      expect(
        descendantIds.toSet(),
        {tulisMenulis.id, pulpen.id, pulpenGel.id},
      );
    });

    test('getDescendantIds returns empty for a leaf category', () async {
      final category = await categoryRepository.create('Snacks');
      expect(await categoryRepository.getDescendantIds(category.id), isEmpty);
    });
  });

  group('CategoryRepository.delete', () {
    test('blocks deletion when a product directly references the category', () async {
      final category = await categoryRepository.create('Snacks');
      await productRepository.create(
        name: 'Chips',
        categoryId: category.id,
        sellPrice: 10000,
        unit: 'pcs',
      );

      expect(
        () => categoryRepository.delete(category.id),
        throwsA(isA<CategoryInUseException>()),
      );
      expect(await categoryRepository.getById(category.id), isNotNull);
    });

    test('blocks deletion when only a grandchild category (2+ levels down) has a product', () async {
      final alatTulis = await categoryRepository.create('Alat Tulis');
      final tulisMenulis = await categoryRepository.create('Tulis Menulis', parentId: alatTulis.id);
      final pulpen = await categoryRepository.create('Pulpen', parentId: tulisMenulis.id);
      await productRepository.create(
        name: 'Pulpen Merah',
        categoryId: pulpen.id,
        sellPrice: 3000,
        unit: 'pcs',
      );

      // Deleting the grandparent is blocked by the recursive product
      // check even though no product references "Alat Tulis" or "Tulis
      // Menulis" directly.
      expect(
        () => categoryRepository.delete(alatTulis.id),
        throwsA(
          isA<CategoryInUseException>().having((e) => e.productCount, 'productCount', 1),
        ),
      );
    });

    test('blocks deletion when the category has child categories, even with zero products', () async {
      final alatTulis = await categoryRepository.create('Alat Tulis');
      await categoryRepository.create('Pulpen', parentId: alatTulis.id);

      expect(
        () => categoryRepository.delete(alatTulis.id),
        throwsA(isA<CategoryHasChildrenException>()),
      );
      expect(await categoryRepository.getById(alatTulis.id), isNotNull);
    });

    test('succeeds for a leaf category with no products and no children', () async {
      final alatTulis = await categoryRepository.create('Alat Tulis');
      final pulpen = await categoryRepository.create('Pulpen', parentId: alatTulis.id);

      await categoryRepository.delete(pulpen.id);
      expect(await categoryRepository.getById(pulpen.id), isNull);
    });

    test('succeeds when no product references the category', () async {
      final category = await categoryRepository.create('Snacks');
      await categoryRepository.delete(category.id);
      expect(await categoryRepository.getById(category.id), isNull);
    });
  });
}
