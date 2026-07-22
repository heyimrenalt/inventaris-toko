import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/models/product.dart';
import 'package:inventaris_toko/data/models/stock_mutation.dart';
import 'package:inventaris_toko/data/repositories/app_settings_repository.dart';
import 'package:inventaris_toko/data/repositories/category_repository.dart';
import 'package:inventaris_toko/data/repositories/product_repository.dart';
import 'package:inventaris_toko/data/repositories/stock_mutation_repository.dart';
import 'package:inventaris_toko/ui/navigation/main_scaffold.dart';
import 'package:inventaris_toko/ui/screens/mutasi/catat_mutasi_screen.dart';
import 'package:isar_community/isar.dart';

import '../../../data/repositories/test_isar.dart';
import '../../widget_test_helpers.dart';

/// Regression coverage for the Mutasi "Catat" form's controller/submit
/// lifecycle. This is what caught the original bug report ("Tab Mutasi,
/// input a stock mutation, submit, app crashes"): the root cause was a
/// rapid-double-tap race in `_submit()` — the "Simpan" button's disabled
/// state only takes effect once the widget rebuilds on the *next* frame,
/// so two taps landing before that rebuild both still hit the old
/// (non-null) `onPressed` callback, letting `_submit()` run twice
/// concurrently. Every test here wraps its interaction in
/// [expectNoFlutterErrors] (see widget_test_helpers.dart) specifically
/// because a plain widget test does not fail on a framework assertion
/// raised outside the direct pump/build call stack — that is exactly how
/// this bug shipped in the first place.
void main() {
  late Isar isar;
  late CategoryRepository categoryRepository;
  late ProductRepository productRepository;
  late StockMutationRepository stockMutationRepository;

  setUp(() async {
    isar = await openTestIsar();
    categoryRepository = CategoryRepository(isar);
    stockMutationRepository = StockMutationRepository(isar);
    productRepository = ProductRepository(isar, stockMutationRepository, AppSettingsRepository(isar));
  });

  tearDown(() async {
    await closeTestIsar(isar);
  });

  Future<Product> seedProduct({double initialStock = 10}) async {
    final category = await categoryRepository.create('Snacks');
    return productRepository.create(
      name: 'Indomie Goreng',
      categoryId: category.id,
      sellPrice: 3000,
      unit: 'pcs',
      initialStock: initialStock,
    );
  }

  Future<void> pumpForm(
    WidgetTester tester, {
    required Product product,
    StockMutationType? initialType,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CatatMutasiScreen(
                    isar: isar,
                    product: product,
                    initialType: initialType,
                  ),
                ),
              ),
              child: const Text('Marker'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Marker'));
    await settleAfterAsyncWork(tester);
  }

  Future<void> tapSubmit(WidgetTester tester) async {
    final submitFinder = find.byKey(const Key('catat_mutasi_submit'));
    await tester.ensureVisible(submitFinder);
    await tester.tap(submitFinder);
    await settleAfterAsyncWork(tester);
  }

  testWidgets('stock-in submit: no exception, form closes cleanly', (tester) async {
    await tester.runAsync(() async {
      await expectNoFlutterErrors(tester, () async {
        final product = await seedProduct();
        await pumpForm(tester, product: product, initialType: StockMutationType.stockIn);

        await tester.enterText(find.byKey(Key('unit_qty_field_${product.id}')), '5');
        await tapSubmit(tester);

        expect(find.text('Marker'), findsOneWidget);
        expect(find.byType(CatatMutasiScreen), findsNothing);
      });
    });
  });

  testWidgets('stock-out submit: no exception, form closes cleanly', (tester) async {
    await tester.runAsync(() async {
      await expectNoFlutterErrors(tester, () async {
        final product = await seedProduct();
        await pumpForm(tester, product: product, initialType: StockMutationType.stockOut);

        await tester.enterText(find.byKey(Key('unit_qty_field_${product.id}')), '4');
        await tapSubmit(tester);

        expect(find.text('Marker'), findsOneWidget);
        expect(find.byType(CatatMutasiScreen), findsNothing);
      });
    });
  });

  testWidgets('submit followed immediately by a back-button tap: no exception', (tester) async {
    await tester.runAsync(() async {
      await expectNoFlutterErrors(tester, () async {
        final product = await seedProduct();
        await pumpForm(tester, product: product, initialType: StockMutationType.stockIn);

        await tester.enterText(find.byKey(Key('unit_qty_field_${product.id}')), '5');
        // Submit's own successful path already pops the route — this
        // fires a second, redundant back navigation right on top of it
        // (no settle in between) to make sure that doesn't double-pop or
        // crash. Whichever pop wins the race, the form must be gone
        // afterwards with no exception raised.
        await tester.tap(find.byKey(const Key('catat_mutasi_submit')));
        final backButton = find.byTooltip('Back');
        if (backButton.evaluate().isNotEmpty) {
          await tester.tap(backButton);
        }
        await settleAfterAsyncWork(tester);

        expect(find.byType(CatatMutasiScreen), findsNothing);
      });
    });
  });

  testWidgets('rapid double/triple-tap on submit: exactly one mutation recorded, no exception',
      (tester) async {
    await tester.runAsync(() async {
      late Product product;
      await expectNoFlutterErrors(tester, () async {
        product = await seedProduct();
        await pumpForm(tester, product: product, initialType: StockMutationType.stockIn);

        await tester.enterText(find.byKey(Key('unit_qty_field_${product.id}')), '5');
        await tester.pump();

        final submitFinder = find.byKey(const Key('catat_mutasi_submit'));
        await tester.ensureVisible(submitFinder);

        // Three taps fired back-to-back with only a bare pump() (no real
        // delay, no settle) between the first two, so all land before
        // the disabled-button rebuild can take effect.
        await tester.tap(submitFinder);
        await tester.tap(submitFinder);
        await tester.pump();
        await tester.tap(submitFinder);

        await settleAfterAsyncWork(tester);
      });

      final history = await stockMutationRepository.getHistoryForProduct(product.id);
      // 1 "Stok awal" mutation from seeding + exactly 1 stock-in from the
      // 3 rapid taps.
      expect(history, hasLength(2));
      final updated = await productRepository.getById(product.id);
      expect(updated!.currentStock, 15);
    });
  });

  testWidgets('undo the last mutation via the SnackBar action: no exception', (tester) async {
    await tester.runAsync(() async {
      await expectNoFlutterErrors(tester, () async {
        final product = await seedProduct();
        await pumpForm(tester, product: product, initialType: StockMutationType.stockOut);

        await tester.enterText(find.byKey(Key('unit_qty_field_${product.id}')), '4');
        await tapSubmit(tester);

        await tester.tap(find.widgetWithText(SnackBarAction, 'Batalkan'));
        await settleAfterAsyncWork(tester);

        expect(find.text('Mutasi dibatalkan'), findsOneWidget);
      });
    });
  });

  testWidgets('opening and closing the Catat form 5 times in a row: no exception, no leaked controllers',
      (tester) async {
    await tester.runAsync(() async {
      await expectNoFlutterErrors(tester, () async {
        final product = await seedProduct(initialStock: 100);

        for (var i = 0; i < 5; i++) {
          await pumpForm(tester, product: product, initialType: StockMutationType.stockIn);
          expect(find.byType(CatatMutasiScreen), findsOneWidget);
          await tester.tap(find.byIcon(Icons.arrow_back_rounded));
          await tester.pumpAndSettle();
          await settleAfterAsyncWork(tester);
          expect(find.byType(CatatMutasiScreen), findsNothing);
        }
      });
    });
  });

  testWidgets('validation: empty quantity shows inline error, no crash, controllers intact',
      (tester) async {
    await tester.runAsync(() async {
      await expectNoFlutterErrors(tester, () async {
        final product = await seedProduct();
        await pumpForm(tester, product: product, initialType: StockMutationType.stockIn);

        await tapSubmit(tester);

        expect(find.text('Jumlah harus lebih dari 0'), findsOneWidget);
        expect(find.byType(CatatMutasiScreen), findsOneWidget);
        // The field is still usable after the validation error.
        await tester.enterText(find.byKey(Key('unit_qty_field_${product.id}')), '3');
        await tapSubmit(tester);
        expect(find.text('Marker'), findsOneWidget);
      });
    });
  });

  testWidgets('validation: quantity 0 shows inline error, no crash', (tester) async {
    await tester.runAsync(() async {
      await expectNoFlutterErrors(tester, () async {
        final product = await seedProduct();
        await pumpForm(tester, product: product, initialType: StockMutationType.stockIn);

        await tester.enterText(find.byKey(Key('unit_qty_field_${product.id}')), '0');
        await tapSubmit(tester);

        expect(find.text('Jumlah harus lebih dari 0'), findsOneWidget);
        expect(find.byType(CatatMutasiScreen), findsOneWidget);
      });
    });
  });

  testWidgets('validation: negative quantity shows inline error, no crash', (tester) async {
    await tester.runAsync(() async {
      await expectNoFlutterErrors(tester, () async {
        final product = await seedProduct();
        await pumpForm(tester, product: product, initialType: StockMutationType.stockIn);

        await tester.enterText(find.byKey(Key('unit_qty_field_${product.id}')), '-5');
        await tapSubmit(tester);

        expect(find.text('Jumlah harus lebih dari 0'), findsOneWidget);
        expect(find.byType(CatatMutasiScreen), findsOneWidget);
      });
    });
  });

  testWidgets(
    'stock-out exceeding current stock is rejected inline (existing business rule), no crash',
    (tester) async {
      await tester.runAsync(() async {
        await expectNoFlutterErrors(tester, () async {
          final product = await seedProduct(initialStock: 5);
          await pumpForm(tester, product: product, initialType: StockMutationType.stockOut);

          await tester.enterText(find.byKey(Key('unit_qty_field_${product.id}')), '20');
          await tapSubmit(tester);

          expect(find.textContaining('Stok tidak mencukupi'), findsOneWidget);
          expect(find.byType(CatatMutasiScreen), findsOneWidget);
          final unchanged = await productRepository.getById(product.id);
          expect(unchanged!.currentStock, 5);
        });
      });
    },
  );

  testWidgets('back-button press mid-submit: no exception', (tester) async {
    await tester.runAsync(() async {
      await expectNoFlutterErrors(tester, () async {
        final product = await seedProduct();
        await pumpForm(tester, product: product, initialType: StockMutationType.stockIn);

        await tester.enterText(find.byKey(Key('unit_qty_field_${product.id}')), '5');
        // Tap submit and, without waiting for its real (Isar-backed)
        // write to resolve, immediately trigger a back navigation —
        // exercises the `if (!mounted) return;` guard after the await in
        // _submit(). The submit's own write may or may not still be
        // in-flight by the time the back button is looked up (real Isar
        // I/O timing isn't deterministic in a test), so only tap it if
        // the form (and its AppBar back button) is still there.
        await tester.tap(find.byKey(const Key('catat_mutasi_submit')));
        final backButton = find.byTooltip('Back');
        if (backButton.evaluate().isNotEmpty) {
          await tester.tap(backButton);
        }
        await settleAfterAsyncWork(tester);

        expect(find.byType(CatatMutasiScreen), findsNothing);
      });
    });
  });

  testWidgets('screen rotation while the form has text entered: text preserved, no exception',
      (tester) async {
    await tester.runAsync(() async {
      await expectNoFlutterErrors(tester, () async {
        final product = await seedProduct();
        await pumpForm(tester, product: product, initialType: StockMutationType.stockIn);

        await tester.enterText(find.byKey(Key('unit_qty_field_${product.id}')), '7');
        await tester.pump();

        // Simulate a rotation: a MediaQuery size change forces a
        // rebuild of the whole tree without disposing/recreating
        // CatatMutasiScreen's State (same Element, same controllers).
        await tester.binding.setSurfaceSize(const Size(800, 400));
        await tester.pumpAndSettle();

        expect(
          tester.widget<TextField>(find.byKey(Key('unit_qty_field_${product.id}'))).controller!.text,
          '7',
        );

        await tester.binding.setSurfaceSize(null);
        await tester.pumpAndSettle();
      });
    });
  });

  testWidgets(
    'full navigation through MainScaffold (tab tap, Catat, search, select, submit): no exception',
    (tester) async {
      await tester.runAsync(() async {
        await expectNoFlutterErrors(tester, () async {
          final product = await seedProduct();
          // Otherwise the one-time OEM battery-optimization dialog
          // (auto-shown by PengaturanScreen, which IndexedStack builds
          // eagerly alongside Beranda) covers the screen and swallows the
          // tab tap below.
          await AppSettingsRepository(isar).dismissBatteryOptimizationDialog();

          await tester.pumpWidget(MaterialApp(home: MainScaffold(isar: isar)));
          await settleAfterAsyncWork(tester);

          await tester.tap(find.byIcon(Icons.swap_horiz));
          await settleAfterAsyncWork(tester);

          await tester.tap(find.text('Stok masuk'));
          await settleAfterAsyncWork(tester);

          await tester.enterText(find.byKey(const Key('catat_mutasi_search')), 'goreng');
          await settleAfterAsyncWork(tester);

          await tester.tap(find.text('Indomie Goreng'));
          await settleAfterAsyncWork(tester);

          await tester.enterText(find.byKey(Key('unit_qty_field_${product.id}')), '10');

          final submitFinder = find.byKey(const Key('catat_mutasi_submit'));
          await tester.ensureVisible(submitFinder);
          await tester.tap(submitFinder);
          await settleAfterAsyncWork(tester);
        });
      });
    },
  );
}
