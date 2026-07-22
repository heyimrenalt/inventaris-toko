import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/models/product.dart';
import 'package:inventaris_toko/data/models/stock_mutation.dart';
import 'package:inventaris_toko/data/repositories/app_settings_repository.dart';
import 'package:inventaris_toko/data/repositories/category_repository.dart';
import 'package:inventaris_toko/data/repositories/product_repository.dart';
import 'package:inventaris_toko/data/repositories/stock_mutation_repository.dart';
import 'package:inventaris_toko/services/notification_service.dart';
import 'package:inventaris_toko/ui/screens/mutasi/catat_stok_keluar_batch_screen.dart';
import 'package:isar_community/isar.dart';

import '../../../data/repositories/test_isar.dart';
import '../../widget_test_helpers.dart';

class _FakeNotificationSender implements NotificationSender {
  final List<String> bodies = [];

  @override
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    required String channelDescription,
    required bool highImportance,
    String? payload,
  }) async {
    bodies.add(body);
  }

  @override
  Future<void> cancelAllNotifications() async {}
}

void main() {
  late Isar isar;
  late CategoryRepository categoryRepository;
  late ProductRepository productRepository;
  late StockMutationRepository stockMutationRepository;
  late _FakeNotificationSender fakeSender;

  setUp(() async {
    isar = await openTestIsar();
    categoryRepository = CategoryRepository(isar);
    stockMutationRepository = StockMutationRepository(isar);
    productRepository = ProductRepository(
      isar,
      stockMutationRepository,
      AppSettingsRepository(isar),
    );
    fakeSender = _FakeNotificationSender();
    NotificationService.sender = fakeSender;
  });

  tearDown(() async {
    await closeTestIsar(isar);
  });

  // Wraps CatatStokKeluarBatchScreen behind a base route with a
  // distinguishable marker, so "navigates back" and the SnackBar
  // delivery both work — same pattern as catat_mutasi_screen_test.dart.
  Future<void> pumpWithBackStack(WidgetTester tester, {Product? initialProduct}) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CatatStokKeluarBatchScreen(
                    isar: isar,
                    initialProduct: initialProduct,
                  ),
                ),
              ),
              child: const Text('Mutasi List Marker'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Mutasi List Marker'));
    await settleAfterAsyncWork(tester);
  }

  Future<Product> createProduct({
    required String name,
    required double initialStock,
    String unit = 'pcs',
  }) async {
    final category = await categoryRepository.create('Snacks $name');
    return productRepository.create(
      name: name,
      categoryId: category.id,
      sellPrice: 1000,
      unit: unit,
      initialStock: initialStock,
    );
  }

  Future<void> searchAndAdd(WidgetTester tester, String query, String productName) async {
    await tester.enterText(find.byKey(const Key('beranda_search_field')), query);
    await settleAfterAsyncWork(tester);
    await tester.tap(find.text(productName));
    await settleAfterAsyncWork(tester);
  }

  testWidgets('empty cart shows the "Cari produk" empty state', (tester) async {
    await tester.runAsync(() async {
      await pumpWithBackStack(tester);

      expect(find.text('Cari produk di atas untuk mulai mencatat.'), findsOneWidget);
      expect(find.byKey(const Key('batch_cart_list')), findsNothing);

      final saveButton = tester.widget<ElevatedButton>(
        find.byKey(const Key('batch_save_button')),
      );
      expect(saveButton.onPressed, isNull);
    });
  });

  testWidgets('adding a product shows it in the cart with a unit qty field at quantity 1', (tester) async {
    await tester.runAsync(() async {
      final product = await createProduct(name: 'Gula Pasir', initialStock: 12);

      await pumpWithBackStack(tester);
      await searchAndAdd(tester, 'gula', 'Gula Pasir');

      expect(find.textContaining('Gula Pasir — stok: 12 pcs'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byKey(Key('unit_qty_field_${product.id}'))).controller!.text,
        '1',
      );
      expect(find.text('Simpan semua (1 barang)'), findsOneWidget);
    });
  });

  testWidgets('stepper + increments quantity, - decrements down to 0', (tester) async {
    await tester.runAsync(() async {
      final product = await createProduct(name: 'Gula Pasir', initialStock: 12);

      await pumpWithBackStack(tester);
      await searchAndAdd(tester, 'gula', 'Gula Pasir');

      await tester.tap(find.byKey(Key('unit_qty_stepper_plus_${product.id}')));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byKey(Key('unit_qty_field_${product.id}')))
            .controller!
            .text,
        '2',
      );

      await tester.tap(find.byKey(Key('unit_qty_stepper_minus_${product.id}')));
      await tester.pump();
      await tester.tap(find.byKey(Key('unit_qty_stepper_minus_${product.id}')));
      await tester.pump();

      expect(
        tester.widget<TextField>(find.byKey(Key('unit_qty_field_${product.id}')))
            .controller!
            .text,
        '0',
      );
      final decrementButton = tester.widget<IconButton>(
        find.byKey(Key('unit_qty_stepper_minus_${product.id}')),
      );
      expect(decrementButton.onPressed, isNull);
    });
  });

  testWidgets(
    'pre-flight validation: quantity of 0 shows an inline error and disables save',
    (tester) async {
      await tester.runAsync(() async {
        final product = await createProduct(name: 'Gula Pasir', initialStock: 12);

        await pumpWithBackStack(tester);
        await searchAndAdd(tester, 'gula', 'Gula Pasir');

        await tester.tap(find.byKey(Key('unit_qty_stepper_minus_${product.id}')));
        await tester.pump();

        expect(find.textContaining('Jumlah harus lebih dari 0'), findsOneWidget);

        final saveButton = tester.widget<ElevatedButton>(
          find.byKey(const Key('batch_save_button')),
        );
        expect(saveButton.onPressed, isNull);
      });
    },
  );

  testWidgets(
    'pre-flight validation: quantity above currentStock shows an inline error and disables save',
    (tester) async {
      await tester.runAsync(() async {
        final product = await createProduct(name: 'Gula Pasir', initialStock: 2);

        await pumpWithBackStack(tester);
        await searchAndAdd(tester, 'gula', 'Gula Pasir');

        await tester.tap(find.byKey(Key('unit_qty_stepper_plus_${product.id}')));
        await tester.pump();
        await tester.tap(find.byKey(Key('unit_qty_stepper_plus_${product.id}')));
        await tester.pump();
        // Quantity is now 3, exceeding the stock of 2.

        expect(find.textContaining('Stok tidak mencukupi: tersedia 2 pcs'), findsOneWidget);

        final saveButton = tester.widget<ElevatedButton>(
          find.byKey(const Key('batch_save_button')),
        );
        expect(saveButton.onPressed, isNull);
      });
    },
  );

  testWidgets(
    'all items valid: save button enabled and tapping it records a mutation per item',
    (tester) async {
      await tester.runAsync(() async {
        final gula = await createProduct(name: 'Gula Pasir', initialStock: 12);
        final beras = await createProduct(name: 'Beras 5kg', initialStock: 8);

        await pumpWithBackStack(tester);
        await searchAndAdd(tester, 'gula', 'Gula Pasir');
        await searchAndAdd(tester, 'beras', 'Beras 5kg');

        final saveButton = tester.widget<ElevatedButton>(
          find.byKey(const Key('batch_save_button')),
        );
        expect(saveButton.onPressed, isNotNull);

        await tester.tap(find.byKey(const Key('batch_save_button')));
        await settleAfterAsyncWork(tester);

        // Navigated back and both mutations were recorded.
        expect(find.text('Mutasi List Marker'), findsOneWidget);
        expect(find.text('2 barang berhasil dicatat'), findsOneWidget);

        final gulaHistory = await stockMutationRepository.getHistoryForProduct(gula.id);
        expect(gulaHistory.any((m) => m.type == StockMutationType.stockOut && m.quantity == 1), isTrue);

        final berasUpdated = await productRepository.getById(beras.id);
        expect(berasUpdated!.currentStock, 7);
      });
    },
  );

  testWidgets('exiting with a non-empty cart shows a confirmation dialog', (tester) async {
    await tester.runAsync(() async {
      await createProduct(name: 'Gula Pasir', initialStock: 12);

      await pumpWithBackStack(tester);
      await searchAndAdd(tester, 'gula', 'Gula Pasir');

      final backButton = find.byTooltip('Back');
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('belum disimpan'), findsOneWidget);

      // Confirming exit actually leaves the screen.
      await tester.tap(find.widgetWithText(TextButton, 'Keluar'));
      await settleAfterAsyncWork(tester);
      expect(find.text('Mutasi List Marker'), findsOneWidget);
    });
  });

  testWidgets(
    'opened with an initialProduct pre-adds it to the cart at quantity 1',
    (tester) async {
      await tester.runAsync(() async {
        final product = await createProduct(name: 'Gula Pasir', initialStock: 12);

        await pumpWithBackStack(tester, initialProduct: product);

        expect(find.textContaining('Gula Pasir — stok: 12 pcs'), findsOneWidget);
        expect(find.text('Simpan semua (1 barang)'), findsOneWidget);
      });
    },
  );

  testWidgets(
    'a single-item save shows a "Tersimpan" SnackBar with a "Batalkan" action that auto-dismisses',
    (tester) async {
      await tester.runAsync(() async {
        await createProduct(name: 'Gula Pasir', initialStock: 12);

        await pumpWithBackStack(tester);
        await searchAndAdd(tester, 'gula', 'Gula Pasir');

        await tester.tap(find.byKey(const Key('batch_save_button')));
        await settleAfterAsyncWork(tester);

        expect(find.textContaining('Tersimpan: Gula Pasir'), findsOneWidget);
        expect(find.widgetWithText(SnackBarAction, 'Batalkan'), findsOneWidget);

        // Same bug as CatatMutasiScreen's undo SnackBar: SnackBar.persist
        // defaults to true whenever action is non-null, which silently
        // turns `duration` into a no-op — so this SnackBar must set
        // persist: false explicitly, or it never auto-dismisses.
        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackBar.persist, isFalse);
        expect(snackBar.duration, const Duration(seconds: 5));
      });
    },
  );

  testWidgets(
    'saving an item that brings its stock to exactly 0 queues it for the next critical stock '
    'alert, without sending anything instantly',
    (tester) async {
      await tester.runAsync(() async {
        final product = await createProduct(name: 'Gula Pasir', initialStock: 1);

        await pumpWithBackStack(tester);
        await searchAndAdd(tester, 'gula', 'Gula Pasir');

        await tester.tap(find.byKey(const Key('batch_save_button')));
        await settleAfterAsyncWork(tester);

        final updated = await productRepository.getById(product.id);
        expect(updated!.criticalStockAlertState, criticalStockAlertStatePending);
        expect(fakeSender.bodies, isEmpty);
      });
    },
  );

  testWidgets(
    'saving 4 items that each hit 0 stock queues all 4, without sending anything instantly',
    (tester) async {
      await tester.runAsync(() async {
        final products = <Product>[];
        for (final name in ['Produk A', 'Produk B', 'Produk C', 'Produk D']) {
          products.add(await createProduct(name: name, initialStock: 1));
        }

        await pumpWithBackStack(tester);
        await searchAndAdd(tester, 'produk a', 'Produk A');
        await searchAndAdd(tester, 'produk b', 'Produk B');
        await searchAndAdd(tester, 'produk c', 'Produk C');
        await searchAndAdd(tester, 'produk d', 'Produk D');

        await tester.tap(find.byKey(const Key('batch_save_button')));
        await settleAfterAsyncWork(tester);

        for (final product in products) {
          final updated = await productRepository.getById(product.id);
          expect(updated!.criticalStockAlertState, criticalStockAlertStatePending);
        }
        expect(fakeSender.bodies, isEmpty);
      });
    },
  );

  group('unit toggle (pcs/pack/dus)', () {
    testWidgets(
      'switching a row to dus and entering "1" saves the correct pcs quantity and entered-unit history',
      (tester) async {
        await tester.runAsync(() async {
          final category = await categoryRepository.create('Snacks');
          final product = await productRepository.create(
            name: 'Indomie',
            categoryId: category.id,
            sellPrice: 3000,
            unit: 'pcs',
            initialStock: 100,
            unitsPerPack: 12,
            unitsPerDus: 6,
          );

          await pumpWithBackStack(tester);
          await searchAndAdd(tester, 'indomie', 'Indomie');

          await tester.tap(find.descendant(
            of: find.byKey(Key('unit_qty_toggle_${product.id}')),
            matching: find.text('dus'),
          ));
          await tester.pump();
          await tester.enterText(find.byKey(Key('unit_qty_field_${product.id}')), '1');
          await tester.pump();

          await tester.tap(find.byKey(const Key('batch_save_button')));
          await settleAfterAsyncWork(tester);

          final updated = await productRepository.getById(product.id);
          expect(updated!.currentStock, 28); // 100 - 72.

          final history = await stockMutationRepository.getHistoryForProduct(product.id);
          final saved = history.first;
          expect(saved.quantity, 72);
          expect(saved.enteredUnit, EnteredUnit.dus);
          expect(saved.enteredQuantity, 1);
        });
      },
    );

    testWidgets('re-adding an in-cart product via search bumps it by 1 in its current unit',
        (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Snacks');
        final product = await productRepository.create(
          name: 'Indomie',
          categoryId: category.id,
          sellPrice: 3000,
          unit: 'pcs',
          initialStock: 100,
          unitsPerPack: 12,
        );

        await pumpWithBackStack(tester);
        await searchAndAdd(tester, 'indomie', 'Indomie');

        await tester.tap(find.descendant(
          of: find.byKey(Key('unit_qty_toggle_${product.id}')),
          matching: find.text('pack'),
        ));
        await tester.pump();
        await tester.enterText(find.byKey(Key('unit_qty_field_${product.id}')), '2');
        await tester.pump();

        // Re-selecting the same product from search bumps by 1 pack
        // (24 pcs), not 1 pcs.
        await searchAndAdd(tester, 'indomie', 'Indomie');

        expect(
          tester.widget<TextField>(find.byKey(Key('unit_qty_field_${product.id}')))
              .controller!
              .text,
          '3',
        );
      });
    });
  });
}
