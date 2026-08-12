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

      // The decimal key is blocked outright for a non-fractional pcs field,
      // so "2.5" can't be entered at all — the "." is stripped to "25".
      await tester.enterText(find.byKey(const Key('kulakan_qty_field_1')), '2.5');
      await tester.pump();

      final text = tester.widget<TextField>(find.byKey(const Key('kulakan_qty_field_1'))).controller!.text;
      expect(text.contains('.'), isFalse);
      expect(text, '25');
      // Whatever was captured is a whole number — a fraction is impossible.
      expect(capturedQty, isNotNull);
      expect(capturedQty, capturedQty!.roundToDouble());
    },
  );

  testWidgets('pack mode blocks a fractional pack quantity (decimal key stripped)', (tester) async {
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

    final text = tester.widget<TextField>(find.byKey(const Key('kulakan_qty_field_1'))).controller!.text;
    expect(text.contains('.'), isFalse);
    expect(text, '25');
    // No fractional pack quantity can ever reach onChanged.
    expect(capturedQty, isNotNull);
    expect(capturedQty, capturedQty!.roundToDouble());
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

      // Dus is always whole even when the product allows fractional pcs —
      // the decimal key is blocked, so "0.5" is stripped to "05" ("."
      // removed) and no fractional dus can be entered.
      await tester.enterText(find.byKey(const Key('kulakan_qty_field_1')), '0.5');
      await tester.pump();

      final text = tester.widget<TextField>(find.byKey(const Key('kulakan_qty_field_1'))).controller!.text;
      expect(text.contains('.'), isFalse);
      // Any value that did reach onChanged is a whole number of pcs.
      if (capturedQty != null) {
        expect(capturedQty, capturedQty!.roundToDouble());
      }
    });
  });

  group('field sizing', () {
    /// Width the field's own text needs, measured the way the field does.
    double neededWidth(WidgetTester tester, String text) {
      final style = Theme.of(tester.element(find.byType(RestockQtyField)))
          .textTheme
          .bodyLarge;
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      return painter.width;
    }

    double fieldWidth(WidgetTester tester) =>
        tester.getSize(find.byKey(const Key('kulakan_qty_field_1'))).width;

    testWidgets('pcs-only 5-digit value is not clipped by the "pcs" suffix', (tester) async {
      await pumpField(
        tester,
        unitsPerPack: null,
        initialQtyInPcs: 10000,
        initialInputUnitWasPack: false,
        onChanged: (_, _) {},
      );

      expect(fieldWidth(tester), greaterThan(neededWidth(tester, '10000pcs')));
    });

    testWidgets('field grows as digits are typed and never below the 1-digit width',
        (tester) async {
      await pumpField(
        tester,
        unitsPerPack: null,
        initialQtyInPcs: 0,
        initialInputUnitWasPack: false,
        onChanged: (_, _) {},
      );
      final oneDigit = fieldWidth(tester);
      expect(oneDigit, greaterThan(neededWidth(tester, '0pcs')));

      await tester.enterText(find.byKey(const Key('kulakan_qty_field_1')), '10000');
      await tester.pump();

      expect(fieldWidth(tester), greaterThan(oneDigit));
    });

    testWidgets('pack/dus variant fits a 5-digit value too', (tester) async {
      await pumpField(
        tester,
        unitsPerPack: 12,
        unitsPerDus: 4,
        initialQtyInPcs: 10000 * 12 * 4,
        initialInputUnitWasPack: false,
        onChanged: (_, _) {},
      );

      await tester.enterText(find.byKey(const Key('kulakan_qty_field_1')), '10000');
      await tester.pump();

      expect(fieldWidth(tester), greaterThan(neededWidth(tester, '10000')));
    });

    testWidgets('narrow screen with a large qty does not overflow the row', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: Row(
              children: [
                Checkbox(value: false, onChanged: (_) {}),
                const Expanded(child: Text('Nama produk yang panjang sekali')),
                RestockQtyField(
                  productId: 1,
                  unitsPerPack: 12,
                  unitsPerDus: 4,
                  initialQtyInPcs: 99999,
                  initialInputUnitWasPack: false,
                  allowsFractionalQuantity: false,
                  onChanged: (_, _) {},
                ),
              ],
            ),
          ),
        ),
      ));

      expect(tester.takeException(), isNull);
    });
  });

  group('switching unit with a value that does not divide evenly', () {
    String fieldText(WidgetTester tester) =>
        tester.widget<TextField>(find.byKey(const Key('kulakan_qty_field_1'))).controller!.text;

    Future<void> tapUnit(WidgetTester tester, String label) async {
      await tester.tap(find.descendant(
        of: find.byKey(const Key('kulakan_qty_unit_toggle_1')),
        matching: find.text(label),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('clears the field and explains, instead of silently rounding', (tester) async {
      double? capturedQty;
      await pumpField(
        tester,
        unitsPerPack: 12,
        // 5 pcs is a fraction of a pack.
        initialQtyInPcs: 5,
        initialInputUnitWasPack: false,
        onChanged: (qty, _) => capturedQty = qty,
      );

      await tapUnit(tester, 'pack');

      expect(fieldText(tester), '');
      expect(find.byKey(const Key('kulakan_qty_error_1')), findsOneWidget);
      expect(find.textContaining('dikosongkan'), findsOneWidget);
      expect(capturedQty, 0);
    });

    testWidgets('a value that does divide evenly switches across intact', (tester) async {
      double? capturedQty;
      bool? capturedWasPack;
      await pumpField(
        tester,
        unitsPerPack: 12,
        initialQtyInPcs: 24,
        initialInputUnitWasPack: false,
        onChanged: (qty, wasPack) {
          capturedQty = qty;
          capturedWasPack = wasPack;
        },
      );

      await tapUnit(tester, 'pack');

      expect(fieldText(tester), '2');
      expect(capturedQty, 24);
      expect(capturedWasPack, isTrue);
      expect(find.byKey(const Key('kulakan_qty_error_1')), findsNothing);
    });
  });
}
