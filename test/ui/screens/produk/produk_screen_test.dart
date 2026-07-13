import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/models/stock_mutation.dart';
import 'package:inventaris_toko/data/repositories/app_settings_repository.dart';
import 'package:inventaris_toko/data/repositories/category_repository.dart';
import 'package:inventaris_toko/data/repositories/product_repository.dart';
import 'package:inventaris_toko/data/repositories/stock_mutation_repository.dart';
import 'package:inventaris_toko/ui/screens/produk/produk_screen.dart';
import 'package:inventaris_toko/ui/widgets/category_tree_picker.dart';
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

  Future<void> openCategoryFilterPicker(WidgetTester tester) async {
    final fieldFinder = find.byKey(const Key('produk_category_filter'));
    await tester.ensureVisible(fieldFinder);
    await tester.tap(fieldFinder);
    // CategoryTreePicker shows a CircularProgressIndicator (indefinite
    // animation) until its own real Isar getAll() call resolves — a bare
    // pumpAndSettle() would spin forever waiting on a real Future it
    // can't see, same reasoning as settleAfterAsyncWork everywhere else.
    await settleAfterAsyncWork(tester);
  }

  // The category name can also appear behind the open sheet (in a
  // product list item's category label), so taps inside the picker are
  // scoped to CategoryTreePicker to avoid ambiguous finders.
  Future<void> tapCategoryInPicker(WidgetTester tester, String name) async {
    await tester.tap(
      find.descendant(of: find.byType(CategoryTreePicker), matching: find.text(name)),
    );
    await settleAfterAsyncWork(tester);
  }

  testWidgets('category filter picker filters the visible list', (tester) async {
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

      await openCategoryFilterPicker(tester);
      await tapCategoryInPicker(tester, 'Drinks');

      expect(find.text('Water'), findsOneWidget);
      expect(find.text('Chips'), findsNothing);

      await openCategoryFilterPicker(tester);
      await tester.tap(find.byKey(const Key('category_picker_all')));
      await settleAfterAsyncWork(tester);

      expect(find.text('Chips'), findsOneWidget);
      expect(find.text('Water'), findsOneWidget);
    });
  });

  testWidgets('"Lainnya" filter shows only uncategorized products', (tester) async {
    await tester.runAsync(() async {
      final snacks = await categoryRepository.create('Snacks');
      await productRepository.create(
        name: 'Chips',
        categoryId: snacks.id,
        sellPrice: 5000,
        unit: 'pcs',
      );
      await productRepository.create(
        name: 'Misc Item',
        sellPrice: 3000,
        unit: 'pcs',
      );

      await pumpScreen(tester);

      await openCategoryFilterPicker(tester);
      await tester.tap(find.byKey(const Key('category_picker_uncategorized')));
      await settleAfterAsyncWork(tester);

      expect(find.text('Misc Item'), findsOneWidget);
      expect(find.text('Chips'), findsNothing);
    });
  });

  testWidgets(
    'selecting a parent category includes products tagged to its descendants',
    (tester) async {
      await tester.runAsync(() async {
        final alatTulis = await categoryRepository.create('Alat Tulis');
        final pulpen = await categoryRepository.create('Pulpen', parentId: alatTulis.id);
        final drinks = await categoryRepository.create('Drinks');
        await productRepository.create(
          name: 'Buku Tulis',
          categoryId: alatTulis.id,
          sellPrice: 3000,
          unit: 'pcs',
        );
        await productRepository.create(
          name: 'Pulpen Merah',
          categoryId: pulpen.id,
          sellPrice: 2000,
          unit: 'pcs',
        );
        await productRepository.create(
          name: 'Water',
          categoryId: drinks.id,
          sellPrice: 3000,
          unit: 'pcs',
        );

        await pumpScreen(tester);

        await openCategoryFilterPicker(tester);
        await tapCategoryInPicker(tester, 'Alat Tulis');

        expect(find.text('Buku Tulis'), findsOneWidget);
        expect(find.text('Pulpen Merah'), findsOneWidget);
        expect(find.text('Water'), findsNothing);
      });
    },
  );

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

  testWidgets(
    'recording a stock mutation elsewhere updates the displayed stock without navigating away',
    (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Snacks');
        final product = await productRepository.create(
          name: 'Chips',
          categoryId: category.id,
          sellPrice: 5000,
          unit: 'pcs',
          initialStock: 12,
        );
        final stockMutationRepository = StockMutationRepository(isar);

        await pumpScreen(tester);

        expect(find.text('12 pcs'), findsOneWidget);

        // Simulates a mutation recorded from a different, separately
        // mounted screen (e.g. Mutasi tab or Product Detail) while this
        // screen stays mounted underneath in the IndexedStack — no push/
        // pop through this screen, so it can only pick up the change via
        // its own watch subscription.
        await stockMutationRepository.recordMutation(
          productId: product.id,
          type: StockMutationType.stockIn,
          quantity: 8,
        );
        await settleAfterAsyncWork(tester);

        expect(find.text('12 pcs'), findsNothing);
        expect(find.text('20 pcs'), findsOneWidget);
      });
    },
  );

  testWidgets('typing in the search field filters the list live to matching product name', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Snacks');
      await productRepository.create(
        name: 'Indomie Goreng',
        categoryId: category.id,
        sellPrice: 3000,
        unit: 'pcs',
      );
      await productRepository.create(
        name: 'Aqua Botol',
        categoryId: category.id,
        sellPrice: 3000,
        unit: 'pcs',
      );

      await pumpScreen(tester);
      expect(find.text('Indomie Goreng'), findsOneWidget);
      expect(find.text('Aqua Botol'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('produk_search')), 'goreng');
      await settleAfterAsyncWork(tester);

      expect(find.text('Indomie Goreng'), findsOneWidget);
      expect(find.text('Aqua Botol'), findsNothing);

      // Clearing via the "x" button restores the full list.
      await tester.tap(find.byIcon(Icons.clear));
      await settleAfterAsyncWork(tester);

      expect(find.text('Indomie Goreng'), findsOneWidget);
      expect(find.text('Aqua Botol'), findsOneWidget);
    });
  });

  testWidgets('search combined with a selected category filter narrows to both constraints', (tester) async {
    await tester.runAsync(() async {
      final snacks = await categoryRepository.create('Snacks');
      final drinks = await categoryRepository.create('Drinks');
      await productRepository.create(
        name: 'Chips Original',
        categoryId: snacks.id,
        sellPrice: 5000,
        unit: 'pcs',
      );
      await productRepository.create(
        name: 'Chips Pedas',
        categoryId: snacks.id,
        sellPrice: 5000,
        unit: 'pcs',
      );
      await productRepository.create(
        name: 'Chips Water', // shares "Chips" with the snacks but is a drink
        categoryId: drinks.id,
        sellPrice: 3000,
        unit: 'pcs',
      );

      await pumpScreen(tester);

      await openCategoryFilterPicker(tester);
      await tapCategoryInPicker(tester, 'Snacks');

      expect(find.text('Chips Original'), findsOneWidget);
      expect(find.text('Chips Pedas'), findsOneWidget);
      expect(find.text('Chips Water'), findsNothing);

      await tester.enterText(find.byKey(const Key('produk_search')), 'pedas');
      await settleAfterAsyncWork(tester);

      // Same-category AND matching search only.
      expect(find.text('Chips Pedas'), findsOneWidget);
      expect(find.text('Chips Original'), findsNothing);
      expect(find.text('Chips Water'), findsNothing);
    });
  });

  testWidgets(
    'search with no matches shows "Tidak ditemukan" distinct from the no-products empty state',
    (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Snacks');
        await productRepository.create(
          name: 'Chips',
          categoryId: category.id,
          sellPrice: 5000,
          unit: 'pcs',
        );

        await pumpScreen(tester);

        await tester.enterText(find.byKey(const Key('produk_search')), 'nonexistent product');
        await settleAfterAsyncWork(tester);

        expect(find.text('Tidak ditemukan.'), findsOneWidget);
        expect(
          find.text('Belum ada produk. Tambahkan produk pertama untuk mulai.'),
          findsNothing,
        );
      });
    },
  );

  testWidgets('archived products remain excluded from search results', (tester) async {
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

      await tester.enterText(find.byKey(const Key('produk_search')), 'chips');
      await settleAfterAsyncWork(tester);

      expect(find.text('Chips'), findsNothing);
      expect(find.text('Tidak ditemukan.'), findsNothing);
      expect(
        find.text('Belum ada produk. Tambahkan produk pertama untuk mulai.'),
        findsOneWidget,
      );
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

  testWidgets(
    'adding a category elsewhere (direct repository call) auto-refreshes the filter picker '
    'without any manual trigger',
    (tester) async {
      await tester.runAsync(() async {
        await categoryRepository.create('Snacks');
        await pumpScreen(tester);
        await openCategoryFilterPicker(tester);

        expect(find.text('Snacks'), findsOneWidget);
        expect(find.text('Drinks'), findsNothing);

        // Simulates a category added from Kelola Kategori (Pengaturan
        // tab, a separately mounted screen) while this Produk tab stays
        // alive in MainScaffold's IndexedStack — exactly the case the
        // watchLazy() subscription is meant to fix.
        await categoryRepository.create('Drinks');
        await settleAfterAsyncWork(tester);

        expect(find.text('Drinks'), findsOneWidget);
      });
    },
  );
}
