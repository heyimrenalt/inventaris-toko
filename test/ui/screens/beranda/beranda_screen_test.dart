import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/models/product.dart';
import 'package:inventaris_toko/data/models/stock_mutation.dart';
import 'package:inventaris_toko/data/repositories/app_settings_repository.dart';
import 'package:inventaris_toko/data/repositories/category_repository.dart';
import 'package:inventaris_toko/data/repositories/product_repository.dart';
import 'package:inventaris_toko/data/repositories/stock_mutation_repository.dart';
import 'package:inventaris_toko/domain/velocity_calculator.dart';
import 'package:inventaris_toko/ui/screens/beranda/beranda_screen.dart';
import 'package:inventaris_toko/ui/widgets/app_header.dart';
import 'package:inventaris_toko/ui/widgets/product_search_bar.dart';
import 'package:isar_community/isar.dart';

import '../../../data/repositories/test_isar.dart';
import '../../widget_test_helpers.dart';

/// Test double that counts [getAll] calls, so a test can verify
/// pull-to-refresh actually re-queries Isar (and so recomputes the
/// Prioritas Kulakan / Sering Keluar figures) rather than just
/// re-rendering whatever was already loaded.
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
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('id')],
      home: BerandaScreen(isar: isar),
    ));
    await settleAfterAsyncWork(tester);
  }

  /// [recordMutation] always stamps `DateTime.now()`, so this records
  /// [mutationCount] mutations and then backdates them directly, all to
  /// the same date [_backdateDays] days ago — comfortably inside
  /// [VelocityCalculator.recentWindowDays] (so the mutations are never at
  /// risk of falling just outside the recent window due to the real
  /// wall-clock time elapsing between seeding and the screen's own
  /// `DateTime.now()` call in [_load]). With every mutation on the same
  /// day, `dailyVelocity` is a clean, precomputable blend of the recent
  /// and all-time components (mirroring [VelocityCalculator]'s exact
  /// formula), so choosing [initialStock] so post-mutation currentStock
  /// equals `targetDays * dailyVelocity` still gives a predictable
  /// estimated-days-remaining for fixture products.
  Future<Product> seedEligibleProduct(
    int categoryId,
    String name,
    int targetDays, {
    double stockOutQuantity = 5,
  }) async {
    const mutationCount = 5;
    const backdateDays = 20;
    final totalConsumed = mutationCount * stockOutQuantity;
    final velocity30d = totalConsumed / VelocityCalculator.recentWindowDays;
    final velocityAllTime = totalConsumed / backdateDays;
    final dailyVelocity = velocity30d * VelocityCalculator.recentWeight +
        velocityAllTime * VelocityCalculator.allTimeWeight;
    final targetCurrentStock = targetDays * dailyVelocity;

    final product = await productRepository.create(
      name: name,
      categoryId: categoryId,
      sellPrice: 1000,
      unit: 'pcs',
      initialStock: targetCurrentStock + totalConsumed,
      // The velocity math above produces a fractional currentStock/qty
      // by construction — this fixture isn't exercising the
      // whole-quantity feature, so it opts out of the new default
      // enforcement rather than fighting it.
      allowsFractionalQuantity: true,
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

  testWidgets('summary cards show correct counts', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Umum');

      // 6 eligible products in the red/yellow range (<= 7 days).
      for (var days = 1; days <= 6; days++) {
        await seedEligibleProduct(category.id, 'Produk $days Hari', days);
      }
      // 1 eligible product in the neutral range (> 7 days) — counts
      // toward Total Produk but not Perlu Kulakan.
      await seedEligibleProduct(category.id, 'Produk 10 Hari', 10);
      // 1 product with no stockOut history at all — not eligible for
      // the priority calculation, but still counts toward Total Produk.
      await productRepository.create(
        name: 'Produk Tanpa Riwayat',
        categoryId: category.id,
        sellPrice: 1000,
        unit: 'pcs',
        initialStock: 20,
      );
      // An archived product — must be excluded from both counts.
      final archived = await productRepository.create(
        name: 'Produk Arsip',
        categoryId: category.id,
        sellPrice: 1000,
        unit: 'pcs',
        initialStock: 20,
      );
      await productRepository.archive(archived.id);

      await pumpScreen(tester);

      expect(
        find.descendant(
          of: find.byKey(const Key('beranda_summary_total_produk')),
          matching: find.text('8'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('beranda_summary_perlu_kulakan')),
          matching: find.text('6'),
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('priority preview shows at most 5 items, most urgent first', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Umum');

      final products = <int, Product>{};
      for (var days = 1; days <= 6; days++) {
        products[days] = await seedEligibleProduct(category.id, 'Produk $days Hari', days);
      }
      products[10] = await seedEligibleProduct(category.id, 'Produk 10 Hari', 10);

      await pumpScreen(tester);

      expect(find.byKey(const Key('beranda_priority_preview_list')), findsOneWidget);

      // Scoped to the priority preview list specifically — every seeded
      // product here shares the same velocity (default stockOutQuantity),
      // so several of them are equally likely to also appear in the
      // separate "Sering keluar" section, which an unscoped find.text
      // would double-count.
      Finder inPreview(String text) => find.descendant(
            of: find.byKey(const Key('beranda_priority_preview_list')),
            matching: find.text(text),
          );

      // Only the 5 most urgent (1..5 hari) are in the preview.
      expect(inPreview('Produk 1 Hari'), findsOneWidget);
      expect(inPreview('Produk 5 Hari'), findsOneWidget);
      expect(inPreview('Produk 6 Hari'), findsNothing);
      expect(inPreview('Produk 10 Hari'), findsNothing);

      // The most urgent card is positioned to the left of a less urgent
      // one in the horizontal-scroll preview.
      final card1 = find.byKey(Key('priority_card_${products[1]!.id}'));
      final card5 = find.byKey(Key('priority_card_${products[5]!.id}'));
      expect(tester.getTopLeft(card1).dx, lessThan(tester.getTopLeft(card5).dx));
    });
  });

  testWidgets('shows empty state when there is no eligible sales data', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Umum');
      await productRepository.create(
        name: 'Produk Tanpa Riwayat',
        categoryId: category.id,
        sellPrice: 1000,
        unit: 'pcs',
        initialStock: 10,
      );

      await pumpScreen(tester);

      expect(find.byKey(const Key('beranda_priority_empty_state')), findsOneWidget);
      expect(
        find.text(
          'Belum ada data penjualan untuk dihitung. Catat beberapa mutasi '
          'stok keluar dulu.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('beranda_lihat_semua_button')), findsNothing);
    });
  });

  testWidgets('search shows matching products as the user types, excluding archived ones',
      (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Umum');
      await productRepository.create(
        name: 'Kopi Kapal Api',
        categoryId: category.id,
        sellPrice: 1000,
        unit: 'pcs',
      );
      final archived = await productRepository.create(
        name: 'Kopi Luwak',
        categoryId: category.id,
        sellPrice: 1000,
        unit: 'pcs',
      );
      await productRepository.archive(archived.id);

      await pumpScreen(tester);

      expect(find.byKey(const Key('beranda_search_results')), findsNothing);

      await tester.enterText(find.byKey(const Key('beranda_search_field')), 'Kopi');
      await settleAfterAsyncWork(tester);

      expect(find.byKey(const Key('beranda_search_results')), findsOneWidget);
      expect(find.text('Kopi Kapal Api'), findsOneWidget);
      expect(find.text('Kopi Luwak'), findsNothing);
    });
  });

  testWidgets('search field has no colored border in enabled or focused state', (tester) async {
    await tester.runAsync(() async {
      await pumpScreen(tester);

      final decorationTheme =
          Theme.of(tester.element(find.byKey(const Key('beranda_search_field'))))
              .inputDecorationTheme;

      // Every state must be an explicit no-border — leaving any of these
      // unset lets Material derive a default that tints the outline with
      // the theme's primary color on focus (the "green ring" bug).
      expect(decorationTheme.border, equals(InputBorder.none));
      expect(decorationTheme.enabledBorder, equals(InputBorder.none));
      expect(decorationTheme.focusedBorder, equals(InputBorder.none));
      expect(decorationTheme.errorBorder, equals(InputBorder.none));
      expect(decorationTheme.focusedErrorBorder, equals(InputBorder.none));
      expect(decorationTheme.disabledBorder, equals(InputBorder.none));

      // Actually focus it — this must not throw or change the resolved
      // border theme (i.e. no separate focus-only border path kicks in).
      await tester.tap(find.byKey(const Key('beranda_search_field')));
      await settleAfterAsyncWork(tester);
      expect(find.byKey(const Key('beranda_search_field')), findsOneWidget);
    });
  });

  testWidgets('Beranda renders exactly one search bar, not a duplicate', (tester) async {
    await tester.runAsync(() async {
      await pumpScreen(tester);

      expect(find.byType(ProductSearchBar), findsOneWidget);
      expect(find.byKey(const Key('beranda_search_field')), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  testWidgets('search results dropdown is anchored below the search field, not at screen top',
      (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Umum');
      await productRepository.create(
        name: 'Kopi Kapal Api',
        categoryId: category.id,
        sellPrice: 1000,
        unit: 'pcs',
      );

      await pumpScreen(tester);

      await tester.enterText(find.byKey(const Key('beranda_search_field')), 'Kopi');
      await settleAfterAsyncWork(tester);

      final fieldBottom = tester.getBottomLeft(find.byKey(const Key('beranda_search_field'))).dy;
      final resultsTop = tester.getTopLeft(find.byKey(const Key('beranda_search_results'))).dy;

      // The dropdown must sit at (or below) the field's own bottom edge —
      // never above it, which is what the header-overlap bug looked like.
      expect(resultsTop, greaterThanOrEqualTo(fieldBottom));
    });
  });

  testWidgets('summary cards render at exactly the same height', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Umum');
      // Different digit counts between the two counts (1 vs 3 digits) is
      // exactly the kind of content difference that could otherwise make
      // one card taller than the other.
      for (var days = 1; days <= 6; days++) {
        await seedEligibleProduct(category.id, 'Produk $days Hari', days);
      }
      for (var i = 0; i < 94; i++) {
        await productRepository.create(
          name: 'Produk Tanpa Riwayat $i',
          categoryId: category.id,
          sellPrice: 1000,
          unit: 'pcs',
          initialStock: 20,
        );
      }

      await pumpScreen(tester);

      final totalHeight =
          tester.getSize(find.byKey(const Key('beranda_summary_total_produk'))).height;
      final perluHeight =
          tester.getSize(find.byKey(const Key('beranda_summary_perlu_kulakan'))).height;

      expect(totalHeight, equals(perluHeight));
    });
  });

  testWidgets('no QR/barcode scan icon exists anywhere on Beranda', (tester) async {
    await tester.runAsync(() async {
      await pumpScreen(tester);

      expect(find.byIcon(Icons.qr_code_scanner), findsNothing);
    });
  });

  testWidgets('"Lihat semua" navigates to the full Prioritas Kulakan screen', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Umum');
      await seedEligibleProduct(category.id, 'Produk 1 Hari', 1);

      await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('beranda_lihat_semua_button')));
      await settleAfterAsyncWork(tester);

      expect(find.widgetWithText(AppHeader, 'Prioritas Kulakan'), findsOneWidget);
      expect(find.byKey(const Key('prioritas_kulakan_list')), findsOneWidget);
    });
  });

  testWidgets('"Sering keluar" section appears when there are eligible products with sales history',
      (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Umum');
      await seedEligibleProduct(category.id, 'Produk 1 Hari', 1);

      await pumpScreen(tester);

      expect(find.text('Sering keluar'), findsOneWidget);
      expect(find.byKey(const Key('beranda_frequently_sold_list')), findsOneWidget);
    });
  });

  testWidgets('"Sering keluar" ranks products by highest daily velocity, not urgency',
      (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Umum');
      // Low velocity (1/day) but urgent (2 days left) — should rank behind
      // the high-velocity product in "Sering keluar" despite being first
      // in "Prioritas Kulakan".
      final urgentButSlow = await seedEligibleProduct(
        category.id,
        'Lambat',
        2,
        stockOutQuantity: 1,
      );
      final fastSeller = await seedEligibleProduct(
        category.id,
        'Laris',
        20,
        stockOutQuantity: 10,
      );

      await pumpScreen(tester);

      final fastCard = find.byKey(Key('frequently_sold_card_${fastSeller.id}'));
      final slowCard = find.byKey(Key('frequently_sold_card_${urgentButSlow.id}'));
      expect(fastCard, findsOneWidget);
      expect(slowCard, findsOneWidget);
      expect(tester.getTopLeft(fastCard).dx, lessThan(tester.getTopLeft(slowCard).dx));
    });
  });

  testWidgets('"Sering keluar" section is hidden when no products have sales history',
      (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Umum');
      await productRepository.create(
        name: 'Produk Tanpa Riwayat',
        categoryId: category.id,
        sellPrice: 1000,
        unit: 'pcs',
        initialStock: 10,
      );

      await pumpScreen(tester);

      expect(find.text('Sering keluar'), findsNothing);
      expect(find.byKey(const Key('beranda_frequently_sold_list')), findsNothing);
    });
  });

  testWidgets('"Sering keluar" section\'s "Lihat semua" opens the full Sering Keluar list',
      (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Umum');
      final product = await seedEligibleProduct(category.id, 'Produk 1 Hari', 1);

      await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('beranda_frequently_sold_lihat_semua_button')));
      await settleAfterAsyncWork(tester);

      expect(find.widgetWithText(AppHeader, 'Sering Keluar'), findsOneWidget);
      expect(find.byKey(Key('frequently_sold_row_${product.id}')), findsOneWidget);
    });
  });

  testWidgets(
    'pull-to-refresh re-queries products, recomputing Prioritas Kulakan/Sering Keluar',
    (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Umum');
        await seedEligibleProduct(category.id, 'Produk 1 Hari', 1);

        final countingRepository = _CountingProductRepository(
          isar,
          stockMutationRepository,
          AppSettingsRepository(isar),
        );

        await tester.pumpWidget(MaterialApp(
          locale: const Locale('id'),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('id')],
          home: BerandaScreen(isar: isar, productRepository: countingRepository),
        ));
        await settleAfterAsyncWork(tester);

        final callsAfterInitialLoad = countingRepository.getAllCallCount;
        expect(callsAfterInitialLoad, greaterThanOrEqualTo(1));

        await triggerRefresh(tester);

        // A second getAll() call means _load() re-ran end to end, which is
        // exactly what recomputes the priority/frequently-sold figures —
        // both are derived from that same product list on every _load().
        expect(countingRepository.getAllCallCount, greaterThan(callsAfterInitialLoad));
      });
    },
  );

  testWidgets('empty state (no sales data) is still pull-refreshable', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Umum');
      await productRepository.create(
        name: 'Produk Tanpa Riwayat',
        categoryId: category.id,
        sellPrice: 1000,
        unit: 'pcs',
        initialStock: 10,
      );

      await pumpScreen(tester);
      expect(find.byKey(const Key('beranda_priority_empty_state')), findsOneWidget);

      // Must complete without throwing even with nothing to scroll far
      // through.
      await triggerRefresh(tester);

      expect(find.byKey(const Key('beranda_priority_empty_state')), findsOneWidget);
    });
  });
}
