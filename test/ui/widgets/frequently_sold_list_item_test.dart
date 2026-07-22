import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/models/product.dart';
import 'package:inventaris_toko/domain/prioritas_kulakan_calculator.dart';
import 'package:inventaris_toko/ui/widgets/frequently_sold_list_item.dart';

void main() {
  Product product({required double currentStock}) {
    return Product()
      ..id = 1
      ..name = 'Kopi Kapal Api'
      ..sellPrice = 1000
      ..unit = 'pcs'
      ..currentStock = currentStock
      ..minStockThreshold = 5
      ..createdAt = DateTime(2026, 1, 1)
      ..updatedAt = DateTime(2026, 1, 1);
  }

  PrioritasKulakanResult result({
    required double currentStock,
    required int dataAgeDays,
    double dailyVelocity = 9,
  }) {
    return PrioritasKulakanResult(
      product: product(currentStock: currentStock),
      dailyVelocity: dailyVelocity,
      dataAgeDays: dataAgeDays,
      estimatedDaysRemaining: null,
      isOutOfStock: currentStock <= 0,
      urgency: PriorityUrgency.neutral,
      suggestedRestockQty: 1,
    );
  }

  Future<void> pumpItem(WidgetTester tester, PrioritasKulakanResult result) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FrequentlySoldListItem(result: result, onTap: () {}),
      ),
    ));
  }

  testWidgets('out-of-stock product appends "(stok kosong)" to the velocity line', (tester) async {
    await pumpItem(
      tester,
      result(currentStock: 0, dataAgeDays: 10),
    );

    expect(find.textContaining('(stok kosong)'), findsOneWidget);
    expect(find.text('Rata-rata terjual ~9/hari (stok kosong)'), findsOneWidget);
  });

  testWidgets('in-stock product does not show "(stok kosong)"', (tester) async {
    await pumpItem(
      tester,
      result(currentStock: 20, dataAgeDays: 10),
    );

    expect(find.textContaining('(stok kosong)'), findsNothing);
    expect(find.text('Rata-rata terjual ~9/hari'), findsOneWidget);
  });

  testWidgets('dataAgeDays caption is dynamic, not hardcoded to 30', (tester) async {
    await pumpItem(
      tester,
      result(currentStock: 10, dataAgeDays: 10),
    );

    expect(find.text('berdasarkan rata-rata 10 hari terakhir'), findsOneWidget);
    expect(find.text('berdasarkan rata-rata 30 hari terakhir'), findsNothing);
  });

  testWidgets('current stock is shown as a secondary line', (tester) async {
    await pumpItem(
      tester,
      result(currentStock: 7, dataAgeDays: 10),
    );

    expect(find.text('Stok: 7 pcs'), findsOneWidget);
  });
}
