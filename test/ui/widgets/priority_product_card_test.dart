import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/models/product.dart';
import 'package:inventaris_toko/domain/prioritas_kulakan_calculator.dart';
import 'package:inventaris_toko/ui/widgets/priority_product_card.dart';

void main() {
  PrioritasKulakanResult resultFor({
    int id = 1,
    required double currentStock,
    int? unitsPerPack,
    int? unitsPerDus,
  }) {
    final product = Product()
      ..id = id
      ..name = 'Test Product'
      ..sellPrice = 1000
      ..unit = 'pcs'
      ..currentStock = currentStock
      ..minStockThreshold = 5
      ..unitsPerPack = unitsPerPack
      ..unitsPerDus = unitsPerDus
      ..createdAt = DateTime(2026, 1, 1)
      ..updatedAt = DateTime(2026, 1, 1);

    return PrioritasKulakanResult(
      product: product,
      dailyVelocity: 1,
      dataAgeDays: 7,
      estimatedDaysRemaining: currentStock,
      isOutOfStock: currentStock <= 0,
      urgency: PriorityUrgency.neutral,
      suggestedRestockQty: 0,
    );
  }

  Future<void> pumpCard(WidgetTester tester, PrioritasKulakanResult result, {bool compact = false}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PriorityProductCard(result: result, onTap: () {}, compact: compact),
      ),
    ));
  }

  testWidgets('full card: currentStock=72, unitsPerPack=6, unitsPerDus=6 shows "= 12 pack = 2 dus"',
      (tester) async {
    await pumpCard(tester, resultFor(currentStock: 72, unitsPerPack: 6, unitsPerDus: 6));

    expect(find.text('= 12 pack = 2 dus'), findsOneWidget);
  });

  testWidgets('full card: currentStock=15, unitsPerPack=6 shows no conversion line', (tester) async {
    await pumpCard(tester, resultFor(currentStock: 15, unitsPerPack: 6));

    expect(find.textContaining('pack'), findsNothing);
    expect(find.textContaining('dus'), findsNothing);
  });

  testWidgets('full card: no unitsPerPack shows no conversion line (unchanged behavior)',
      (tester) async {
    await pumpCard(tester, resultFor(currentStock: 15));

    expect(find.textContaining('pack'), findsNothing);
    expect(find.textContaining('dus'), findsNothing);
  });

  testWidgets('compact card: currentStock=72, unitsPerPack=6, unitsPerDus=6 shows "= 12 pack = 2 dus"',
      (tester) async {
    await pumpCard(tester, resultFor(currentStock: 72, unitsPerPack: 6, unitsPerDus: 6), compact: true);

    expect(find.text('= 12 pack = 2 dus'), findsOneWidget);
  });

  testWidgets('unitsPerDus set with unitsPerPack null shows "= N dus" only (dus relative to pcs)',
      (tester) async {
    await pumpCard(tester, resultFor(currentStock: 24, unitsPerDus: 12));

    expect(find.text('= 2 dus'), findsOneWidget);
  });
}
