import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/models/stock_mutation.dart';
import 'package:inventaris_toko/data/repositories/app_settings_repository.dart';
import 'package:inventaris_toko/data/repositories/category_repository.dart';
import 'package:inventaris_toko/data/repositories/product_repository.dart';
import 'package:inventaris_toko/data/repositories/stock_mutation_repository.dart';
import 'package:inventaris_toko/ui/screens/produk/product_detail_screen.dart';
import 'package:isar_community/isar.dart';

import '../../../data/repositories/test_isar.dart';
import '../../widget_test_helpers.dart';
import 'fake_photo_storage_service.dart';

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

  // Wraps ProductDetailScreen behind a base route with a distinguishable
  // marker, so "navigates back" can be verified by checking we're back at
  // that marker (rather than just guessing at pop() semantics).
  Future<void> pumpDetailWithBackStack(WidgetTester tester, int productId) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProductDetailScreen(
                    isar: isar,
                    productId: productId,
                    photoStorageService: FakePhotoStorageService(),
                  ),
                ),
              ),
              child: const Text('Produk List Marker'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Produk List Marker'));
    await settleAfterAsyncWork(tester);
  }

  testWidgets('displays correct product info', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Snacks');
      final product = await productRepository.create(
        name: 'Chips',
        categoryId: category.id,
        sellPrice: 5000,
        unit: 'pcs',
        code: '999',
        minStockThreshold: 5,
        initialStock: 12,
      );

      await pumpDetailWithBackStack(tester, product.id);

      expect(find.byKey(const Key('product_detail_name')), findsOneWidget);
      expect(find.text('Kode: 999'), findsOneWidget);
      expect(find.text('Snacks'), findsOneWidget);
      expect(find.text('Rp 5.000'), findsOneWidget);
      expect(find.text('pcs'), findsOneWidget);
      expect(find.textContaining('Stok saat ini: 12 pcs'), findsOneWidget);
      expect(find.text('5 pcs'), findsOneWidget);
    });
  });

  testWidgets(
    'tapping Stok masuk navigates to Catat Mutasi pre-selected, and returning refreshes stock + history',
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

        await pumpDetailWithBackStack(tester, product.id);

        await tester.tap(find.widgetWithText(ElevatedButton, 'Stok masuk'));
        await settleAfterAsyncWork(tester);

        expect(find.text('Catat Mutasi'), findsOneWidget);
        expect(
          find.textContaining('Chips — stok saat ini: 12 pcs'),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('catat_mutasi_type_in')),
            matching: find.byType(ElevatedButton),
          ),
          findsOneWidget,
        );

        await tester.enterText(find.byKey(const Key('catat_mutasi_quantity')), '8');
        final submitFinder = find.byKey(const Key('catat_mutasi_submit'));
        await tester.ensureVisible(submitFinder);
        await tester.tap(submitFinder);
        await settleAfterAsyncWork(tester);

        // Back on Detail without a manual reload: stock figure and
        // recent history both reflect the new mutation immediately.
        expect(find.text('Detail Produk'), findsOneWidget);
        expect(find.textContaining('Stok saat ini: 20 pcs'), findsOneWidget);
        expect(find.text('+8 pcs'), findsOneWidget);

        final updated = await productRepository.getById(product.id);
        expect(updated!.currentStock, 20);
      });
    },
  );

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

        await pumpDetailWithBackStack(tester, product.id);

        expect(find.textContaining('Stok saat ini: 12 pcs'), findsOneWidget);

        // Simulates a mutation recorded elsewhere (not through this
        // screen's own Stok masuk/keluar buttons), which this screen can
        // only pick up via its own watch subscription.
        await stockMutationRepository.recordMutation(
          productId: product.id,
          type: StockMutationType.stockIn,
          quantity: 8,
        );
        await settleAfterAsyncWork(tester);

        expect(find.textContaining('Stok saat ini: 20 pcs'), findsOneWidget);
      });
    },
  );

  testWidgets('delete on a product with no mutation history succeeds and navigates back', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Snacks');
      final product = await productRepository.create(
        name: 'Chips',
        categoryId: category.id,
        sellPrice: 5000,
        unit: 'pcs',
      );

      await pumpDetailWithBackStack(tester, product.id);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus produk'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, 'Hapus'),
        ),
      );
      await settleAfterAsyncWork(tester);

      expect(find.text('Produk List Marker'), findsOneWidget);
      expect(find.text('Detail Produk'), findsNothing);
      expect(await productRepository.getById(product.id), isNull);
    });
  });

  testWidgets(
    'delete on a product with mutation history shows the archive-offering dialog',
    (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Snacks');
        final product = await productRepository.create(
          name: 'Chips',
          categoryId: category.id,
          sellPrice: 5000,
          unit: 'pcs',
          initialStock: 5,
        );

        await pumpDetailWithBackStack(tester, product.id);

        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Hapus produk'));
        await tester.pumpAndSettle();

        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.widgetWithText(TextButton, 'Hapus'),
          ),
        );
        await settleAfterAsyncWork(tester);

        expect(
          find.textContaining('memiliki 1 riwayat mutasi stok'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(ElevatedButton, 'Arsipkan produk ini'),
          findsOneWidget,
        );
        final unchanged = await productRepository.getById(product.id);
        expect(unchanged, isNotNull);
        expect(unchanged!.isArchived, isFalse);
      });
    },
  );

  testWidgets(
    'confirming archive from the blocking dialog archives the product and navigates back',
    (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Snacks');
        final product = await productRepository.create(
          name: 'Chips',
          categoryId: category.id,
          sellPrice: 5000,
          unit: 'pcs',
          initialStock: 5,
        );

        await pumpDetailWithBackStack(tester, product.id);

        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Hapus produk'));
        await tester.pumpAndSettle();

        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.widgetWithText(TextButton, 'Hapus'),
          ),
        );
        await settleAfterAsyncWork(tester);

        await tester.tap(find.widgetWithText(ElevatedButton, 'Arsipkan produk ini'));
        await settleAfterAsyncWork(tester);

        expect(find.text('Produk List Marker'), findsOneWidget);
        expect(find.text('Produk diarsipkan'), findsOneWidget);

        final archived = await productRepository.getById(product.id);
        expect(archived!.isArchived, isTrue);
        expect(archived.archivedAt, isNotNull);
      });
    },
  );

  testWidgets('standalone Arsipkan action in the menu archives without a failed delete first', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Snacks');
      final product = await productRepository.create(
        name: 'Chips',
        categoryId: category.id,
        sellPrice: 5000,
        unit: 'pcs',
      );

      await pumpDetailWithBackStack(tester, product.id);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Arsipkan produk'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, 'Arsipkan'),
        ),
      );
      await settleAfterAsyncWork(tester);

      expect(find.text('Produk List Marker'), findsOneWidget);
      final archived = await productRepository.getById(product.id);
      expect(archived!.isArchived, isTrue);
    });
  });
}
