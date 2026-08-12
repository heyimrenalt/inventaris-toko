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

      // Decimal key blocked for a non-fractional product — "2.5" is stripped
      // to "25", so a fraction can never be entered.
      await tester.enterText(find.byKey(const Key('unit_qty_field_1')), '2.5');
      await tester.pump();

      final text = tester.widget<TextField>(find.byKey(const Key('unit_qty_field_1'))).controller!.text;
      expect(text.contains('.'), isFalse);
      expect(text, '25');
      expect(capturedQty, isNotNull);
      expect(capturedQty, capturedQty!.roundToDouble());
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

      // Pack is always whole — decimal key blocked, "2.5" stripped to "25".
      await tester.enterText(find.byKey(const Key('unit_qty_field_1')), '2.5');
      await tester.pump();

      final text = tester.widget<TextField>(find.byKey(const Key('unit_qty_field_1'))).controller!.text;
      expect(text.contains('.'), isFalse);
      expect(text, '25');
      expect(capturedQty, isNotNull);
      expect(capturedQty, capturedQty!.roundToDouble());
    },
  );

  testWidgets(
    'dus mode blocks a fractional value even for a product with allowsFractionalQuantity: true '
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

      // Dus is always whole — decimal key blocked, "." stripped from "0.5".
      await tester.enterText(find.byKey(const Key('unit_qty_field_1')), '0.5');
      await tester.pump();

      final text = tester.widget<TextField>(find.byKey(const Key('unit_qty_field_1'))).controller!.text;
      expect(text.contains('.'), isFalse);
      if (capturedQty != null) {
        expect(capturedQty, capturedQty!.roundToDouble());
      }
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

  group('switching unit with a value that does not divide evenly', () {
    String fieldText(WidgetTester tester) =>
        tester.widget<TextField>(find.byKey(const Key('unit_qty_field_1'))).controller!.text;

    Future<void> tapUnit(WidgetTester tester, String label) async {
      await tester.tap(find.descendant(
        of: find.byKey(const Key('unit_qty_toggle_1')),
        matching: find.text(label),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('clears the field and explains, instead of silently rounding', (tester) async {
      double? capturedQty;
      EnteredUnit? capturedUnit;
      await pumpField(
        tester,
        forProduct: product(unitsPerPack: 12),
        // 5 pcs is 0.41666… pack — not a whole pack.
        initialQtyInPcs: 5,
        initialEnteredUnit: EnteredUnit.pcs,
        onChanged: (qty, unit, _) {
          capturedQty = qty;
          capturedUnit = unit;
        },
      );

      await tapUnit(tester, 'pack');

      // Emptied, *not* rounded to "0" or "1" — a rounded value is a
      // quantity the user never entered.
      expect(fieldText(tester), '');
      expect(find.byKey(const Key('unit_qty_error_1')), findsOneWidget);
      expect(find.textContaining('dikosongkan'), findsOneWidget);

      // The switch itself still happened, so the user isn't stranded.
      expect(capturedUnit, EnteredUnit.pack);
      // Zero, so submit rejects it rather than recording the stale 5 pcs.
      expect(capturedQty, 0);
    });

    testWidgets('a continuous pcs value switching to a discrete unit is cleared, not rounded',
        (tester) async {
      double? capturedQty;
      await pumpField(
        tester,
        forProduct: product(unitsPerPack: 4, allowsFractionalQuantity: true),
        initialQtyInPcs: 2.5,
        initialEnteredUnit: EnteredUnit.pcs,
        onChanged: (qty, _, _) => capturedQty = qty,
      );
      expect(fieldText(tester), '2.5');

      await tapUnit(tester, 'pack');

      expect(fieldText(tester), '');
      expect(capturedQty, 0);
    });

    testWidgets('a value that does divide evenly switches across intact', (tester) async {
      double? capturedQty;
      double? capturedEntered;
      await pumpField(
        tester,
        forProduct: product(unitsPerPack: 12),
        initialQtyInPcs: 24,
        initialEnteredUnit: EnteredUnit.pcs,
        onChanged: (qty, _, entered) {
          capturedQty = qty;
          capturedEntered = entered;
        },
      );

      await tapUnit(tester, 'pack');

      expect(fieldText(tester), '2');
      expect(capturedEntered, 2);
      // Round-trips back to exactly the pcs it started from.
      expect(capturedQty, 24);
      expect(find.byKey(const Key('unit_qty_error_1')), findsNothing);
    });

    testWidgets('switching from a discrete unit back to continuous pcs keeps the value',
        (tester) async {
      double? capturedQty;
      await pumpField(
        tester,
        forProduct: product(unitsPerPack: 4, allowsFractionalQuantity: true),
        initialQtyInPcs: 8,
        initialEnteredUnit: EnteredUnit.pack,
        onChanged: (qty, _, _) => capturedQty = qty,
      );
      expect(fieldText(tester), '2');

      await tapUnit(tester, 'pcs');

      expect(fieldText(tester), '8');
      expect(capturedQty, 8);
    });
  });

  group('empty, zero and negative input', () {
    testWidgets('an emptied field reports nothing new, leaving the last value to submit-time '
        'validation', (tester) async {
      double? capturedQty;
      await pumpField(
        tester,
        forProduct: product(),
        initialQtyInPcs: 3,
        initialEnteredUnit: EnteredUnit.pcs,
        onChanged: (qty, _, _) => capturedQty = qty,
      );

      await tester.enterText(find.byKey(const Key('unit_qty_field_1')), '');
      await tester.pump();

      // Unparseable text never propagates a quantity.
      expect(capturedQty, isNull);
    });

    testWidgets('zero is reported but is not submittable', (tester) async {
      double? capturedQty;
      await pumpField(
        tester,
        forProduct: product(),
        initialQtyInPcs: 3,
        initialEnteredUnit: EnteredUnit.pcs,
        onChanged: (qty, _, _) => capturedQty = qty,
      );

      await tester.enterText(find.byKey(const Key('unit_qty_field_1')), '0');
      await tester.pump();

      // The field allows 0 while typing (you have to pass through it to
      // reach "10"); CatatMutasiScreen and StockMutationRepository are what
      // reject it at submit.
      expect(capturedQty, 0);
      expect(capturedQty!, lessThanOrEqualTo(0));
    });

    testWidgets('a negative value cannot be entered — the minus key is filtered out',
        (tester) async {
      double? capturedQty;
      await pumpField(
        tester,
        forProduct: product(allowsFractionalQuantity: true),
        initialQtyInPcs: 3,
        initialEnteredUnit: EnteredUnit.pcs,
        onChanged: (qty, _, _) => capturedQty = qty,
      );

      await tester.enterText(find.byKey(const Key('unit_qty_field_1')), '-5');
      await tester.pump();

      expect(
        tester.widget<TextField>(find.byKey(const Key('unit_qty_field_1'))).controller!.text,
        isNot(contains('-')),
      );
      // The whole edit is refused, so no new quantity is reported at all —
      // and certainly never a negative one.
      expect(capturedQty ?? 0, isNonNegative);
    });

    testWidgets('the decrement stepper stops at zero and never goes negative', (tester) async {
      await pumpField(
        tester,
        forProduct: product(),
        initialQtyInPcs: 1,
        initialEnteredUnit: EnteredUnit.pcs,
        onChanged: (_, _, _) {},
      );

      await tester.tap(find.byKey(const Key('unit_qty_stepper_minus_1')));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byKey(const Key('unit_qty_field_1'))).controller!.text,
        '0',
      );

      // At zero the button is disabled outright.
      final minus = tester.widget<IconButton>(find.byKey(const Key('unit_qty_stepper_minus_1')));
      expect(minus.onPressed, isNull);
    });
  });
}
