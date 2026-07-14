import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/models/product.dart';
import 'package:inventaris_toko/data/models/stock_mutation.dart';
import 'package:inventaris_toko/data/repositories/app_settings_repository.dart';
import 'package:inventaris_toko/data/repositories/category_repository.dart';
import 'package:inventaris_toko/data/repositories/product_repository.dart';
import 'package:inventaris_toko/data/repositories/stock_mutation_repository.dart';
import 'package:inventaris_toko/domain/prioritas_kulakan_calculator.dart';
import 'package:inventaris_toko/ui/screens/beranda/prioritas_kulakan_screen.dart';
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
      home: PrioritasKulakanScreen(isar: isar),
    ));
    await settleAfterAsyncWork(tester);
  }

  // Same construction as PrioritasKulakanCalculator's own test suite: a
  // single stockOut mutation of [stockOutQuantity] always uses a 1-day
  // velocity divisor, so choosing initialStock as
  // `stockOutQuantity * (targetDays + 1)` lands the post-mutation
  // currentStock at exactly `stockOutQuantity * targetDays`, giving a
  // predictable estimatedDaysRemaining of exactly [targetDays].
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

  testWidgets('"Bagikan" and "Salin teks" buttons are visible on the full screen', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Umum');
      await seedEligibleProduct(category.id, 'Produk 1 Hari', 1);

      await pumpScreen(tester);

      expect(find.byKey(const Key('kulakan_share_button')), findsOneWidget);
      expect(find.byKey(const Key('kulakan_copy_button')), findsOneWidget);
    });
  });

  testWidgets('red/yellow urgency items are checked by default, neutral items are unchecked',
      (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Umum');
      final red = await seedEligibleProduct(category.id, 'Produk Merah', 1);
      final yellow = await seedEligibleProduct(category.id, 'Produk Kuning', 5);
      final neutral = await seedEligibleProduct(category.id, 'Produk Netral', 10);

      await pumpScreen(tester);

      Checkbox checkboxFor(Product product) =>
          tester.widget<Checkbox>(find.byKey(Key('kulakan_checkbox_${product.id}')));

      expect(checkboxFor(red).value, isTrue);
      expect(checkboxFor(yellow).value, isTrue);
      expect(checkboxFor(neutral).value, isFalse);
    });
  });

  testWidgets('toggling a checkbox changes its state', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Umum');
      final product = await seedEligibleProduct(category.id, 'Produk 1 Hari', 1);

      await pumpScreen(tester);

      final checkboxKey = Key('kulakan_checkbox_${product.id}');
      expect(tester.widget<Checkbox>(find.byKey(checkboxKey)).value, isTrue);

      await tester.tap(find.byKey(checkboxKey));
      await settleAfterAsyncWork(tester);
      expect(tester.widget<Checkbox>(find.byKey(checkboxKey)).value, isFalse);

      await tester.tap(find.byKey(checkboxKey));
      await settleAfterAsyncWork(tester);
      expect(tester.widget<Checkbox>(find.byKey(checkboxKey)).value, isTrue);
    });
  });

  testWidgets('"Salin teks" copies the formatted shopping list to the clipboard', (tester) async {
    await tester.runAsync(() async {
      // flutter_test doesn't mock the platform clipboard channel by
      // default (unlike some other plugin channels), so Clipboard.setData
      // is intercepted here and the argument it was called with captured
      // directly, rather than relying on a round-trip through
      // Clipboard.getData.
      String? capturedText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            capturedText = (methodCall.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      final category = await categoryRepository.create('Umum');
      await seedEligibleProduct(category.id, 'Gula Pasir 1kg', 1);

      await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('kulakan_copy_button')));
      await settleAfterAsyncWork(tester);

      expect(find.text('Teks disalin ke clipboard'), findsOneWidget);
      expect(capturedText, contains('Daftar Belanja Kulakan'));
      expect(capturedText, contains('✓ Gula Pasir 1kg — '));
      expect(capturedText, contains('Total: 1 barang'));
    });
  });

  testWidgets('the share/copy buttons are disabled when nothing is checked', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Umum');
      final product = await seedEligibleProduct(category.id, 'Produk 1 Hari', 1);

      await pumpScreen(tester);

      await tester.tap(find.byKey(Key('kulakan_checkbox_${product.id}')));
      await settleAfterAsyncWork(tester);

      final shareButton =
          tester.widget<IconButton>(find.byKey(const Key('kulakan_share_button')));
      final copyButton = tester.widget<IconButton>(find.byKey(const Key('kulakan_copy_button')));
      expect(shareButton.onPressed, isNull);
      expect(copyButton.onPressed, isNull);
    });
  });

  Product buildProduct({
    required int id,
    required String name,
    required double currentStock,
    String unit = 'pcs',
  }) {
    final now = DateTime(2026, 7, 14);
    return Product()
      ..id = id
      ..name = name
      ..categoryId = 1
      ..sellPrice = 1000
      ..unit = unit
      ..currentStock = currentStock
      ..minStockThreshold = 5
      ..createdAt = now
      ..updatedAt = now;
  }

  PrioritasKulakanResult buildResult({
    required Product product,
    required double dailyVelocity,
    required PriorityUrgency urgency,
    required int suggestedRestockQty,
  }) {
    return PrioritasKulakanResult(
      product: product,
      dailyVelocity: dailyVelocity,
      estimatedDaysRemaining: 5,
      isOutOfStock: false,
      urgency: urgency,
      suggestedRestockQty: suggestedRestockQty,
    );
  }

  test('buildKulakanShareText includes only checked items, with correct suggested quantities', () {
    final gula = buildProduct(id: 1, name: 'Gula Pasir 1kg', currentStock: 4);
    final kopi = buildProduct(id: 2, name: 'Kopi Kapal Api', currentStock: 2);
    final beras = buildProduct(id: 3, name: 'Beras Premium 5kg', currentStock: 10);

    final results = [
      buildResult(product: gula, dailyVelocity: 2, urgency: PriorityUrgency.red, suggestedRestockQty: 10),
      buildResult(product: kopi, dailyVelocity: 1, urgency: PriorityUrgency.red, suggestedRestockQty: 6),
      buildResult(
        product: beras,
        dailyVelocity: 3,
        urgency: PriorityUrgency.yellow,
        suggestedRestockQty: 15,
      ),
    ];

    final text = buildKulakanShareText(
      results: results,
      checkedProductIds: {1, 2},
      now: DateTime(2026, 7, 14),
    );

    expect(text, contains('Daftar Belanja Kulakan'));
    expect(text, contains('Toko Mama · 14 Juli 2026'));
    expect(text, contains('✓ Gula Pasir 1kg — 10 pcs'));
    expect(text, contains('✓ Kopi Kapal Api — 6 pcs'));
    expect(text, isNot(contains('Beras Premium')));
    expect(text, contains('Total: 2 barang'));
  });

  test('buildKulakanShareText with no checked items produces a zero-item total', () {
    final gula = buildProduct(id: 1, name: 'Gula Pasir 1kg', currentStock: 4);
    final results = [
      buildResult(product: gula, dailyVelocity: 2, urgency: PriorityUrgency.red, suggestedRestockQty: 10),
    ];

    final text = buildKulakanShareText(
      results: results,
      checkedProductIds: const {},
      now: DateTime(2026, 7, 14),
    );

    expect(text, isNot(contains('Gula Pasir')));
    expect(text, contains('Total: 0 barang'));
  });
}
