import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:inventaris_toko/data/models/product.dart';
import 'package:inventaris_toko/data/models/stock_mutation.dart';
import 'package:inventaris_toko/data/repositories/stock_mutation_repository.dart';
import 'package:inventaris_toko/ui/screens/keuntungan/rekap_keuntungan_screen.dart';
import 'package:isar_community/isar.dart';

import '../../../data/repositories/test_isar.dart';

/// Structural guards for the Rekap Keuntungan body after it moved off
/// `SingleChildScrollView` + `ListView(shrinkWrap: true)` onto a
/// [CustomScrollView] with a lazy [SliverList]. The old shape built every
/// product row on the first frame, which dominated screen-open time at
/// scale; these assertions exist so that anti-pattern cannot come back.
///
/// Isar setup follows the sibling action-bar test: the screen takes its
/// [Isar] directly, so a real test database is the established stub here.
void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  late Isar isar;

  Product product(String name) => Product()
    ..name = name
    ..sellPrice = 5000
    ..unit = 'pcs'
    ..currentStock = 10
    ..minStockThreshold = 1
    ..averageCostPrice = 3000
    ..createdAt = DateTime(2026, 5, 1)
    ..updatedAt = DateTime(2026, 5, 1);

  StockMutation sale(int productId) => StockMutation()
    ..productId = productId
    ..type = StockMutationType.stockOut
    ..quantity = 1
    ..stockAfter = 0
    ..sellPriceSnapshot = 5000
    ..costPriceSnapshot = 3000
    ..createdAt = DateTime(2026, 5, 5, 10);

  /// See the sibling tests: Isar calls have to run on the real event loop,
  /// which `testWidgets`' fake-async zone otherwise never drives.
  Future<void> seed(WidgetTester tester, int lineCount) async {
    await tester.runAsync(() async {
      isar = await openTestIsar();
      await isar.writeTxn(() async {
        for (var i = 1; i <= lineCount; i++) {
          await isar.products.put(product('Produk $i'));
          await isar.stockMutations.put(sale(i));
        }
      });
    });
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 60; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.idle();
      await tester.pump();
    }
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RekapKeuntunganScreen(
          isar: isar,
          mutationRepository: StockMutationRepository(isar),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> teardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => closeTestIsar(isar));
  }

  testWidgets('scrolling root is a CustomScrollView with no nested scrollables',
      (tester) async {
    await seed(tester, 3);
    await pumpScreen(tester);

    expect(find.byType(CustomScrollView), findsOneWidget);

    // No shrink-wrapped list anywhere: that is the un-virtualised shape.
    final shrinkWrapped = tester
        .widgetList<ListView>(find.byType(ListView))
        .where((list) => list.shrinkWrap);
    expect(shrinkWrapped, isEmpty);

    // And no Scrollable nested inside another Scrollable, which is what
    // the old SingleChildScrollView + inner ListView produced.
    for (final element in find.byType(Scrollable).evaluate()) {
      expect(
        find.ancestor(
          of: find.byWidget(element.widget),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
        reason: 'Scrollable must not be nested inside another Scrollable',
      );
    }

    await teardown(tester);
  });

  testWidgets('detail title stays inside the same card as the product list',
      (tester) async {
    await seed(tester, 3);
    await pumpScreen(tester);

    final card = find.byType(DecoratedSliver);
    expect(card, findsOneWidget);

    // Visual-parity guard: the bordered card has to wrap the title *and*
    // the list, exactly as the old Container-wrapped Column did.
    expect(
      find.descendant(
        of: card,
        matching: find.textContaining('Detail Per Produk'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.byType(SliverList)),
      findsOneWidget,
    );

    await teardown(tester);
  });

  testWidgets('a single-line report renders no trailing separator',
      (tester) async {
    await seed(tester, 1);
    await pumpScreen(tester);

    expect(find.textContaining('Detail Per Produk (1)'), findsOneWidget);
    expect(find.byType(Divider), findsNothing);

    await teardown(tester);
  });
}
