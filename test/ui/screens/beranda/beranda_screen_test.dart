import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/models/product.dart';
import 'package:inventaris_toko/data/models/stock_mutation.dart';
import 'package:inventaris_toko/data/repositories/app_settings_repository.dart';
import 'package:inventaris_toko/data/repositories/category_repository.dart';
import 'package:inventaris_toko/data/repositories/product_repository.dart';
import 'package:inventaris_toko/data/repositories/stock_mutation_repository.dart';
import 'package:inventaris_toko/ui/screens/beranda/beranda_screen.dart';
import 'package:isar_community/isar.dart';

import '../../../data/repositories/test_isar.dart';
import '../../widget_test_helpers.dart';

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

  /// A product with exactly one stockOut mutation recorded "now" always
  /// has a 1-day divisor (see PrioritasKulakanCalculator), so its
  /// dailyVelocity equals [stockOutQuantity] and its estimated days
  /// remaining is simply currentStock ÷ stockOutQuantity. Choosing
  /// [initialStock] as `stockOutQuantity * (targetDays + 1)` lands the
  /// post-mutation currentStock at exactly `stockOutQuantity *
  /// targetDays`, giving predictable, easy-to-reason-about day counts
  /// for fixture products.
  Future<Product> seedEligibleProduct(
    int categoryId,
    String name,
    int targetDays, {
    double stockOutQuantity = 5,
  }) async {
    final product = await productRepository.create(
      name: name,
      categoryId: categoryId,
      sellPrice: 1000,
      unit: 'pcs',
      initialStock: stockOutQuantity * (targetDays + 1),
    );
    await stockMutationRepository.recordMutation(
      productId: product.id,
      type: StockMutationType.stockOut,
      quantity: stockOutQuantity,
    );
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

      // Only the 5 most urgent (1..5 hari) are in the preview.
      expect(find.text('Produk 1 Hari'), findsOneWidget);
      expect(find.text('Produk 5 Hari'), findsOneWidget);
      expect(find.text('Produk 6 Hari'), findsNothing);
      expect(find.text('Produk 10 Hari'), findsNothing);

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

  testWidgets('"Lihat semua" navigates to the full Prioritas Kulakan screen', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Umum');
      await seedEligibleProduct(category.id, 'Produk 1 Hari', 1);

      await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('beranda_lihat_semua_button')));
      await settleAfterAsyncWork(tester);

      expect(find.widgetWithText(AppBar, 'Prioritas Kulakan'), findsOneWidget);
      expect(find.byKey(const Key('prioritas_kulakan_list')), findsOneWidget);
    });
  });
}
