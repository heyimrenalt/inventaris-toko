import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/repositories/app_settings_repository.dart';
import 'package:inventaris_toko/data/repositories/category_repository.dart';
import 'package:inventaris_toko/data/repositories/product_repository.dart';
import 'package:inventaris_toko/data/repositories/stock_mutation_repository.dart';
import 'package:isar_community/isar.dart';

import 'test_isar.dart';

/// Bulk archive/delete from the Produk grid's multi-select. The contract
/// that matters most: deleting many products must not become a way around
/// [ProductRepository.delete]'s refusal to destroy mutation history.
void main() {
  late Isar isar;
  late ProductRepository productRepository;
  late StockMutationRepository mutationRepository;
  late CategoryRepository categoryRepository;

  setUp(() async {
    isar = await openTestIsar();
    mutationRepository = StockMutationRepository(isar);
    categoryRepository = CategoryRepository(isar);
    productRepository = ProductRepository(
      isar,
      mutationRepository,
      AppSettingsRepository(isar),
    );
  });

  tearDown(() async => closeTestIsar(isar));

  Future<int> makeProduct(String name, {double initialStock = 0}) async {
    final category = await categoryRepository.create('Cat $name');
    final product = await productRepository.create(
      name: name,
      categoryId: category.id,
      unit: 'pcs',
      sellPrice: 1000,
      initialStock: initialStock,
    );
    return product.id;
  }

  group('archiveMany', () {
    test('archives every id and reports what it changed', () async {
      final a = await makeProduct('A');
      final b = await makeProduct('B');

      final archived = await productRepository.archiveMany([a, b]);

      expect(archived, [a, b]);
      expect(await productRepository.getAll(), isEmpty);
      expect((await productRepository.getArchived()).length, 2);
    });

    test('skips an already-archived product so undo cannot over-restore', () async {
      final a = await makeProduct('A');
      final b = await makeProduct('B');
      await productRepository.archive(a);

      // A was archived beforehand and must not be reported as this
      // batch's doing — undoing the batch would otherwise un-archive it.
      final archived = await productRepository.archiveMany([a, b]);

      expect(archived, [b]);
      await productRepository.unarchiveMany(archived);
      expect((await productRepository.getById(a))!.isArchived, isTrue);
      expect((await productRepository.getById(b))!.isArchived, isFalse);
    });

    test('a missing id does not cost the rest of the batch', () async {
      final a = await makeProduct('A');

      final archived = await productRepository.archiveMany([999999, a]);

      expect(archived, [a]);
    });
  });

  group('deleteMany', () {
    test('deletes products that have no mutation history', () async {
      final a = await makeProduct('A');
      final b = await makeProduct('B');

      final result = await productRepository.deleteMany([a, b]);

      expect(result.deleted.map((p) => p.id), [a, b]);
      expect(result.blocked, isEmpty);
      expect(await productRepository.getAll(includeArchived: true), isEmpty);
    });

    test('refuses a product with mutations and leaves its ledger intact', () async {
      // initialStock writes an opening stockIn, which is exactly the
      // history that must survive.
      final withHistory = await makeProduct('Punya riwayat', initialStock: 5);
      final clean = await makeProduct('Bersih');

      final result = await productRepository.deleteMany([withHistory, clean]);

      expect(result.deleted.map((p) => p.id), [clean]);
      expect(result.blocked.map((p) => p.id), [withHistory]);

      // The product is still there, and so is every mutation of it.
      expect(await productRepository.getById(withHistory), isNotNull);
      final mutations = await mutationRepository.getHistoryForProduct(withHistory);
      expect(mutations, isNotEmpty);
    });

    test('bulk is not a loophole: one blocked product does not abort the rest',
        () async {
      final blocked = await makeProduct('Blocked', initialStock: 3);
      final a = await makeProduct('A');
      final b = await makeProduct('B');

      final result = await productRepository.deleteMany([blocked, a, b]);

      expect(result.deleted.length, 2);
      expect(result.blocked.length, 1);
      expect(await mutationRepository.getAllMutations(), isNotEmpty);
    });

    test('an empty selection yields an empty result', () async {
      final result = await productRepository.deleteMany(const <int>[]);
      expect(result.isEmpty, isTrue);
    });
  });
}
