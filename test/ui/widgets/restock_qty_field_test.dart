import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/ui/widgets/restock_qty_field.dart';

void main() {
  Future<void> pumpField(
    WidgetTester tester, {
    required int? unitsPerPack,
    int? unitsPerDus,
    required double initialQtyInPcs,
    required bool initialInputUnitWasPack,
    required void Function(double qtyInPcs, bool inputUnitWasPack) onChanged,
    bool allowsFractionalQuantity = false,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RestockQtyField(
          productId: 1,
          unitsPerPack: unitsPerPack,
          unitsPerDus: unitsPerDus,
          initialQtyInPcs: initialQtyInPcs,
          initialInputUnitWasPack: initialInputUnitWasPack,
          allowsFractionalQuantity: allowsFractionalQuantity,
          onChanged: onChanged,
        ),
      ),
    ));
  }

  testWidgets('pack input converts to pcs: unitsPerPack 12, typing 2 packs -> qtyInPcs 24',
      (tester) async {
    double? capturedQty;
    bool? capturedUnit;
    await pumpField(
      tester,
      unitsPerPack: 12,
      initialQtyInPcs: 0,
      initialInputUnitWasPack: true,
      onChanged: (qty, unit) {
        capturedQty = qty;
        capturedUnit = unit;
      },
    );

    await tester.enterText(find.byKey(const Key('kulakan_qty_field_1')), '2');
    await tester.pump();

    expect(capturedQty, 24);
    expect(capturedUnit, isTrue);
    expect(find.text('2 pack (24 pcs)'), findsOneWidget);
  });

  testWidgets(
    'unitsPerPack changed after saving (12 -> 10): a stored qtyInPcs of 24 stays 24 pcs, '
    'and the pack display recomputes to 2.4 pack',
    (tester) async {
      // Simulates reopening a previously-saved item after the product's
      // unitsPerPack was edited: qtyInPcs is canonical and untouched by
      // the change, only the pack-display conversion recomputes.
      await pumpField(
        tester,
        unitsPerPack: 10,
        initialQtyInPcs: 24,
        initialInputUnitWasPack: true,
        onChanged: (_, _) {},
      );

      expect(find.text('2.4 pack (24 pcs)'), findsOneWidget);
    },
  );

  testWidgets(
    'pcs mode allows a fractional quantity for a product with allowsFractionalQuantity: true (weighed goods)',
    (tester) async {
      double? capturedQty;
      await pumpField(
        tester,
        unitsPerPack: null,
        initialQtyInPcs: 0,
        initialInputUnitWasPack: false,
        allowsFractionalQuantity: true,
        onChanged: (qty, _) => capturedQty = qty,
      );

      await tester.enterText(find.byKey(const Key('kulakan_qty_field_1')), '2.5');
      await tester.pump();

      expect(capturedQty, 2.5);
    },
  );

  testWidgets(
    'pcs mode rejects a fractional quantity for a product with allowsFractionalQuantity: false (default)',
    (tester) async {
      double? capturedQty;
      await pumpField(
        tester,
        unitsPerPack: null,
        initialQtyInPcs: 0,
        initialInputUnitWasPack: false,
        onChanged: (qty, _) => capturedQty = qty,
      );

      await tester.enterText(find.byKey(const Key('kulakan_qty_field_1')), '2.5');
      await tester.pump();

      expect(find.byKey(const Key('kulakan_qty_error_1')), findsOneWidget);
      expect(find.text('Jumlah harus bilangan bulat'), findsOneWidget);
      expect(capturedQty, isNull);
    },
  );

  testWidgets('pack mode rejects a fractional pack quantity with an inline error', (tester) async {
    double? capturedQty;
    await pumpField(
      tester,
      unitsPerPack: 12,
      initialQtyInPcs: 12,
      initialInputUnitWasPack: true,
      onChanged: (qty, _) => capturedQty = qty,
    );

    await tester.enterText(find.byKey(const Key('kulakan_qty_field_1')), '2.5');
    await tester.pump();

    expect(find.byKey(const Key('kulakan_qty_error_1')), findsOneWidget);
    expect(find.text('Jumlah pack harus bilangan bulat'), findsOneWidget);
    // The last accepted value (the initial one) is what was ever reported —
    // the invalid 2.5 pack edit must never reach onChanged.
    expect(capturedQty, isNull);
  });

  testWidgets('pack mode accepts a whole-number pack quantity with no error', (tester) async {
    await pumpField(
      tester,
      unitsPerPack: 12,
      initialQtyInPcs: 12,
      initialInputUnitWasPack: true,
      onChanged: (_, _) {},
    );

    await tester.enterText(find.byKey(const Key('kulakan_qty_field_1')), '3');
    await tester.pump();

    expect(find.byKey(const Key('kulakan_qty_error_1')), findsNothing);
    expect(find.text('3 pack (36 pcs)'), findsOneWidget);
  });

  testWidgets('stepper + button increments by 1 pcs for a pcs-only field', (tester) async {
    double? capturedQty;
    await pumpField(
      tester,
      unitsPerPack: null,
      initialQtyInPcs: 5,
      initialInputUnitWasPack: false,
      onChanged: (qty, _) => capturedQty = qty,
    );

    await tester.tap(find.byKey(const Key('kulakan_qty_stepper_plus_1')));
    await tester.pump();

    expect(capturedQty, 6);
    expect(find.text('6'), findsOneWidget);
  });

  testWidgets('stepper - button decrements by 1 pcs and never goes below 0', (tester) async {
    double? capturedQty;
    await pumpField(
      tester,
      unitsPerPack: null,
      initialQtyInPcs: 1,
      initialInputUnitWasPack: false,
      onChanged: (qty, _) => capturedQty = qty,
    );

    await tester.tap(find.byKey(const Key('kulakan_qty_stepper_minus_1')));
    await tester.pump();
    expect(capturedQty, 0);

    final minusButton =
        tester.widget<IconButton>(find.byKey(const Key('kulakan_qty_stepper_minus_1')));
    expect(minusButton.onPressed, isNull);
  });

  testWidgets('stepper + button increments by 1 pack (not 1 pcs) when pack mode is active',
      (tester) async {
    double? capturedQty;
    await pumpField(
      tester,
      unitsPerPack: 12,
      initialQtyInPcs: 24,
      initialInputUnitWasPack: true,
      onChanged: (qty, _) => capturedQty = qty,
    );

    await tester.tap(find.byKey(const Key('kulakan_qty_stepper_plus_1')));
    await tester.pump();

    // 2 pack -> 3 pack == 36 pcs, not 25 pcs.
    expect(capturedQty, 36);
    expect(find.text('3 pack (36 pcs)'), findsOneWidget);
  });

  group('dus support', () {
    testWidgets(
      'unitsPerPack=6, unitsPerDus=6 offers a pcs/pack/dus toggle; switching to dus and typing '
      '"1" yields qtyInPcs=36',
      (tester) async {
        double? capturedQty;
        await pumpField(
          tester,
          unitsPerPack: 6,
          unitsPerDus: 6,
          initialQtyInPcs: 0,
          initialInputUnitWasPack: false,
          onChanged: (qty, _) => capturedQty = qty,
        );

        final toggle = find.byKey(const Key('kulakan_qty_unit_toggle_1'));
        expect(find.descendant(of: toggle, matching: find.text('pcs')), findsOneWidget);
        expect(find.descendant(of: toggle, matching: find.text('pack')), findsOneWidget);
        expect(find.descendant(of: toggle, matching: find.text('dus')), findsOneWidget);

        await tester.tap(find.descendant(of: toggle, matching: find.text('dus')));
        await tester.pump();

        await tester.enterText(find.byKey(const Key('kulakan_qty_field_1')), '1');
        await tester.pump();

        expect(capturedQty, 36);
        expect(find.text('1 dus (6 pack, 36 pcs)'), findsOneWidget);
      },
    );

    testWidgets(
      'unitsPerDus=12, unitsPerPack=null offers a pcs/dus toggle (no pack); typing "1" in dus '
      'yields qtyInPcs=12',
      (tester) async {
        double? capturedQty;
        await pumpField(
          tester,
          unitsPerPack: null,
          unitsPerDus: 12,
          initialQtyInPcs: 0,
          initialInputUnitWasPack: false,
          onChanged: (qty, _) => capturedQty = qty,
        );

        final toggle = find.byKey(const Key('kulakan_qty_unit_toggle_1'));
        expect(find.descendant(of: toggle, matching: find.text('pcs')), findsOneWidget);
        expect(find.descendant(of: toggle, matching: find.text('pack')), findsNothing);
        expect(find.descendant(of: toggle, matching: find.text('dus')), findsOneWidget);

        await tester.tap(find.descendant(of: toggle, matching: find.text('dus')));
        await tester.pump();

        await tester.enterText(find.byKey(const Key('kulakan_qty_field_1')), '1');
        await tester.pump();

        expect(capturedQty, 12);
        expect(find.text('1 dus (12 pcs)'), findsOneWidget);
      },
    );

    testWidgets('dus mode rejects a fractional quantity regardless of allowsFractionalQuantity',
        (tester) async {
      double? capturedQty;
      await pumpField(
        tester,
        unitsPerPack: 6,
        unitsPerDus: 6,
        initialQtyInPcs: 0,
        initialInputUnitWasPack: false,
        allowsFractionalQuantity: true,
        onChanged: (qty, _) => capturedQty = qty,
      );

      await tester.tap(find.descendant(
        of: find.byKey(const Key('kulakan_qty_unit_toggle_1')),
        matching: find.text('dus'),
      ));
      await tester.pump();
      // Switching units itself is a valid edit that reports the converted
      // value — reset here so the assertion below only reflects the
      // fractional-dus entry under test.
      capturedQty = null;

      await tester.enterText(find.byKey(const Key('kulakan_qty_field_1')), '0.5');
      await tester.pump();

      expect(find.byKey(const Key('kulakan_qty_error_1')), findsOneWidget);
      expect(find.text('Jumlah dus harus bilangan bulat'), findsOneWidget);
      expect(capturedQty, isNull);
    });
  });
}
