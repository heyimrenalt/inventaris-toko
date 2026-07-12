import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/repositories/app_settings_repository.dart';
import 'package:inventaris_toko/data/repositories/category_repository.dart';
import 'package:inventaris_toko/data/repositories/product_repository.dart';
import 'package:inventaris_toko/data/repositories/stock_mutation_repository.dart';
import 'package:inventaris_toko/ui/screens/produk/produk_screen.dart';
import 'package:inventaris_toko/ui/widgets/product_list_item.dart';
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
    await tester.pumpWidget(MaterialApp(home: ProdukScreen(isar: isar)));
    await settleAfterAsyncWork(tester);
  }

  testWidgets('shows empty state when no products exist', (tester) async {
    await tester.runAsync(() async {
      await pumpScreen(tester);

      expect(
        find.text('Belum ada produk. Tambahkan produk pertama untuk mulai.'),
        findsOneWidget,
      );
    });
  });

  testWidgets('shows list of products with correct name/category/stock', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Snacks');
      await productRepository.create(
        name: 'Chips',
        categoryId: category.id,
        sellPrice: 5000,
        unit: 'pcs',
        initialStock: 12,
      );

      await pumpScreen(tester);

      expect(find.text('Chips'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(ProductListItem), matching: find.text('Snacks')),
        findsOneWidget,
      );
      expect(find.text('12 pcs'), findsOneWidget);
    });
  });

  testWidgets('category filter chip filters the visible list', (tester) async {
    await tester.runAsync(() async {
      final snacks = await categoryRepository.create('Snacks');
      final drinks = await categoryRepository.create('Drinks');
      await productRepository.create(
        name: 'Chips',
        categoryId: snacks.id,
        sellPrice: 5000,
        unit: 'pcs',
      );
      await productRepository.create(
        name: 'Water',
        categoryId: drinks.id,
        sellPrice: 3000,
        unit: 'pcs',
      );

      await pumpScreen(tester);

      expect(find.text('Chips'), findsOneWidget);
      expect(find.text('Water'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Drinks'));
      await settleAfterAsyncWork(tester);

      expect(find.text('Water'), findsOneWidget);
      expect(find.text('Chips'), findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Semua'));
      await settleAfterAsyncWork(tester);

      expect(find.text('Chips'), findsOneWidget);
      expect(find.text('Water'), findsOneWidget);
    });
  });

  testWidgets('low stock shows red indicator, sufficient stock shows green', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Snacks');
      final low = await productRepository.create(
        name: 'Low Stock Item',
        categoryId: category.id,
        sellPrice: 1000,
        unit: 'pcs',
        minStockThreshold: 5,
        initialStock: 2,
      );
      final ok = await productRepository.create(
        name: 'OK Stock Item',
        categoryId: category.id,
        sellPrice: 1000,
        unit: 'pcs',
        minStockThreshold: 5,
        initialStock: 10,
      );

      await pumpScreen(tester);

      final lowIndicator = tester.widget<Container>(
        find.byKey(Key('stock_indicator_${low.id}')),
      );
      final okIndicator = tester.widget<Container>(
        find.byKey(Key('stock_indicator_${ok.id}')),
      );

      expect(lowIndicator.color, Colors.red);
      expect(okIndicator.color, Colors.green);
    });
  });

  testWidgets('tapping a list item navigates to the Detail screen', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Snacks');
      await productRepository.create(
        name: 'Chips',
        categoryId: category.id,
        sellPrice: 5000,
        unit: 'pcs',
      );

      await pumpScreen(tester);

      await tester.tap(find.text('Chips'));
      await settleAfterAsyncWork(tester);

      expect(find.text('Detail Produk'), findsOneWidget);
    });
  });
}
