import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/models/stock_mutation.dart';
import 'package:inventaris_toko/domain/unit_conversion.dart';

void main() {
  group('toPcs', () {
    test('pcs is a no-op', () {
      final result = UnitConversion.toPcs(
        value: 5,
        unit: EnteredUnit.pcs,
        unitsPerPack: 12,
        unitsPerDus: 6,
      );
      expect(result, 5);
    });

    test('pack multiplies by unitsPerPack', () {
      final result = UnitConversion.toPcs(
        value: 2,
        unit: EnteredUnit.pack,
        unitsPerPack: 12,
        unitsPerDus: null,
      );
      expect(result, 24);
    });

    test('dus multiplies by unitsPerDus then unitsPerPack', () {
      // 1 dus = 6 pack = 72 pcs, given unitsPerPack: 12, unitsPerDus: 6.
      final result = UnitConversion.toPcs(
        value: 1,
        unit: EnteredUnit.dus,
        unitsPerPack: 12,
        unitsPerDus: 6,
      );
      expect(result, 72);
    });

    test('dus multiplies straight by unitsPerDus when there is no pack tier', () {
      // 1 dus = 12 pcs directly, no pack in between.
      final result = UnitConversion.toPcs(
        value: 1,
        unit: EnteredUnit.dus,
        unitsPerPack: null,
        unitsPerDus: 12,
      );
      expect(result, 12);
    });

    test('throws ArgumentError converting from pack with unitsPerPack null', () {
      expect(
        () => UnitConversion.toPcs(
          value: 1,
          unit: EnteredUnit.pack,
          unitsPerPack: null,
          unitsPerDus: null,
        ),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError converting from dus with unitsPerDus null', () {
      expect(
        () => UnitConversion.toPcs(
          value: 1,
          unit: EnteredUnit.dus,
          unitsPerPack: 12,
          unitsPerDus: null,
        ),
        throwsArgumentError,
      );
    });
  });

  group('fromPcs', () {
    test('pcs is a no-op', () {
      expect(
        UnitConversion.fromPcs(
          qtyInPcs: 24,
          unit: EnteredUnit.pcs,
          unitsPerPack: 12,
          unitsPerDus: null,
        ),
        24,
      );
    });

    test('pack divides by unitsPerPack', () {
      expect(
        UnitConversion.fromPcs(
          qtyInPcs: 24,
          unit: EnteredUnit.pack,
          unitsPerPack: 12,
          unitsPerDus: null,
        ),
        2,
      );
    });

    test('dus divides by unitsPerPack then unitsPerDus', () {
      expect(
        UnitConversion.fromPcs(
          qtyInPcs: 72,
          unit: EnteredUnit.dus,
          unitsPerPack: 12,
          unitsPerDus: 6,
        ),
        1,
      );
    });

    test('dus divides straight by unitsPerDus when there is no pack tier', () {
      expect(
        UnitConversion.fromPcs(
          qtyInPcs: 12,
          unit: EnteredUnit.dus,
          unitsPerPack: null,
          unitsPerDus: 12,
        ),
        1,
      );
    });

    test('is the inverse of toPcs', () {
      const original = 3.0;
      final pcs = UnitConversion.toPcs(
        value: original,
        unit: EnteredUnit.dus,
        unitsPerPack: 5,
        unitsPerDus: 4,
      );
      final back = UnitConversion.fromPcs(
        qtyInPcs: pcs,
        unit: EnteredUnit.dus,
        unitsPerPack: 5,
        unitsPerDus: 4,
      );
      expect(back, original);
    });
  });

  group('availableUnitsFor', () {
    test('pcs-only product only offers pcs', () {
      expect(
        UnitConversion.availableUnitsFor(unitsPerPack: null, unitsPerDus: null),
        [EnteredUnit.pcs],
      );
    });

    test('pack-capable product offers pcs and pack', () {
      expect(
        UnitConversion.availableUnitsFor(unitsPerPack: 12, unitsPerDus: null),
        [EnteredUnit.pcs, EnteredUnit.pack],
      );
    });

    test('dus-capable product offers all three, in ascending order', () {
      expect(
        UnitConversion.availableUnitsFor(unitsPerPack: 12, unitsPerDus: 6),
        [EnteredUnit.pcs, EnteredUnit.pack, EnteredUnit.dus],
      );
    });

    test('a dus with no pack tier offers pcs and dus, but not pack', () {
      expect(
        UnitConversion.availableUnitsFor(unitsPerPack: null, unitsPerDus: 6),
        [EnteredUnit.pcs, EnteredUnit.dus],
      );
    });
  });

  group('formatCaption', () {
    test('pcs degrades to a plain quantity, no parenthetical', () {
      final result = UnitConversion.formatCaption(
        value: 24,
        unit: EnteredUnit.pcs,
        unitsPerPack: 12,
        unitsPerDus: 6,
      );
      expect(result, '24 pcs');
    });

    test('pack shows a pcs breakdown', () {
      final result = UnitConversion.formatCaption(
        value: 2,
        unit: EnteredUnit.pack,
        unitsPerPack: 12,
        unitsPerDus: null,
      );
      expect(result, '2 pack (24 pcs)');
    });

    test('dus shows both pack and pcs breakdown', () {
      final result = UnitConversion.formatCaption(
        value: 1,
        unit: EnteredUnit.dus,
        unitsPerPack: 12,
        unitsPerDus: 6,
      );
      expect(result, '1 dus (6 pack, 72 pcs)');
    });

    test('dus with no pack tier shows only a pcs breakdown, no pack parenthetical', () {
      final result = UnitConversion.formatCaption(
        value: 1,
        unit: EnteredUnit.dus,
        unitsPerPack: null,
        unitsPerDus: 12,
      );
      expect(result, '1 dus (12 pcs)');
    });

    test('fractional values format to 1 decimal place', () {
      final result = UnitConversion.formatCaption(
        value: 1.5,
        unit: EnteredUnit.pack,
        unitsPerPack: 4,
        unitsPerDus: null,
      );
      expect(result, '1.5 pack (6 pcs)');
    });
  });
}
