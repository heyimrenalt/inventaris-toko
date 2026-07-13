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
}
