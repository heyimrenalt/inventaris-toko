import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/models/stock_mutation.dart';
import 'package:inventaris_toko/data/repositories/app_settings_repository.dart';
import 'package:inventaris_toko/data/repositories/category_repository.dart';
import 'package:inventaris_toko/data/repositories/product_repository.dart';
import 'package:inventaris_toko/data/repositories/stock_mutation_repository.dart';
import 'package:inventaris_toko/ui/screens/mutasi/product_mutation_history_screen.dart';
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

  // recordMutation always stamps `createdAt` with the real current time,
  // so a mutation from days ago has to be inserted directly instead —
  // same approach used by mutasi_screen_test.dart's day-grouping test.
  Future<StockMutation> insertMutationAt({
    required int productId,
    required StockMutationType type,
    required double quantity,
    required DateTime createdAt,
  }) async {
    final mutation = StockMutation()
      ..productId = productId
      ..type = type
      ..quantity = quantity
      ..stockAfter = 0
      ..createdAt = createdAt;
    await isar.writeTxn(() async {
      await isar.stockMutations.put(mutation);
    });
    return mutation;
  }

  testWidgets(
    'groups mutations under "Hari ini" / "Kemarin" / an absolute date header, same as the Mutasi tab',
    (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Snacks');
        final product = await productRepository.create(
          name: 'Chips',
          categoryId: category.id,
          sellPrice: 1000,
          unit: 'pcs',
        );

        final now = DateTime.now();
        await insertMutationAt(
          productId: product.id,
          type: StockMutationType.stockIn,
          quantity: 5,
          createdAt: now,
        );
        await insertMutationAt(
          productId: product.id,
          type: StockMutationType.stockIn,
          quantity: 3,
          createdAt: now.subtract(const Duration(days: 1)),
        );
        final oldDate = now.subtract(const Duration(days: 10));
        await insertMutationAt(
          productId: product.id,
          type: StockMutationType.stockOut,
          quantity: 2,
          createdAt: oldDate,
        );

        await tester.pumpWidget(MaterialApp(
          home: ProductMutationHistoryScreen(isar: isar, product: product),
        ));
        await settleAfterAsyncWork(tester);

        expect(find.text('Hari ini'), findsOneWidget);
        expect(find.text('Kemarin'), findsOneWidget);

        const months = [
          'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
          'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
        ];
        final expectedOldLabel =
            '${oldDate.day} ${months[oldDate.month - 1]} ${oldDate.year}';
        expect(find.text(expectedOldLabel), findsOneWidget);

        expect(find.text('+5 pcs'), findsOneWidget);
        expect(find.text('+3 pcs'), findsOneWidget);
        expect(find.text('-2 pcs'), findsOneWidget);
      });
    },
  );

  testWidgets(
    'only the most recent mutation shows a "Batalkan" action, and cancelling it records a compensating entry',
    (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Snacks');
        final product = await productRepository.create(
          name: 'Chips',
          categoryId: category.id,
          sellPrice: 1000,
          unit: 'pcs',
          initialStock: 10,
        );
        final older = await stockMutationRepository.recordMutation(
          productId: product.id,
          type: StockMutationType.stockOut,
          quantity: 3,
        );
        final latest = await stockMutationRepository.recordMutation(
          productId: product.id,
          type: StockMutationType.stockIn,
          quantity: 2,
        );

        await tester.pumpWidget(MaterialApp(
          home: ProductMutationHistoryScreen(isar: isar, product: product),
        ));
        await settleAfterAsyncWork(tester);

        expect(find.byIcon(Icons.undo), findsOneWidget);
        expect(find.byKey(Key('mutation_cancel_${latest.id}')), findsOneWidget);
        expect(find.byKey(Key('mutation_cancel_${older.id}')), findsNothing);

        await tester.tap(find.byKey(Key('mutation_cancel_${latest.id}')));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Batalkan').last);
        await settleAfterAsyncWork(tester);

        expect(find.text('Mutasi dibatalkan'), findsOneWidget);

        final history = await stockMutationRepository.getHistoryForProduct(product.id);
        expect(
          history.any(
            (m) => m.type == StockMutationType.stockOut && (m.note ?? '').startsWith('Dibatalkan'),
          ),
          isTrue,
        );

        // Undoing the newest mutation created a brand-new stockOut entry,
        // which is now the newest — so cancel eligibility has moved off
        // of `latest` entirely.
        expect(find.byKey(Key('mutation_cancel_${latest.id}')), findsNothing);
      });
    },
  );

  testWidgets(
    'with 3 mutations for the same product, only the newest shows a cancel button — the other two show none at all',
    (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Snacks');
        final product = await productRepository.create(
          name: 'Chips',
          categoryId: category.id,
          sellPrice: 1000,
          unit: 'pcs',
          initialStock: 20,
        );

        final m1 = await stockMutationRepository.recordMutation(
          productId: product.id,
          type: StockMutationType.stockOut,
          quantity: 1,
        );
        final m2 = await stockMutationRepository.recordMutation(
          productId: product.id,
          type: StockMutationType.stockOut,
          quantity: 1,
        );
        final m3 = await stockMutationRepository.recordMutation(
          productId: product.id,
          type: StockMutationType.stockOut,
          quantity: 1,
        );

        await tester.pumpWidget(MaterialApp(
          home: ProductMutationHistoryScreen(isar: isar, product: product),
        ));
        await settleAfterAsyncWork(tester);

        // Exactly one cancel button anywhere in the screen — not "disabled
        // but present" on the older two, but genuinely absent.
        expect(find.byIcon(Icons.undo), findsOneWidget);
        expect(find.byKey(Key('mutation_cancel_${m3.id}')), findsOneWidget);
        expect(find.byKey(Key('mutation_cancel_${m2.id}')), findsNothing);
        expect(find.byKey(Key('mutation_cancel_${m1.id}')), findsNothing);
      });
    },
  );
}
