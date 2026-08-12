import 'package:flutter/services.dart';

import '../data/models/stock_mutation.dart';

/// The single authoritative answer to "may this quantity be fractional?".
///
/// Two things decide it, and they live at different levels:
///
///  * [EnteredUnit.isDiscretePackaging] — a property of the *unit*. A pack
///    and a dus are countable packaging tiers: half a pack is not a thing
///    you can put on a shelf, whatever the goods inside are. This is
///    intrinsic and never overridable.
///  * [Product.allowsFractionalQuantity] — a property of the *product*.
///    [EnteredUnit.pcs] is this app's canonical base unit, and it is
///    deliberately generic: for beras or minyak it stands in for kg or
///    liter, and there "2.5 pcs" means 2.5 kg. So pcs is continuous only
///    when the product says its goods are measured rather than counted.
///
/// Everything that accepts a quantity — the mutation entry field
/// ([UnitQtyField]), the kulakan quantity field ([RestockQtyField]) — must
/// route through [allowsDecimal] rather than testing unit names itself, so
/// the classification lives in exactly one place.
class UnitQuantityRules {
  const UnitQuantityRules._();

  /// Decimal places accepted for a continuous quantity.
  ///
  /// Three, because the smallest unit anyone in a warung actually weighs
  /// out is a gram against a kg (0.001), and that is also where a double
  /// still round-trips through Isar and the "x,xxx" display without
  /// visible drift. Deeper precision would be noise the user can't read
  /// back off a receipt.
  static const int maxDecimalPlaces = 3;

  /// Whether a quantity entered in [unit] for a product whose
  /// [Product.allowsFractionalQuantity] is [productAllowsFractional] may
  /// carry a decimal part.
  static bool allowsDecimal({
    required EnteredUnit unit,
    required bool productAllowsFractional,
  }) =>
      !unit.isDiscretePackaging && productAllowsFractional;

  /// Keyboard for such a field — a discrete quantity gets a keyboard with
  /// no decimal separator key at all, so the block is visible to the user
  /// before they type rather than only enforced afterwards.
  static TextInputType keyboardType({
    required EnteredUnit unit,
    required bool productAllowsFractional,
  }) =>
      TextInputType.numberWithOptions(
        decimal: allowsDecimal(unit: unit, productAllowsFractional: productAllowsFractional),
      );

  /// Formatters for such a field. Both branches filter *pasted* text as
  /// well as keystrokes — [TextInputFormatter]s run on every edit
  /// regardless of its source, which is what makes a pasted "0.4" no
  /// easier to sneak in than a typed one.
  static List<TextInputFormatter> inputFormatters({
    required EnteredUnit unit,
    required bool productAllowsFractional,
  }) =>
      allowsDecimal(unit: unit, productAllowsFractional: productAllowsFractional)
          ? const [DecimalTextInputFormatter(maxDecimalPlaces: maxDecimalPlaces)]
          : [FilteringTextInputFormatter.digitsOnly];
}

extension EnteredUnitContinuity on EnteredUnit {
  /// `true` for the countable packaging tiers (pack, dus), which can never
  /// hold a fractional quantity.
  ///
  /// `false` for [EnteredUnit.pcs] — *not* because pcs is continuous, but
  /// because pcs alone defers to the product (see [UnitQuantityRules]). A
  /// pcs field for an ordinary countable product is still integer-only.
  bool get isDiscretePackaging {
    switch (this) {
      case EnteredUnit.pcs:
        return false;
      case EnteredUnit.pack:
      case EnteredUnit.dus:
        return true;
    }
  }
}

/// Accepts digits with at most one decimal separator ("." or ",", since an
/// Indonesian keyboard offers either) followed by at most
/// [maxDecimalPlaces] digits.
///
/// Rejects the whole edit rather than salvaging part of it: a paste of
/// "1.2.3" or "0.4567" leaves the field exactly as it was, instead of
/// being silently mangled into "1.23" or truncated to "0.456" — a quietly
/// altered number is worse than a rejected one, because the user has no
/// cue that what they see isn't what they entered.
class DecimalTextInputFormatter extends TextInputFormatter {
  const DecimalTextInputFormatter({required this.maxDecimalPlaces});

  final int maxDecimalPlaces;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    // Empty is always allowed — the user has to be able to clear the field
    // to retype it, and "empty" is rejected at submit, not while typing.
    if (text.isEmpty) return newValue;

    final pattern = RegExp('^[0-9]*([.,][0-9]{0,$maxDecimalPlaces})?\$');
    if (!pattern.hasMatch(text)) return oldValue;
    return newValue;
  }
}
