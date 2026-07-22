import '../data/models/stock_mutation.dart';

/// Pure pcs/pack/dus quantity conversion and formatting. No Isar/Flutter
/// dependency, so it's unit-testable standalone — same shape as
/// [HppCalculator]/[VelocityCalculator].
///
/// A dus converts relative to whatever the next-smaller configured unit
/// is: when [unitsPerPack] is set, [unitsPerDus] means packs-per-dus
/// (e.g. `unitsPerPack: 2, unitsPerDus: 3` → 1 dus = 3 pack = 6 pcs).
/// When [unitsPerPack] is `null`, [unitsPerDus] means pcs-per-dus
/// directly — real kulakan goods aren't always 3 tiers deep (e.g. "1 dus
/// = 12 pcs" with no pack in between at all). See
/// [Product.unitsPerDus]/[ProductRepository] for the same rule.
class UnitConversion {
  const UnitConversion._();

  /// Converts [value] (expressed in [unit]) to canonical pcs.
  ///
  /// Throws [ArgumentError] if [unit] needs a conversion factor that's
  /// null ([unitsPerPack] for pack, [unitsPerDus] for dus).
  static double toPcs({
    required double value,
    required EnteredUnit unit,
    required int? unitsPerPack,
    required int? unitsPerDus,
  }) {
    switch (unit) {
      case EnteredUnit.pcs:
        return value;
      case EnteredUnit.pack:
        if (unitsPerPack == null) {
          throw ArgumentError('unitsPerPack is null, cannot convert from pack');
        }
        return value * unitsPerPack;
      case EnteredUnit.dus:
        if (unitsPerDus == null) {
          throw ArgumentError('unitsPerDus is null, cannot convert from dus');
        }
        // Relative to pack if it exists, otherwise straight to pcs.
        final dusInPcs = unitsPerPack == null ? unitsPerDus : unitsPerDus * unitsPerPack;
        return value * dusInPcs;
    }
  }

  /// Converts a canonical [qtyInPcs] to [unit]. Inverse of [toPcs].
  static double fromPcs({
    required double qtyInPcs,
    required EnteredUnit unit,
    required int? unitsPerPack,
    required int? unitsPerDus,
  }) {
    switch (unit) {
      case EnteredUnit.pcs:
        return qtyInPcs;
      case EnteredUnit.pack:
        if (unitsPerPack == null) {
          throw ArgumentError('unitsPerPack is null, cannot convert to pack');
        }
        return qtyInPcs / unitsPerPack;
      case EnteredUnit.dus:
        if (unitsPerDus == null) {
          throw ArgumentError('unitsPerDus is null, cannot convert to dus');
        }
        final dusInPcs = unitsPerPack == null ? unitsPerDus : unitsPerDus * unitsPerPack;
        return qtyInPcs / dusInPcs;
    }
  }

  /// Which units are legitimately offerable for a product with the given
  /// conversion factors — pcs is always included; pack and dus are each
  /// included independently, whenever their own factor is set (dus does
  /// *not* require pack — see the class doc comment).
  static List<EnteredUnit> availableUnitsFor({
    required int? unitsPerPack,
    required int? unitsPerDus,
  }) {
    final units = [EnteredUnit.pcs];
    if (unitsPerPack != null) units.add(EnteredUnit.pack);
    if (unitsPerDus != null) units.add(EnteredUnit.dus);
    return units;
  }

  /// "1 dus (3 pack, 6 pcs)" — [value] in [unit], the entered unit
  /// leading, followed by a parenthetical breakdown into every unit
  /// smaller than [unit] that the product supports. Degrades to a plain
  /// "24 pcs" when [unit] is already [EnteredUnit.pcs], and to "1 dus
  /// (12 pcs)" (no pack parenthetical) for a dus defined directly in pcs.
  static String formatCaption({
    required double value,
    required EnteredUnit unit,
    required int? unitsPerPack,
    required int? unitsPerDus,
  }) {
    final leading = '${_formatNumber(value)} ${_unitLabel(unit)}';
    if (unit == EnteredUnit.pcs) return leading;

    final qtyInPcs =
        toPcs(value: value, unit: unit, unitsPerPack: unitsPerPack, unitsPerDus: unitsPerDus);

    final parts = <String>[];
    if (unit == EnteredUnit.dus && unitsPerPack != null) {
      final packs = fromPcs(
        qtyInPcs: qtyInPcs,
        unit: EnteredUnit.pack,
        unitsPerPack: unitsPerPack,
        unitsPerDus: unitsPerDus,
      );
      parts.add('${_formatNumber(packs)} pack');
    }
    parts.add('${_formatNumber(qtyInPcs)} pcs');

    return '$leading (${parts.join(', ')})';
  }

  static String _unitLabel(EnteredUnit unit) {
    switch (unit) {
      case EnteredUnit.pcs:
        return 'pcs';
      case EnteredUnit.pack:
        return 'pack';
      case EnteredUnit.dus:
        return 'dus';
    }
  }
}

String _formatNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(1);
}
