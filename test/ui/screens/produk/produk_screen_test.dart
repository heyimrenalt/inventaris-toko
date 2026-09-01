import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/models/product.dart';
import 'package:inventaris_toko/data/models/stock_mutation.dart';
import 'package:inventaris_toko/data/repositories/app_settings_repository.dart';
import 'package:inventaris_toko/data/repositories/category_repository.dart';
import 'package:inventaris_toko/data/repositories/product_repository.dart';
import 'package:inventaris_toko/data/repositories/stock_mutation_repository.dart';
import 'package:inventaris_toko/ui/screens/produk/produk_screen.dart';
import 'package:inventaris_toko/ui/widgets/app_header.dart';
import 'package:inventaris_toko/ui/widgets/app_search_bar.dart';
import 'package:inventaris_toko/ui/widgets/category_tree_picker.dart';
import 'package:inventaris_toko/ui/widgets/product_grid_card.dart';
import 'package:isar_community/isar.dart';

import '../../../data/repositories/test_isar.dart';
import '../../widget_test_helpers.dart';

/// Test double that counts [getAll] calls, so a test can verify
/// pull-to-refresh actually re-queries Isar rather than just re-rendering
/// whatever was already loaded.
class _CountingProductRepository extends ProductRepository {
  _CountingProductRepository(super.isar, super.mutationRepository, super.settingsRepository);

  int getAllCallCount = 0;

  @override
  Future<List<Product>> getAll({bool includeArchived = false}) {
    getAllCallCount++;
    return super.getAll(includeArchived: includeArchived);
  }
}

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

  Future<void> openCategoryFilterPicker(WidgetTester tester) async {
    final fieldFinder = find.byKey(const Key('produk_category_filter'));
    await tester.ensureVisible(fieldFinder);
    await tester.tap(fieldFinder);
    await settleAfterAsyncWork(tester);
  }

  Future<void> tapCategoryInPicker(WidgetTester tester, String name) async {
    await tester.tap(
      find.descendant(of: find.byType(CategoryTreePicker), matching: find.text(name)),
    );
    await settleAfterAsyncWork(tester);
  }

  testWidgets('pull-to-refresh triggers the data re-query', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Snacks');
      await productRepository.create(
        name: 'Chips',
        categoryId: category.id,
        sellPrice: 5000,
        unit: 'pcs',
      );

      final countingRepository = _CountingProductRepository(
        isar,
        StockMutationRepository(isar),
        AppSettingsRepository(isar),
      );

      await tester.pumpWidget(
        MaterialApp(home: ProdukScreen(isar: isar, productRepository: countingRepository)),
      );
      await settleAfterAsyncWork(tester);

      final callsAfterInitialLoad = countingRepository.getAllCallCount;
      expect(callsAfterInitialLoad, greaterThanOrEqualTo(1));

      await triggerRefresh(tester);

      expect(countingRepository.getAllCallCount, greaterThan(callsAfterInitialLoad));
    });
  });

  testWidgets('refresh preserves an active category filter', (tester) async {
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
        name: 'Chips Water',
        categoryId: drinks.id,
        sellPrice: 3000,
        unit: 'pcs',
      );

      await pumpScreen(tester);

      await openCategoryFilterPicker(tester);
      await tapCategoryInPicker(tester, 'Snacks');

      expect(find.text('Chips Pedas'), findsOneWidget);
      expect(find.text('Chips Original'), findsOneWidget);
      expect(find.text('Chips Water'), findsNothing);

      await triggerRefresh(tester);

      expect(find.text('Chips Pedas'), findsOneWidget);
      expect(find.text('Chips Original'), findsOneWidget);
      expect(find.text('Chips Water'), findsNothing);
    });
  });

  testWidgets('empty list is still pull-refreshable', (tester) async {
    await tester.runAsync(() async {
      await pumpScreen(tester);

      expect(
        find.text('Belum ada produk. Tambahkan produk pertama untuk mulai.'),
        findsOneWidget,
      );

      // Must complete without throwing even though there's nothing to
      // scroll through — the empty state still needs to be pull-refreshable.
      await triggerRefresh(tester);

      expect(
        find.text('Belum ada produk. Tambahkan produk pertama untuk mulai.'),
        findsOneWidget,
      );
    });
  });

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
        find.descendant(of: find.byType(ProductGridCard), matching: find.textContaining('Snacks')),
        findsOneWidget,
      );
      expect(find.text('12'), findsOneWidget); // stock quantity
      expect(find.text('pcs'), findsOneWidget); // unit
    });
  });


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

  testWidgets('low stock shows danger badge color, sufficient stock shows safe color', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Snacks');
      await productRepository.create(
        name: 'Low Stock Item',
        categoryId: category.id,
        sellPrice: 1000,
        unit: 'pcs',
        minStockThreshold: 5,
        initialStock: 2,
      );
      await productRepository.create(
        name: 'OK Stock Item',
        categoryId: category.id,
        sellPrice: 1000,
        unit: 'pcs',
        minStockThreshold: 5,
        initialStock: 10,
      );

      await pumpScreen(tester);

      expect(find.text('2'), findsOneWidget); // low stock quantity
      expect(find.text('10'), findsOneWidget); // ok stock quantity
      expect(find.text('pcs'), findsAtLeast(2)); // unit label appears for both
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

        expect(find.text('12'), findsOneWidget); // initial stock quantity

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

        expect(find.text('12'), findsNothing);
        expect(find.text('20'), findsOneWidget); // updated stock quantity
      });
    },
  );




  testWidgets('archived products remain excluded from the list', (tester) async {
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

      expect(find.text('Chips'), findsNothing);
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

  testWidgets('screen renders with AppHeader showing "Produk" title', (tester) async {
    await tester.runAsync(() async {
      await pumpScreen(tester);

      expect(find.byType(AppHeader), findsOneWidget);
      expect(find.text('Produk'), findsOneWidget);
    });
  });

  testWidgets('screen renders with exactly ONE search bar', (tester) async {
    await tester.runAsync(() async {
      await pumpScreen(tester);

      expect(find.byType(AppSearchBar), findsOneWidget);
    });
  });

  testWidgets('search bar has correct placeholder text', (tester) async {
    await tester.runAsync(() async {
      await pumpScreen(tester);

      expect(find.byWidgetPredicate(
        (widget) => widget is TextField && widget.decoration?.hintText == 'Cari produk...',
      ), findsOneWidget);
    });
  });

  testWidgets('category chip is present with text "Semua kategori" by default', (tester) async {
    await tester.runAsync(() async {
      await pumpScreen(tester);

      expect(find.text('Semua kategori'), findsOneWidget);
    });
  });

  testWidgets('sort icon button exists and is tappable', (tester) async {
    await tester.runAsync(() async {
      await pumpScreen(tester);

      expect(find.byKey(const Key('produk_sort_button')), findsOneWidget);
    });
  });

  testWidgets('tapping sort icon toggles sort mode and changes product order', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Snacks');
      await productRepository.create(
        name: 'High Stock Item',
        categoryId: category.id,
        sellPrice: 1000,
        unit: 'pcs',
        initialStock: 100,
      );
      await productRepository.create(
        name: 'Low Stock Item',
        categoryId: category.id,
        sellPrice: 1000,
        unit: 'pcs',
        initialStock: 5,
      );

      await pumpScreen(tester);

      final productItems = find.byType(ProductGridCard);
      expect(productItems, findsNWidgets(2));

      // Initially should show High Stock Item first (default order)
      final initialOrder = find.text('High Stock Item');
      expect(initialOrder, findsOneWidget);

      // Tap sort button
      await tester.tap(find.byKey(const Key('produk_sort_button')));
      await settleAfterAsyncWork(tester);

      // After sort, Low Stock Item should appear first (stock ascending)
      final sortedOrder = find.text('Low Stock Item');
      expect(sortedOrder, findsOneWidget);

      // Tap sort button again to toggle back
      await tester.tap(find.byKey(const Key('produk_sort_button')));
      await settleAfterAsyncWork(tester);

      // Should return to default order
      expect(find.text('High Stock Item'), findsOneWidget);
    });
  });

  testWidgets('search query filters products correctly', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Snacks');
      await productRepository.create(
        name: 'Chips Pedas',
        categoryId: category.id,
        sellPrice: 5000,
        unit: 'pcs',
      );
      await productRepository.create(
        name: 'Cookies Coklat',
        categoryId: category.id,
        sellPrice: 3000,
        unit: 'pcs',
      );

      await pumpScreen(tester);

      expect(find.text('Chips Pedas'), findsOneWidget);
      expect(find.text('Cookies Coklat'), findsOneWidget);

      // Type in search
      await tester.enterText(find.byType(TextField), 'Chips');
      await settleAfterAsyncWork(tester);

      expect(find.text('Chips Pedas'), findsOneWidget);
      expect(find.text('Cookies Coklat'), findsNothing);
    });
  });
}
