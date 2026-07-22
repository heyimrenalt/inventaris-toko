import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/models/product.dart';
import 'package:inventaris_toko/data/models/stock_mutation.dart';
import 'package:inventaris_toko/ui/widgets/unit_qty_field.dart';

void main() {
  Product product({
    int id = 1,
    int? unitsPerPack,
    int? unitsPerDus,
    bool allowsFractionalQuantity = false,
  }) {
    return Product()
      ..id = id
      ..name = 'Test Product'
      ..sellPrice = 1000
      ..unit = 'pcs'
      ..currentStock = 100
      ..minStockThreshold = 5
      ..unitsPerPack = unitsPerPack
      ..unitsPerDus = unitsPerDus
      ..allowsFractionalQuantity = allowsFractionalQuantity
      ..createdAt = DateTime(2026, 1, 1)
      ..updatedAt = DateTime(2026, 1, 1);
  }

  Future<void> pumpField(
    WidgetTester tester, {
    required Product forProduct,
    required double initialQtyInPcs,
    required EnteredUnit initialEnteredUnit,
    required void Function(double qtyInPcs, EnteredUnit unit, double enteredValue) onChanged,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: UnitQtyField(
          product: forProduct,
          initialQtyInPcs: initialQtyInPcs,
          initialEnteredUnit: initialEnteredUnit,
          onChanged: onChanged,
        ),
      ),
    ));
  }

  testWidgets('pcs-only product renders no unit toggle', (tester) async {
    await pumpField(
      tester,
      forProduct: product(),
      initialQtyInPcs: 5,
      initialEnteredUnit: EnteredUnit.pcs,
      onChanged: (_, _, _) {},
    );

    expect(find.byKey(const Key('unit_qty_toggle_1')), findsNothing);
    expect(find.byKey(const Key('unit_qty_field_1')), findsOneWidget);
  });

  testWidgets('pack-only product offers a 2-way pcs/pack toggle', (tester) async {
    await pumpField(
      tester,
      forProduct: product(unitsPerPack: 12),
      initialQtyInPcs: 0,
      initialEnteredUnit: EnteredUnit.pcs,
      onChanged: (_, _, _) {},
    );

    final toggle = find.byKey(const Key('unit_qty_toggle_1'));
    expect(toggle, findsOneWidget);
    expect(find.descendant(of: toggle, matching: find.text('pcs')), findsOneWidget);
    expect(find.descendant(of: toggle, matching: find.text('pack')), findsOneWidget);
    expect(find.descendant(of: toggle, matching: find.text('dus')), findsNothing);
  });

  testWidgets('dus-capable product offers a 3-way pcs/pack/dus toggle', (tester) async {
    await pumpField(
      tester,
      forProduct: product(unitsPerPack: 12, unitsPerDus: 6),
      initialQtyInPcs: 0,
      initialEnteredUnit: EnteredUnit.pcs,
      onChanged: (_, _, _) {},
    );

    final toggle = find.byKey(const Key('unit_qty_toggle_1'));
    expect(find.descendant(of: toggle, matching: find.text('pcs')), findsOneWidget);
    expect(find.descendant(of: toggle, matching: find.text('pack')), findsOneWidget);
    expect(find.descendant(of: toggle, matching: find.text('dus')), findsOneWidget);
  });

  testWidgets(
    'a dus-only product (no pack tier) offers a 2-way pcs/dus toggle, and dus converts straight '
    'to pcs',
    (tester) async {
      double? capturedQty;
      await pumpField(
        tester,
        forProduct: product(unitsPerDus: 12),
        initialQtyInPcs: 0,
        initialEnteredUnit: EnteredUnit.dus,
        onChanged: (qty, _, _) => capturedQty = qty,
      );

      final toggle = find.byKey(const Key('unit_qty_toggle_1'));
      expect(find.descendant(of: toggle, matching: find.text('pcs')), findsOneWidget);
      expect(find.descendant(of: toggle, matching: find.text('pack')), findsNothing);
      expect(find.descendant(of: toggle, matching: find.text('dus')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('unit_qty_field_1')), '1');
      await tester.pump();

      expect(capturedQty, 12);
      expect(find.text('1 dus (12 pcs)'), findsOneWidget);
    },
  );

  testWidgets('entering "1" in dus mode reports the correct pcs conversion and caption',
      (tester) async {
    double? capturedQty;
    EnteredUnit? capturedUnit;
    double? capturedValue;
    await pumpField(
      tester,
      forProduct: product(unitsPerPack: 12, unitsPerDus: 6),
      initialQtyInPcs: 0,
      initialEnteredUnit: EnteredUnit.dus,
      onChanged: (qty, unit, value) {
        capturedQty = qty;
        capturedUnit = unit;
        capturedValue = value;
      },
    );

    await tester.enterText(find.byKey(const Key('unit_qty_field_1')), '1');
    await tester.pump();

    expect(capturedQty, 72);
    expect(capturedUnit, EnteredUnit.dus);
    expect(capturedValue, 1);
    expect(find.text('1 dus (6 pack, 72 pcs)'), findsOneWidget);
  });

  testWidgets('switching from dus to pack recomputes the displayed value', (tester) async {
    await pumpField(
      tester,
      forProduct: product(unitsPerPack: 12, unitsPerDus: 6),
      initialQtyInPcs: 72,
      initialEnteredUnit: EnteredUnit.dus,
      onChanged: (_, _, _) {},
    );

    await tester.tap(find.descendant(
      of: find.byKey(const Key('unit_qty_toggle_1')),
      matching: find.text('pack'),
    ));
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byKey(const Key('unit_qty_field_1'))).controller!.text,
      '6',
    );
  });

  testWidgets(
    'rejects a fractional value in every unit for a product with allowsFractionalQuantity: false (default)',
    (tester) async {
      double? capturedQty;
      await pumpField(
        tester,
        forProduct: product(unitsPerPack: 12, unitsPerDus: 6),
        initialQtyInPcs: 0,
        initialEnteredUnit: EnteredUnit.pcs,
        onChanged: (qty, _, _) => capturedQty = qty,
      );

      await tester.enterText(find.byKey(const Key('unit_qty_field_1')), '2.5');
      await tester.pump();

      expect(find.byKey(const Key('unit_qty_error_1')), findsOneWidget);
      expect(find.text('Jumlah harus bilangan bulat'), findsOneWidget);
      expect(capturedQty, isNull);
    },
  );

  testWidgets('allows a fractional value in every unit for a product with allowsFractionalQuantity: true',
      (tester) async {
    double? capturedQty;
    await pumpField(
      tester,
      forProduct: product(allowsFractionalQuantity: true),
      initialQtyInPcs: 0,
      initialEnteredUnit: EnteredUnit.pcs,
      onChanged: (qty, _, _) => capturedQty = qty,
    );

    await tester.enterText(find.byKey(const Key('unit_qty_field_1')), '2.5');
    await tester.pump();

    expect(find.byKey(const Key('unit_qty_error_1')), findsNothing);
    expect(capturedQty, 2.5);
  });

  testWidgets(
    'pack mode rejects a fractional value even for a product with allowsFractionalQuantity: true '
    '— that flag only governs the base pcs unit',
    (tester) async {
      double? capturedQty;
      await pumpField(
        tester,
        forProduct: product(unitsPerPack: 12, unitsPerDus: 6, allowsFractionalQuantity: true),
        initialQtyInPcs: 0,
        initialEnteredUnit: EnteredUnit.pack,
        onChanged: (qty, _, _) => capturedQty = qty,
      );

      await tester.enterText(find.byKey(const Key('unit_qty_field_1')), '2.5');
      await tester.pump();

      expect(find.byKey(const Key('unit_qty_error_1')), findsOneWidget);
      expect(find.text('Jumlah pack harus bilangan bulat'), findsOneWidget);
      expect(capturedQty, isNull);
    },
  );

  testWidgets(
    'dus mode rejects a fractional value even for a product with allowsFractionalQuantity: true '
    '— that flag only governs the base pcs unit',
    (tester) async {
      double? capturedQty;
      await pumpField(
        tester,
        forProduct: product(unitsPerPack: 12, unitsPerDus: 6, allowsFractionalQuantity: true),
        initialQtyInPcs: 0,
        initialEnteredUnit: EnteredUnit.dus,
        onChanged: (qty, _, _) => capturedQty = qty,
      );

      await tester.enterText(find.byKey(const Key('unit_qty_field_1')), '0.5');
      await tester.pump();

      expect(find.byKey(const Key('unit_qty_error_1')), findsOneWidget);
      expect(find.text('Jumlah dus harus bilangan bulat'), findsOneWidget);
      expect(capturedQty, isNull);
    },
  );

  testWidgets('stepper + button increments by 1 in the currently selected unit', (tester) async {
    double? capturedQty;
    await pumpField(
      tester,
      forProduct: product(unitsPerPack: 12, unitsPerDus: 6),
      initialQtyInPcs: 72,
      initialEnteredUnit: EnteredUnit.dus,
      onChanged: (qty, _, _) => capturedQty = qty,
    );

    await tester.tap(find.byKey(const Key('unit_qty_stepper_plus_1')));
    await tester.pump();

    // 1 dus -> 2 dus == 144 pcs, not 73 pcs.
    expect(capturedQty, 144);
  });

  testWidgets('stepper - button never goes below 0', (tester) async {
    double? capturedQty;
    await pumpField(
      tester,
      forProduct: product(),
      initialQtyInPcs: 1,
      initialEnteredUnit: EnteredUnit.pcs,
      onChanged: (qty, _, _) => capturedQty = qty,
    );

    await tester.tap(find.byKey(const Key('unit_qty_stepper_minus_1')));
    await tester.pump();
    expect(capturedQty, 0);

    final minusButton =
        tester.widget<IconButton>(find.byKey(const Key('unit_qty_stepper_minus_1')));
    expect(minusButton.onPressed, isNull);
  });

  testWidgets('an initial entered unit no longer offered by the product falls back to pcs',
      (tester) async {
    // Simulates a product whose unitsPerDus was cleared after a mutation
    // was previously entered in dus.
    await pumpField(
      tester,
      forProduct: product(unitsPerPack: 12),
      initialQtyInPcs: 24,
      initialEnteredUnit: EnteredUnit.dus,
      onChanged: (_, _, _) {},
    );

    expect(
      tester.widget<TextField>(find.byKey(const Key('unit_qty_field_1'))).controller!.text,
      '24',
    );
  });
}
