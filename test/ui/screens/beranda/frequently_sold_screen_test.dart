import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/models/product.dart';
import 'package:inventaris_toko/data/models/stock_mutation.dart';
import 'package:inventaris_toko/data/repositories/app_settings_repository.dart';
import 'package:inventaris_toko/data/repositories/category_repository.dart';
import 'package:inventaris_toko/data/repositories/product_repository.dart';
import 'package:inventaris_toko/data/repositories/stock_mutation_repository.dart';
import 'package:inventaris_toko/domain/prioritas_kulakan_calculator.dart';
import 'package:inventaris_toko/ui/screens/beranda/frequently_sold_screen.dart';
import 'package:isar_community/isar.dart';

import '../../../data/repositories/test_isar.dart';
import '../../widget_test_helpers.dart';

void main() {
  group('sortFrequentlySold (pure)', () {
    Product product({required int id, required String name}) {
      return Product()
        ..id = id
        ..name = name
        ..sellPrice = 1000
        ..unit = 'pcs'
        ..currentStock = 10
        ..minStockThreshold = 5
        ..createdAt = DateTime(2026, 1, 1)
        ..updatedAt = DateTime(2026, 1, 1);
    }

    PrioritasKulakanResult result({
      required int id,
      required String name,
      required double dailyVelocity,
    }) {
      return PrioritasKulakanResult(
        product: product(id: id, name: name),
        dailyVelocity: dailyVelocity,
        dataAgeDays: 10,
        estimatedDaysRemaining: null,
        isOutOfStock: false,
        urgency: PriorityUrgency.neutral,
        suggestedRestockQty: 1,
      );
    }

    test('sorts by dailyVelocity descending', () {
      final sorted = sortFrequentlySold([
        result(id: 1, name: 'A', dailyVelocity: 2),
        result(id: 2, name: 'B', dailyVelocity: 9),
        result(id: 3, name: 'C', dailyVelocity: 5),
      ]);

      expect(sorted.map((r) => r.product.id), [2, 3, 1]);
    });

    test('ties in dailyVelocity are broken by product name ascending', () {
      final sorted = sortFrequentlySold([
        result(id: 1, name: 'Zebra', dailyVelocity: 5),
        result(id: 2, name: 'Apel', dailyVelocity: 5),
        result(id: 3, name: 'Mangga', dailyVelocity: 5),
      ]);

      expect(sorted.map((r) => r.product.name), ['Apel', 'Mangga', 'Zebra']);
    });

    test('excludes products with dailyVelocity 0', () {
      final sorted = sortFrequentlySold([
        result(id: 1, name: 'Laris', dailyVelocity: 3),
        result(id: 2, name: 'Tidak Laris', dailyVelocity: 0),
      ]);

      expect(sorted.map((r) => r.product.id), [1]);
    });
  });

  group('FrequentlySoldScreen (widget)', () {
    late Isar isar;
    late CategoryRepository categoryRepository;
    late ProductRepository productRepository;
    late StockMutationRepository stockMutationRepository;

    setUp(() async {
      isar = await openTestIsar();
      categoryRepository = CategoryRepository(isar);
      stockMutationRepository = StockMutationRepository(isar);
      productRepository = ProductRepository(
        isar,
        stockMutationRepository,
        AppSettingsRepository(isar),
      );
    });

    tearDown(() async {
      await closeTestIsar(isar);
    });

    Future<void> pumpScreen(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: FrequentlySoldScreen(isar: isar)));
      await settleAfterAsyncWork(tester);
    }

    /// The pinned search/category/chart header plus list rows can push
    /// content below the default test viewport — same lazy-building issue
    /// documented in pengaturan_screen_test.dart's
    /// scrollToCriticalStockSection. Scroll there before asserting on it.
    ///
    /// Uses a plain drag loop rather than [WidgetTester.scrollUntilVisible]:
    /// that helper finishes with `Scrollable.ensureVisible`, which doesn't
    /// account correctly for the pinned header's `maxScrollObstructionExtent`
    /// under test conditions and can leave the target scrolled back out of
    /// view.
    Future<void> scrollUntilFound(WidgetTester tester, Finder finder) async {
      final scrollable = find.byType(Scrollable).first;
      for (var i = 0; i < 30 && finder.evaluate().isEmpty; i++) {
        await tester.drag(scrollable, const Offset(0, -300));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(finder, findsOneWidget, reason: 'did not find $finder after scrolling');
    }

    /// Seeds a product with enough real stockOut history to clear
    /// [VelocityCalculator]'s confidence threshold (>= 5 mutations,
    /// spanning >= 7 days) — same approach as
    /// beranda_screen_test.dart's seedEligibleProduct.
    Future<Product> seedSoldProduct(
      int categoryId,
      String name, {
      double stockOutQuantity = 5,
      double initialStock = 100,
    }) async {
      const mutationCount = 5;
      const backdateDays = 20;

      final product = await productRepository.create(
        name: name,
        categoryId: categoryId,
        sellPrice: 1000,
        unit: 'pcs',
        initialStock: initialStock,
      );

      for (var i = 0; i < mutationCount; i++) {
        await stockMutationRepository.recordMutation(
          productId: product.id,
          type: StockMutationType.stockOut,
          quantity: stockOutQuantity,
        );
      }

      final mutations = await isar.stockMutations.filter().productIdEqualTo(product.id).findAll();
      final backdated = DateTime.now().subtract(const Duration(days: backdateDays));
      await isar.writeTxn(() async {
        for (final mutation in mutations) {
          mutation.createdAt = backdated;
        }
        await isar.stockMutations.putAll(mutations);
      });

      return product;
    }

    testWidgets('excludes archived products even if they have sales history', (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Umum');
        final active = await seedSoldProduct(category.id, 'Aktif');
        final archived = await seedSoldProduct(category.id, 'Diarsipkan');
        await productRepository.archive(archived.id);

        await pumpScreen(tester);

        expect(find.byKey(Key('frequently_sold_row_${active.id}')), findsOneWidget);
        expect(find.byKey(Key('frequently_sold_row_${archived.id}')), findsNothing);
      });
    });

    testWidgets('empty state renders when no product has sales history', (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Umum');
        await productRepository.create(
          name: 'Belum Pernah Terjual',
          categoryId: category.id,
          sellPrice: 1000,
          unit: 'pcs',
          initialStock: 10,
        );

        await pumpScreen(tester);

        expect(find.byKey(const Key('frequently_sold_empty_state')), findsOneWidget);
        expect(find.text('Belum ada riwayat penjualan'), findsOneWidget);
        expect(find.byKey(const Key('frequently_sold_full_list')), findsNothing);
      });
    });

    testWidgets('shows page caption explaining the metric', (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Umum');
        await seedSoldProduct(category.id, 'Kopi');

        await pumpScreen(tester);

        expect(find.byKey(const Key('frequently_sold_page_caption')), findsOneWidget);
      });
    });

    testWidgets('chart shows only the top 7 by velocity, list still shows all', (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Umum');
        final products = <Product>[];
        for (var i = 1; i <= 9; i++) {
          products.add(
            await seedSoldProduct(
              category.id,
              'Produk $i',
              stockOutQuantity: i.toDouble(),
              initialStock: 999,
            ),
          );
        }

        await pumpScreen(tester);

        expect(find.byKey(const Key('frequently_sold_chart')), findsOneWidget);
        // Higher stockOutQuantity ("Produk 9" down to "Produk 3") means
        // higher dailyVelocity, so those are the top 7 bars.
        for (var i = 9; i >= 3; i--) {
          expect(
            find.byKey(Key('frequently_sold_chart_bar_${products[i - 1].id}')),
            findsOneWidget,
          );
        }
        expect(
          find.byKey(Key('frequently_sold_chart_bar_${products[0].id}')),
          findsNothing,
        );
        expect(
          find.byKey(Key('frequently_sold_chart_bar_${products[1].id}')),
          findsNothing,
        );

        // The two lowest-velocity products are still in the full list below
        // (scrolled past the chart and the higher-ranked rows above them).
        await scrollUntilFound(tester, find.byKey(Key('frequently_sold_row_${products[0].id}')));
        expect(find.byKey(Key('frequently_sold_row_${products[0].id}')), findsOneWidget);
        expect(find.byKey(Key('frequently_sold_row_${products[1].id}')), findsOneWidget);
      });
    });

    testWidgets('list caps at 20 items in the default view, with an explanatory caption',
        (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Umum');
        final products = <Product>[];
        for (var i = 1; i <= 22; i++) {
          products.add(
            await seedSoldProduct(
              category.id,
              'Produk $i',
              stockOutQuantity: i.toDouble(),
              initialStock: 999,
            ),
          );
        }

        await pumpScreen(tester);

        await scrollUntilFound(
          tester,
          find.byKey(const Key('frequently_sold_list_limit_caption')),
        );
        expect(find.byKey(const Key('frequently_sold_list_limit_caption')), findsOneWidget);
        expect(find.textContaining('Menampilkan 20 dari 22 produk'), findsOneWidget);

        // The two lowest-velocity products fall outside the top-20 cap —
        // scrolling to the end of the list can't surface them because
        // they were never included in its data in the first place.
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -5000));
        await tester.pumpAndSettle();
        expect(find.byKey(Key('frequently_sold_row_${products[0].id}')), findsNothing);
        expect(find.byKey(Key('frequently_sold_row_${products[1].id}')), findsNothing);
      });
    });

    testWidgets('the 20-item cap and its caption do not apply while searching', (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Umum');
        for (var i = 1; i <= 22; i++) {
          await seedSoldProduct(
            category.id,
            'Produk $i',
            stockOutQuantity: i.toDouble(),
            initialStock: 999,
          );
        }

        await pumpScreen(tester);
        await scrollUntilFound(
          tester,
          find.byKey(const Key('frequently_sold_list_limit_caption')),
        );
        expect(find.byKey(const Key('frequently_sold_list_limit_caption')), findsOneWidget);

        // Scroll back up — the caption check above scrolled the search
        // field itself off-screen.
        await tester.drag(find.byType(CustomScrollView), const Offset(0, 5000));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('frequently_sold_search')), 'Produk');
        await settleAfterAsyncWork(tester);

        expect(find.byKey(const Key('frequently_sold_list_limit_caption')), findsNothing);
      });
    });

    testWidgets('search field filters the visible list by name', (tester) async {
      await tester.runAsync(() async {
        // Both products qualify for the chart's top-7 too, so a bare
        // find.text() would match the chart's bar label as well as the
        // list row below it — scope to the list specifically.
        Finder inList(String text) => find.descendant(
              of: find.byKey(const Key('frequently_sold_full_list')),
              matching: find.text(text),
            );

        final category = await categoryRepository.create('Umum');
        await seedSoldProduct(category.id, 'Kopi Kapal Api');
        await seedSoldProduct(category.id, 'Teh Botol');

        await pumpScreen(tester);

        expect(inList('Kopi Kapal Api'), findsOneWidget);
        expect(inList('Teh Botol'), findsOneWidget);

        await tester.enterText(find.byKey(const Key('frequently_sold_search')), 'Kopi');
        await settleAfterAsyncWork(tester);

        expect(inList('Kopi Kapal Api'), findsOneWidget);
        expect(inList('Teh Botol'), findsNothing);
      });
    });
  });
}
