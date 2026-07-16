import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/models/product.dart';
import 'package:inventaris_toko/data/models/stock_mutation.dart';
import 'package:inventaris_toko/data/repositories/app_settings_repository.dart';
import 'package:inventaris_toko/data/repositories/category_repository.dart';
import 'package:inventaris_toko/data/repositories/product_repository.dart';
import 'package:inventaris_toko/data/repositories/stock_mutation_repository.dart';
import 'package:inventaris_toko/services/notification_service.dart';
import 'package:inventaris_toko/ui/screens/mutasi/catat_mutasi_screen.dart';
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

  // Wraps CatatMutasiScreen behind a base route with a distinguishable
  // marker, so "navigates back on success" and "SnackBar actually shows"
  // can be verified — Navigator.pop() on a screen with no route beneath
  // it (i.e. pumped directly as MaterialApp.home) is a no-op that also
  // breaks the ScaffoldMessenger's SnackBar delivery in tests.
  Future<void> pumpWithBackStack(
    WidgetTester tester, {
    Product? product,
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
              child: const Text('Mutasi List Marker'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Mutasi List Marker'));
    await settleAfterAsyncWork(tester);
  }

  Future<void> tapSubmit(WidgetTester tester) async {
    final submitFinder = find.byKey(const Key('catat_mutasi_submit'));
    await tester.ensureVisible(submitFinder);
    await tester.tap(submitFinder);
    await settleAfterAsyncWork(tester);
  }

  testWidgets('search mode: searching and selecting a product reveals the form', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Snacks');
      await productRepository.create(
        name: 'Indomie Goreng',
        categoryId: category.id,
        sellPrice: 3000,
        unit: 'pcs',
        initialStock: 12,
      );

      await pumpWithBackStack(tester);

      expect(find.byKey(const Key('catat_mutasi_quantity')), findsNothing);

      await tester.enterText(find.byKey(const Key('catat_mutasi_search')), 'goreng');
      await settleAfterAsyncWork(tester);

      expect(find.text('Indomie Goreng'), findsOneWidget);
      await tester.tap(find.text('Indomie Goreng'));
      await settleAfterAsyncWork(tester);

      expect(find.byKey(const Key('catat_mutasi_quantity')), findsOneWidget);
      expect(
        find.textContaining('Indomie Goreng — stok saat ini: 12 pcs'),
        findsOneWidget,
      );
    });
  });

  testWidgets('preselected mode: skips search and shows product context immediately', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Snacks');
      final product = await productRepository.create(
        name: 'Indomie Goreng',
        categoryId: category.id,
        sellPrice: 3000,
        unit: 'pcs',
        initialStock: 12,
      );

      await pumpWithBackStack(tester, product: product, initialType: StockMutationType.stockOut);

      expect(find.byKey(const Key('catat_mutasi_search')), findsNothing);
      expect(find.byKey(const Key('catat_mutasi_quantity')), findsOneWidget);
      expect(
        find.textContaining('Indomie Goreng — stok saat ini: 12 pcs'),
        findsOneWidget,
      );

      // Stok keluar should be the pre-selected type (a filled button vs
      // an outlined one is the visual signal for which is selected).
      expect(
        find.descendant(
          of: find.byKey(const Key('catat_mutasi_type_out')),
          matching: find.byType(ElevatedButton),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('catat_mutasi_type_in')),
          matching: find.byType(OutlinedButton),
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('validation: quantity 0 or empty shows inline error and does not submit', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Snacks');
      final product = await productRepository.create(
        name: 'Indomie Goreng',
        categoryId: category.id,
        sellPrice: 3000,
        unit: 'pcs',
      );

      await pumpWithBackStack(tester, product: product);

      await tapSubmit(tester);

      expect(find.text('Jumlah harus lebih dari 0'), findsOneWidget);
      expect(await stockMutationRepository.getHistoryForProduct(product.id), isEmpty);

      await tester.enterText(find.byKey(const Key('catat_mutasi_quantity')), '0');
      await tapSubmit(tester);

      expect(find.text('Jumlah harus lebih dari 0'), findsOneWidget);
      expect(await stockMutationRepository.getHistoryForProduct(product.id), isEmpty);
    });
  });

  testWidgets('stock-in: submitting a valid mutation succeeds and updates currentStock', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Snacks');
      final product = await productRepository.create(
        name: 'Indomie Goreng',
        categoryId: category.id,
        sellPrice: 3000,
        unit: 'pcs',
        initialStock: 5,
      );

      await pumpWithBackStack(tester, product: product, initialType: StockMutationType.stockIn);

      await tester.enterText(find.byKey(const Key('catat_mutasi_quantity')), '10');
      await tapSubmit(tester);

      expect(find.text('Mutasi List Marker'), findsOneWidget);
      expect(find.text('Stok masuk dicatat: +10 Indomie Goreng'), findsOneWidget);

      final updated = await productRepository.getById(product.id);
      expect(updated!.currentStock, 15);
    });
  });

  testWidgets('stock-out within available stock submits directly without a confirmation dialog', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Snacks');
      final product = await productRepository.create(
        name: 'Indomie Goreng',
        categoryId: category.id,
        sellPrice: 3000,
        unit: 'pcs',
        initialStock: 10,
      );

      await pumpWithBackStack(tester, product: product, initialType: StockMutationType.stockOut);

      await tester.enterText(find.byKey(const Key('catat_mutasi_quantity')), '4');
      await tapSubmit(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Mutasi List Marker'), findsOneWidget);
      expect(find.text('Stok keluar dicatat: -4 Indomie Goreng'), findsOneWidget);

      final updated = await productRepository.getById(product.id);
      expect(updated!.currentStock, 6);
    });
  });

  testWidgets(
    'stock-out exceeding available stock is rejected inline and never submits',
    (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Snacks');
        final product = await productRepository.create(
          name: 'Indomie Goreng',
          categoryId: category.id,
          sellPrice: 3000,
          unit: 'pcs',
          initialStock: 5,
        );
        // setUp's initial stock already records one "Stok awal" mutation;
        // track the count so "no new mutation" is checked against a
        // delta, not an assumed-empty history.
        final historyBeforeSubmit = await stockMutationRepository.getHistoryForProduct(product.id);

        await pumpWithBackStack(tester, product: product, initialType: StockMutationType.stockOut);

        await tester.enterText(find.byKey(const Key('catat_mutasi_quantity')), '20');
        await tapSubmit(tester);

        // Blocked with an inline error, no dialog, no navigation, no
        // mutation recorded, and currentStock untouched.
        expect(find.byType(AlertDialog), findsNothing);
        expect(
          find.text(
            'Stok tidak mencukupi. Stok saat ini: 5 pcs, jumlah yang dimasukkan: 20 pcs.',
            findRichText: true,
          ),
          findsOneWidget,
        );
        expect(find.text('Catat Mutasi'), findsOneWidget);
        expect(find.byKey(const Key('catat_mutasi_quantity')), findsOneWidget);
        expect(
          await stockMutationRepository.getHistoryForProduct(product.id),
          hasLength(historyBeforeSubmit.length),
        );

        // The current-stock figure ("5 pcs") is bolded within the message
        // so it stands out, and the message isn't line-capped or
        // ellipsized (unlike Flutter's default InputDecoration.errorText
        // rendering), so a long message always displays in full.
        final errorTextWidget = tester.widget<RichText>(
          find.text(
            'Stok tidak mencukupi. Stok saat ini: 5 pcs, jumlah yang dimasukkan: 20 pcs.',
            findRichText: true,
          ),
        );
        expect(errorTextWidget.maxLines, isNull);
        // Text.rich wraps the given TextSpan as a single child of its own
        // root span (which carries the effective/inherited style), so the
        // actual message spans are one level down.
        final rootSpan = errorTextWidget.text as TextSpan;
        final messageSpan = rootSpan.children!.single as TextSpan;
        final boldSpan = messageSpan.children!
            .cast<TextSpan>()
            .firstWhere((s) => s.text == '5 pcs');
        expect(boldSpan.style?.fontWeight, FontWeight.bold);
        final nonBoldSpan = messageSpan.children!
            .cast<TextSpan>()
            .firstWhere((s) => s.text == ', jumlah yang dimasukkan: 20 pcs.');
        expect(nonBoldSpan.style?.fontWeight, isNot(FontWeight.bold));

        final unchanged = await productRepository.getById(product.id);
        expect(unchanged!.currentStock, 5);

        // Retrying with a submittable quantity still works after the
        // inline error is showing.
        await tester.enterText(find.byKey(const Key('catat_mutasi_quantity')), '4');
        await tapSubmit(tester);

        expect(find.text('Stok keluar dicatat: -4 Indomie Goreng'), findsOneWidget);
        final updated = await productRepository.getById(product.id);
        expect(updated!.currentStock, 1);
      });
    },
  );

  testWidgets(
    'a successful save shows a SnackBar with a "Batalkan" undo action',
    (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Snacks');
        final product = await productRepository.create(
          name: 'Indomie Goreng',
          categoryId: category.id,
          sellPrice: 3000,
          unit: 'pcs',
          initialStock: 10,
        );

        await pumpWithBackStack(tester, product: product, initialType: StockMutationType.stockOut);

        await tester.enterText(find.byKey(const Key('catat_mutasi_quantity')), '4');
        await tapSubmit(tester);

        expect(find.text('Stok keluar dicatat: -4 Indomie Goreng'), findsOneWidget);
        expect(find.widgetWithText(SnackBarAction, 'Batalkan'), findsOneWidget);

        // SnackBar.persist defaults to true whenever action is non-null,
        // which silently turns `duration` into a no-op (Flutter's own
        // dismiss-timer callback just returns early when persist is
        // true) — so this SnackBar must set persist: false explicitly, or
        // it never auto-dismisses and just sits there until manually
        // swiped away.
        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackBar.persist, isFalse);
        expect(snackBar.duration, const Duration(seconds: 5));
      });
    },
  );

  testWidgets(
    'tapping "Batalkan" in the SnackBar undoes the mutation via undoMutation',
    (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Snacks');
        final product = await productRepository.create(
          name: 'Indomie Goreng',
          categoryId: category.id,
          sellPrice: 3000,
          unit: 'pcs',
          initialStock: 10,
        );

        await pumpWithBackStack(tester, product: product, initialType: StockMutationType.stockOut);

        await tester.enterText(find.byKey(const Key('catat_mutasi_quantity')), '4');
        await tapSubmit(tester);

        final historyBeforeUndo = await stockMutationRepository.getHistoryForProduct(product.id);
        final savedMutation = historyBeforeUndo.first;
        expect(savedMutation.type, StockMutationType.stockOut);
        expect(savedMutation.quantity, 4);

        await tester.tap(find.widgetWithText(SnackBarAction, 'Batalkan'));
        await settleAfterAsyncWork(tester);

        expect(find.text('Mutasi dibatalkan'), findsOneWidget);

        final historyAfterUndo = await stockMutationRepository.getHistoryForProduct(product.id);
        expect(historyAfterUndo, hasLength(historyBeforeUndo.length + 1));
        // The compensating entry is a stockIn of the same quantity, and
        // the original stockOut record is still present untouched.
        expect(
          historyAfterUndo.any(
            (m) => m.type == StockMutationType.stockIn && m.quantity == 4 && (m.note ?? '').startsWith('Dibatalkan'),
          ),
          isTrue,
        );
        expect(historyAfterUndo.any((m) => m.id == savedMutation.id), isTrue);

        final updated = await productRepository.getById(product.id);
        // 10 - 4 (stockOut) + 4 (undo stockIn) = 10.
        expect(updated!.currentStock, 10);
      });
    },
  );

  testWidgets('harga modal field appears for stockIn and disappears for stockOut', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Snacks');
      final product = await productRepository.create(
        name: 'Indomie Goreng',
        categoryId: category.id,
        sellPrice: 3000,
        unit: 'pcs',
        initialStock: 10,
      );

      await pumpWithBackStack(tester, product: product, initialType: StockMutationType.stockIn);
      expect(find.byKey(const Key('catat_mutasi_cost_price')), findsOneWidget);

      await tester.tap(find.byKey(const Key('catat_mutasi_type_out')));
      await tester.pump();
      expect(find.byKey(const Key('catat_mutasi_cost_price')), findsNothing);

      await tester.tap(find.byKey(const Key('catat_mutasi_type_in')));
      await tester.pump();
      expect(find.byKey(const Key('catat_mutasi_cost_price')), findsOneWidget);
    });
  });

  testWidgets(
    'submitting stockIn with harga modal filled recalculates averageCostPrice via recordMutation',
    (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Snacks');
        final product = await productRepository.create(
          name: 'Indomie Goreng',
          categoryId: category.id,
          sellPrice: 3000,
          unit: 'pcs',
          initialStock: 10,
        );

        await pumpWithBackStack(tester, product: product, initialType: StockMutationType.stockIn);

        await tester.enterText(find.byKey(const Key('catat_mutasi_quantity')), '5');
        await tester.enterText(find.byKey(const Key('catat_mutasi_cost_price')), '6000');
        await tapSubmit(tester);

        // No prior HPP (null treated as 0): (10*0 + 5*6000) / 15 = 2000.
        final updated = await productRepository.getById(product.id);
        expect(updated!.currentStock, 15);
        expect(updated.averageCostPrice, 2000);
      });
    },
  );

  testWidgets('submitting stockIn with harga modal left blank leaves averageCostPrice unchanged', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Snacks');
      final product = await productRepository.create(
        name: 'Indomie Goreng',
        categoryId: category.id,
        sellPrice: 3000,
        unit: 'pcs',
        initialStock: 10,
        averageCostPrice: 2500,
      );

      await pumpWithBackStack(tester, product: product, initialType: StockMutationType.stockIn);

      await tester.enterText(find.byKey(const Key('catat_mutasi_quantity')), '5');
      await tapSubmit(tester);

      final updated = await productRepository.getById(product.id);
      expect(updated!.currentStock, 15);
      expect(updated.averageCostPrice, 2500);
    });
  });

  testWidgets('search mode: "Sering keluar" quick-select chips appear before a product is selected',
      (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Snacks');
      final product = await productRepository.create(
        name: 'Indomie Goreng',
        categoryId: category.id,
        sellPrice: 3000,
        unit: 'pcs',
        initialStock: 20,
      );
      await stockMutationRepository.recordMutation(
        productId: product.id,
        type: StockMutationType.stockOut,
        quantity: 5,
      );

      await pumpWithBackStack(tester);

      expect(find.byKey(const Key('catat_mutasi_frequently_sold_chips')), findsOneWidget);
      expect(find.byKey(Key('frequently_sold_chip_${product.id}')), findsOneWidget);
      expect(find.text('Indomie Goreng'), findsOneWidget);
    });
  });

  testWidgets(
    'search mode: no products with sales history means no "Sering keluar" chips',
    (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Snacks');
        await productRepository.create(
          name: 'Indomie Goreng',
          categoryId: category.id,
          sellPrice: 3000,
          unit: 'pcs',
          initialStock: 20,
        );

        await pumpWithBackStack(tester);

        expect(find.byKey(const Key('catat_mutasi_frequently_sold_chips')), findsNothing);
      });
    },
  );

  testWidgets('tapping a "Sering keluar" chip pre-fills that product and hides the chips',
      (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Snacks');
      final product = await productRepository.create(
        name: 'Indomie Goreng',
        categoryId: category.id,
        sellPrice: 3000,
        unit: 'pcs',
        initialStock: 20,
      );
      await stockMutationRepository.recordMutation(
        productId: product.id,
        type: StockMutationType.stockOut,
        quantity: 5,
      );

      await pumpWithBackStack(tester);

      await tester.tap(find.byKey(Key('frequently_sold_chip_${product.id}')));
      await settleAfterAsyncWork(tester);

      expect(find.byKey(const Key('catat_mutasi_frequently_sold_chips')), findsNothing);
      expect(find.byKey(const Key('catat_mutasi_quantity')), findsOneWidget);
      expect(find.textContaining('Indomie Goreng — stok saat ini: 15 pcs'), findsOneWidget);
    });
  });

  testWidgets('quick-select chips are hidden once a product is selected via search',
      (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Snacks');
      final frequent = await productRepository.create(
        name: 'Kopi Kapal Api',
        categoryId: category.id,
        sellPrice: 2000,
        unit: 'pcs',
        initialStock: 20,
      );
      await stockMutationRepository.recordMutation(
        productId: frequent.id,
        type: StockMutationType.stockOut,
        quantity: 5,
      );
      await productRepository.create(
        name: 'Indomie Goreng',
        categoryId: category.id,
        sellPrice: 3000,
        unit: 'pcs',
        initialStock: 12,
      );

      await pumpWithBackStack(tester);
      expect(find.byKey(const Key('catat_mutasi_frequently_sold_chips')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('catat_mutasi_search')), 'goreng');
      await settleAfterAsyncWork(tester);
      await tester.tap(find.text('Indomie Goreng'));
      await settleAfterAsyncWork(tester);

      expect(find.byKey(const Key('catat_mutasi_frequently_sold_chips')), findsNothing);
    });
  });

  testWidgets(
    'stock-out that brings a product to exactly 0 queues it for the next critical stock alert, '
    'without sending anything instantly',
    (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Snacks');
        final product = await productRepository.create(
          name: 'Indomie Goreng',
          categoryId: category.id,
          sellPrice: 3000,
          unit: 'pcs',
          initialStock: 4,
        );

        await pumpWithBackStack(tester, product: product, initialType: StockMutationType.stockOut);

        await tester.enterText(find.byKey(const Key('catat_mutasi_quantity')), '4');
        await tapSubmit(tester);

        final updated = await productRepository.getById(product.id);
        expect(updated!.currentStock, 0);
        expect(updated.criticalStockAlertState, criticalStockAlertStatePending);
        expect(fakeSender.bodies, isEmpty);
      });
    },
  );

  testWidgets('stock-out that leaves stock above the threshold does not queue a critical stock alert',
      (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Snacks');
      final product = await productRepository.create(
        name: 'Indomie Goreng',
        categoryId: category.id,
        sellPrice: 3000,
        unit: 'pcs',
        initialStock: 10,
      );

      await pumpWithBackStack(tester, product: product, initialType: StockMutationType.stockOut);

      await tester.enterText(find.byKey(const Key('catat_mutasi_quantity')), '4');
      await tapSubmit(tester);

      final updated = await productRepository.getById(product.id);
      expect(updated!.currentStock, 6);
      expect(updated.criticalStockAlertState, isNull);
      expect(fakeSender.bodies, isEmpty);
    });
  });
}
