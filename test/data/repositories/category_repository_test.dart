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
  });

  group('CategoryRepository.delete', () {
    test('blocks deletion when a product references the category', () async {
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

    test('succeeds when no product references the category', () async {
      final category = await categoryRepository.create('Snacks');
      await categoryRepository.delete(category.id);
      expect(await categoryRepository.getById(category.id), isNull);
    });
  });
}
