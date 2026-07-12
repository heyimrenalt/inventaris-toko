import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/repositories/app_settings_repository.dart';
import 'package:inventaris_toko/data/repositories/category_repository.dart';
import 'package:inventaris_toko/data/repositories/product_repository.dart';
import 'package:inventaris_toko/data/repositories/stock_mutation_repository.dart';
import 'package:inventaris_toko/ui/screens/produk/archived_products_screen.dart';
import 'package:isar_community/isar.dart';

import '../../../data/repositories/test_isar.dart';
import '../../widget_test_helpers.dart';

void main() {
  late Isar isar;
  late CategoryRepository categoryRepository;
  late ProductRepository productRepository;

  setUp(() async {
    isar = await openTestIsar();
    categoryRepository = CategoryRepository(isar);
    productRepository = ProductRepository(
      isar,
      StockMutationRepository(isar),
      AppSettingsRepository(isar),
    );
  });

  tearDown(() async {
    await closeTestIsar(isar);
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: ArchivedProductsScreen(isar: isar)));
    await settleAfterAsyncWork(tester);
  }

  testWidgets('shows empty state when no archived products exist', (tester) async {
    await tester.runAsync(() async {
      await pumpScreen(tester);

      expect(find.text('Belum ada produk yang diarsipkan.'), findsOneWidget);
    });
  });

  testWidgets('shows archived items with correct info', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Snacks');
      final product = await productRepository.create(
        name: 'Chips',
        categoryId: category.id,
        sellPrice: 5000,
        unit: 'pcs',
      );
      await productRepository.archive(product.id);

      await pumpScreen(tester);

      expect(find.text('Chips'), findsOneWidget);
      expect(find.text('Snacks'), findsOneWidget);
      expect(find.textContaining('Diarsipkan pada'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Pulihkan'), findsOneWidget);
    });
  });

  testWidgets('restoring a product removes it from this list', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Snacks');
      final product = await productRepository.create(
        name: 'Chips',
        categoryId: category.id,
        sellPrice: 5000,
        unit: 'pcs',
      );
      await productRepository.archive(product.id);

      await pumpScreen(tester);
      expect(find.text('Chips'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Pulihkan'));
      await settleAfterAsyncWork(tester);

      expect(find.text('Chips'), findsNothing);
      expect(find.text('Belum ada produk yang diarsipkan.'), findsOneWidget);
      expect(find.text('Produk dipulihkan'), findsOneWidget);

      final restored = await productRepository.getById(product.id);
      expect(restored!.isArchived, isFalse);
    });
  });

  testWidgets('restored product reappears in the normal Produk list query', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Snacks');
      final product = await productRepository.create(
        name: 'Chips',
        categoryId: category.id,
        sellPrice: 5000,
        unit: 'pcs',
      );
      await productRepository.archive(product.id);
      expect(await productRepository.getAll(), isEmpty);

      await pumpScreen(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Pulihkan'));
      await settleAfterAsyncWork(tester);

      final activeList = await productRepository.getAll();
      expect(activeList.map((p) => p.id), [product.id]);
    });
  });
}
