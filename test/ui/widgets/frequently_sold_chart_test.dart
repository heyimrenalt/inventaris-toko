import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/models/product.dart';
import 'package:inventaris_toko/domain/prioritas_kulakan_calculator.dart';
import 'package:inventaris_toko/ui/widgets/frequently_sold_chart.dart';

void main() {
  Product product({required int id, required String name}) {
    return Product()
      ..id = id
      ..name = name
      ..sellPrice = 1000
      ..unit = 'pcs'
      ..currentStock = 10
      ..minStockThreshold = 5
      ..createdAt = DateTime(2026, 1, 1)
      ..updatedAt = DateTime(2026, 1, 1);
  }

  PrioritasKulakanResult result({
    required int id,
    required String name,
    required double dailyVelocity,
  }) {
    return PrioritasKulakanResult(
      product: product(id: id, name: name),
      dailyVelocity: dailyVelocity,
      dataAgeDays: 10,
      estimatedDaysRemaining: null,
      isOutOfStock: false,
      urgency: PriorityUrgency.neutral,
      suggestedRestockQty: 1,
    );
  }

  Future<void> pumpChart(
    WidgetTester tester,
    List<PrioritasKulakanResult> results, {
    int maxBars = 7,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FrequentlySoldChart(results: results, maxBars: maxBars),
      ),
    ));
  }

  testWidgets('renders nothing when there are no results', (tester) async {
    await pumpChart(tester, []);

    expect(find.byKey(const Key('frequently_sold_chart')), findsNothing);
  });

  testWidgets('shows a bar for each result up to maxBars, dropping the rest', (tester) async {
    final results = List.generate(
      9,
      (i) => result(id: i + 1, name: 'Produk ${i + 1}', dailyVelocity: (9 - i).toDouble()),
    );

    await pumpChart(tester, results);

    for (var id = 1; id <= 7; id++) {
      expect(find.byKey(Key('frequently_sold_chart_bar_$id')), findsOneWidget);
    }
    expect(find.byKey(const Key('frequently_sold_chart_bar_8')), findsNothing);
    expect(find.byKey(const Key('frequently_sold_chart_bar_9')), findsNothing);
  });

  testWidgets('shows the product name and formatted velocity on each bar', (tester) async {
    await pumpChart(tester, [result(id: 1, name: 'Kopi Kapal Api', dailyVelocity: 9)]);

    expect(find.text('Kopi Kapal Api'), findsOneWidget);
    expect(
      find.byKey(const Key('frequently_sold_chart_value_1')),
      findsOneWidget,
    );
    expect(find.text('~9/hari'), findsOneWidget);
  });

  testWidgets('respects a custom maxBars', (tester) async {
    final results = List.generate(
      5,
      (i) => result(id: i + 1, name: 'Produk ${i + 1}', dailyVelocity: (5 - i).toDouble()),
    );

    await pumpChart(tester, results, maxBars: 3);

    expect(find.byKey(const Key('frequently_sold_chart_bar_1')), findsOneWidget);
    expect(find.byKey(const Key('frequently_sold_chart_bar_3')), findsOneWidget);
    expect(find.byKey(const Key('frequently_sold_chart_bar_4')), findsNothing);
  });
}
