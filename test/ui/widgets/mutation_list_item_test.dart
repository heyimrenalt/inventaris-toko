import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/models/stock_mutation.dart';
import 'package:inventaris_toko/ui/widgets/mutation_list_item.dart';

void main() {
  StockMutation mutation({
    StockMutationType type = StockMutationType.stockIn,
    double quantity = 10,
    EnteredUnit? enteredUnit,
    double? enteredQuantity,
  }) {
    return StockMutation()
      ..id = 1
      ..productId = 1
      ..type = type
      ..quantity = quantity
      ..stockAfter = quantity
      ..enteredUnit = enteredUnit
      ..enteredQuantity = enteredQuantity
      ..createdAt = DateTime.now();
  }

  Future<void> pumpItem(WidgetTester tester, StockMutation forMutation) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MutationListItem(mutation: forMutation, productName: 'Indomie', unit: 'pcs'),
      ),
    ));
  }

  testWidgets('a legacy mutation (enteredUnit null) shows no entered-unit caption', (tester) async {
    await pumpItem(tester, mutation());

    expect(find.textContaining('dicatat:'), findsNothing);
  });

  testWidgets('enteredUnit pcs shows no caption (it would just repeat the primary line)',
      (tester) async {
    await pumpItem(tester, mutation(enteredUnit: EnteredUnit.pcs, enteredQuantity: 10));

    expect(find.textContaining('dicatat:'), findsNothing);
  });

  testWidgets('enteredUnit pack shows a "(dicatat: N pack)" caption', (tester) async {
    await pumpItem(
      tester,
      mutation(quantity: 24, enteredUnit: EnteredUnit.pack, enteredQuantity: 2),
    );

    expect(find.text('(dicatat: 2 pack)'), findsOneWidget);
  });

  testWidgets('enteredUnit dus shows a "(dicatat: N dus)" caption', (tester) async {
    await pumpItem(
      tester,
      mutation(quantity: 72, enteredUnit: EnteredUnit.dus, enteredQuantity: 1),
    );

    expect(find.text('(dicatat: 1 dus)'), findsOneWidget);
  });

  testWidgets('the primary line always shows the canonical pcs quantity regardless of enteredUnit',
      (tester) async {
    await pumpItem(
      tester,
      mutation(quantity: 72, enteredUnit: EnteredUnit.dus, enteredQuantity: 1),
    );

    expect(find.text('+72 pcs'), findsOneWidget);
  });
}
