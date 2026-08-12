import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/models/stock_mutation.dart';
import 'package:inventaris_toko/domain/unit_conversion.dart';
import 'package:inventaris_toko/domain/unit_quantity_rules.dart';

void main() {
  /// Drives a formatter the way the framework does: [oldText] is what the
  /// field already held, [newText] is what the edit (typed *or* pasted)
  /// would make it, and the return is what actually lands in the field.
  String applyFormatters(
    List<TextInputFormatter> formatters, {
    required String oldText,
    required String newText,
  }) {
    var value = TextEditingValue(
      text: oldText,
      selection: TextSelection.collapsed(offset: oldText.length),
    );
    final incoming = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
    for (final formatter in formatters) {
      value = formatter.formatEditUpdate(value, incoming);
    }
    return value.text;
  }

  List<TextInputFormatter> formattersFor(EnteredUnit unit, {required bool fractional}) =>
      UnitQuantityRules.inputFormatters(unit: unit, productAllowsFractional: fractional);

  group('unit classification', () {
    test('pack and dus are discrete packaging; pcs defers to the product', () {
      expect(EnteredUnit.pack.isDiscretePackaging, isTrue);
      expect(EnteredUnit.dus.isDiscretePackaging, isTrue);
      expect(EnteredUnit.pcs.isDiscretePackaging, isFalse);
    });

    test('a discrete unit forbids decimals even when the product allows fractions', () {
      for (final unit in [EnteredUnit.pack, EnteredUnit.dus]) {
        expect(
          UnitQuantityRules.allowsDecimal(unit: unit, productAllowsFractional: true),
          isFalse,
          reason: '$unit is countable packaging — half a $unit cannot exist',
        );
      }
    });

    test('pcs allows decimals only for a product measured rather than counted', () {
      expect(
        UnitQuantityRules.allowsDecimal(unit: EnteredUnit.pcs, productAllowsFractional: true),
        isTrue,
      );
      expect(
        UnitQuantityRules.allowsDecimal(unit: EnteredUnit.pcs, productAllowsFractional: false),
        isFalse,
      );
    });

    test('the keyboard drops its decimal key exactly when decimals are forbidden', () {
      expect(
        UnitQuantityRules.keyboardType(unit: EnteredUnit.pack, productAllowsFractional: true),
        const TextInputType.numberWithOptions(decimal: false),
      );
      expect(
        UnitQuantityRules.keyboardType(unit: EnteredUnit.pcs, productAllowsFractional: true),
        const TextInputType.numberWithOptions(decimal: true),
      );
    });
  });

  group('discrete unit input formatter', () {
    test('strips "." and "," so a fractional pack can never be typed', () {
      final formatters = formattersFor(EnteredUnit.pack, fractional: true);

      expect(applyFormatters(formatters, oldText: '0', newText: '0.'), '0');
      expect(applyFormatters(formatters, oldText: '0', newText: '0,'), '0');
      // The exact input that produced the bad "0.4 pack" record.
      expect(applyFormatters(formatters, oldText: '', newText: '0.4'), '04');
    });

    test('blocks a *pasted* decimal string, not just keystrokes', () {
      final formatters = formattersFor(EnteredUnit.dus, fractional: true);

      // A paste arrives as one whole-value replacement rather than a
      // character at a time, so it has to be filtered on the value.
      expect(applyFormatters(formatters, oldText: '', newText: '2.5'), '25');
      expect(applyFormatters(formatters, oldText: '', newText: '1,75'), '175');
    });

    test('rejects a negative sign', () {
      final formatters = formattersFor(EnteredUnit.pcs, fractional: false);
      expect(applyFormatters(formatters, oldText: '', newText: '-3'), '3');
    });
  });

  group('continuous unit input formatter', () {
    final formatters = formattersFor(EnteredUnit.pcs, fractional: true);

    test('allows one decimal separator, either "." or ","', () {
      expect(applyFormatters(formatters, oldText: '2', newText: '2.'), '2.');
      expect(applyFormatters(formatters, oldText: '2', newText: '2.5'), '2.5');
      expect(applyFormatters(formatters, oldText: '2', newText: '2,5'), '2,5');
    });

    test('rejects a second separator, leaving the field untouched', () {
      expect(applyFormatters(formatters, oldText: '1.2', newText: '1.2.'), '1.2');
      expect(applyFormatters(formatters, oldText: '1.2', newText: '1.2,3'), '1.2');
    });

    test('rejects more than ${UnitQuantityRules.maxDecimalPlaces} decimal places', () {
      expect(applyFormatters(formatters, oldText: '0.12', newText: '0.123'), '0.123');
      // The 4th decimal is refused outright rather than truncated, so the
      // user never sees a number silently different from what they entered.
      expect(applyFormatters(formatters, oldText: '0.123', newText: '0.1234'), '0.123');
    });

    test('allows clearing the field', () {
      expect(applyFormatters(formatters, oldText: '2.5', newText: ''), '');
    });

    test('rejects a pasted malformed number wholesale', () {
      expect(applyFormatters(formatters, oldText: '7', newText: '1.2.3'), '7');
      expect(applyFormatters(formatters, oldText: '7', newText: '0.4567'), '7');
      expect(applyFormatters(formatters, oldText: '7', newText: 'abc'), '7');
    });
  });

  group('discrete conversion stays exact', () {
    test('an integer pack quantity yields an exactly integer pcs count', () {
      // Float drift here would write a stockAfter like 39.99999 into the
      // ledger, so the result must be integral, not merely close.
      for (final unitsPerPack in [2, 3, 6, 7, 10, 12, 24]) {
        for (final packs in [1, 3, 5, 40, 999]) {
          final pcs = UnitConversion.toPcs(
            value: packs.toDouble(),
            unit: EnteredUnit.pack,
            unitsPerPack: unitsPerPack,
            unitsPerDus: null,
          );
          expect(pcs, packs * unitsPerPack);
          expect(pcs, pcs.roundToDouble(), reason: '$packs pack of $unitsPerPack drifted');
        }
      }
    });

    test('an integer dus quantity yields an exactly integer pcs count through both tiers', () {
      final pcs = UnitConversion.toPcs(
        value: 5,
        unit: EnteredUnit.dus,
        unitsPerPack: 12,
        unitsPerDus: 8,
      );
      expect(pcs, 480);
      expect(pcs, pcs.roundToDouble());
    });
  });
}
