import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/stock_mutation.dart';
import '../../domain/unit_conversion.dart';
import '../../domain/unit_quantity_rules.dart';

/// Editable quantity input for one Kulakan List row.
///
/// For a product with no pack or dus tier configured this is a single
/// numeric field suffixed "pcs". Otherwise a toggle sits below the field
/// offering whichever of pcs/pack/dus [UnitConversion.availableUnitsFor]
/// says the product supports (same rule [UnitQtyField] uses) — typing in
/// pack or dus converts to pcs internally ([onChanged] always receives the
/// canonical pcs quantity), and a caption below shows the breakdown via
/// [UnitConversion.formatCaption] whenever the toggle isn't on pcs.
///
/// [initialInputUnitWasPack]/[onChanged]'s `bool` stays pack-vs-not for
/// backward compatibility with existing callers — it only distinguishes
/// pack from "everything else", so a dus selection round-trips through it
/// as "not pack" the same as pcs would.
///
/// A -/+ stepper always flanks the numeric field so the row stays
/// tappable without opening a keyboard — it steps by 1 in whatever unit
/// is currently displayed.
class RestockQtyField extends StatefulWidget {
  const RestockQtyField({
    super.key,
    required this.productId,
    required this.unitsPerPack,
    this.unitsPerDus,
    required this.initialQtyInPcs,
    required this.initialInputUnitWasPack,
    required this.allowsFractionalQuantity,
    required this.onChanged,
  });

  final int productId;
  final int? unitsPerPack;
  final int? unitsPerDus;
  final double initialQtyInPcs;
  final bool initialInputUnitWasPack;

  /// Mirrors [Product.allowsFractionalQuantity]. Combined with the unit's
  /// own discreteness by [UnitQuantityRules.allowsDecimal], which is the
  /// only place that decision is made — pack and dus are discrete there,
  /// so they never accept a fractional value regardless of this flag.
  final bool allowsFractionalQuantity;

  /// Called with the canonical pcs quantity and whether the field is
  /// currently in pack-input mode, on every valid edit.
  final void Function(double qtyInPcs, bool inputUnitWasPack) onChanged;

  @override
  State<RestockQtyField> createState() => _RestockQtyFieldState();
}

class _RestockQtyFieldState extends State<RestockQtyField> {
  late EnteredUnit _unit;
  late final TextEditingController _controller;
  String? _error;

  List<EnteredUnit> get _availableUnits => UnitConversion.availableUnitsFor(
        unitsPerPack: widget.unitsPerPack,
        unitsPerDus: widget.unitsPerDus,
      );

  @override
  void initState() {
    super.initState();
    _unit = (widget.initialInputUnitWasPack && widget.unitsPerPack != null)
        ? EnteredUnit.pack
        : EnteredUnit.pcs;
    final displayValue = _fromPcs(widget.initialQtyInPcs, _unit);
    _controller = TextEditingController(text: _formatNumber(displayValue));
    // The field sizes itself to its own text (see _columnWidthFor), so every
    // edit has to rebuild — including the ones _applyValue bails out of
    // (empty/unparseable text), which never reach its setState.
    _controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  double get _currentValue => double.tryParse(_controller.text.replaceAll(',', '.')) ?? 0;

  double _toPcs(double value, EnteredUnit unit) => UnitConversion.toPcs(
        value: value,
        unit: unit,
        unitsPerPack: widget.unitsPerPack,
        unitsPerDus: widget.unitsPerDus,
      );

  double _fromPcs(double qtyInPcs, EnteredUnit unit) => UnitConversion.fromPcs(
        qtyInPcs: qtyInPcs,
        unit: unit,
        unitsPerPack: widget.unitsPerPack,
        unitsPerDus: widget.unitsPerDus,
      );

  void _onTextChanged(String text) {
    final value = double.tryParse(text.replaceAll(',', '.'));
    if (value == null) return;
    _applyValue(value);
  }

  /// Whether [unit] forbids a decimal part — see [UnitQuantityRules],
  /// which is the only place that rule is decided.
  bool _requiresIntegerIn(EnteredUnit unit) => !UnitQuantityRules.allowsDecimal(
        unit: unit,
        productAllowsFractional: widget.allowsFractionalQuantity,
      );

  void _applyValue(double value) {
    if (_requiresIntegerIn(_unit) && value != value.roundToDouble()) {
      setState(() => _error = _integerErrorFor(_unit));
      return;
    }

    final qtyInPcs = _toPcs(value, _unit);
    // Recomputes the caption below the field and the stepper's enabled
    // state — neither is driven by the controller's own listenable, so a
    // plain text/stepper edit wouldn't otherwise trigger a rebuild.
    setState(() => _error = null);
    widget.onChanged(qtyInPcs, _unit == EnteredUnit.pack);
  }

  String _integerErrorFor(EnteredUnit unit) {
    switch (unit) {
      case EnteredUnit.pcs:
        return 'Jumlah harus bilangan bulat';
      case EnteredUnit.pack:
        if (widget.unitsPerPack == null) {
          return 'Jumlah pack harus bilangan bulat';
        }
        return 'Hanya bisa dijual per pack. Gunakan kelipatan ${widget.unitsPerPack} pcs';
      case EnteredUnit.dus:
        if (widget.unitsPerDus == null) {
          return 'Jumlah dus harus bilangan bulat';
        }
        final dusInPcs = widget.unitsPerPack == null
            ? widget.unitsPerDus!
            : widget.unitsPerDus! * widget.unitsPerPack!;
        return 'Hanya bisa dijual per dus. Gunakan kelipatan $dusInPcs pcs';
    }
  }

  /// Steps by 1 in whatever unit is currently displayed — since
  /// [_currentValue] is already expressed in that display unit.
  void _step(double delta) {
    final next = _currentValue + delta;
    if (next < 0) return;
    _controller.text = _formatNumber(next);
    _applyValue(next);
  }

  void _changeUnit(EnteredUnit newUnit) {
    if (newUnit == _unit) return;
    final displayValue = _fromPcs(_toPcs(_currentValue, _unit), newUnit);

    // Clears rather than rounds when the value doesn't divide evenly into
    // the new unit — same rule and same rationale as [UnitQtyField], so
    // both quantity fields behave identically. The switch still goes
    // through; only the value is dropped.
    if (_requiresIntegerIn(newUnit) && displayValue != displayValue.roundToDouble()) {
      setState(() {
        _unit = newUnit;
        _controller.text = '';
        _error = 'Jumlah dikosongkan: nilai sebelumnya tidak pas dalam '
            '${_unitLabel(newUnit)}. Masukkan jumlah baru.';
      });
      widget.onChanged(0, newUnit == EnteredUnit.pack);
      return;
    }

    setState(() {
      _unit = newUnit;
      _error = null;
      _controller.text = _formatNumber(displayValue);
    });
    widget.onChanged(_toPcs(displayValue, newUnit), newUnit == EnteredUnit.pack);
  }

  TextInputType get _keyboardType => UnitQuantityRules.keyboardType(
        unit: _unit,
        productAllowsFractional: widget.allowsFractionalQuantity,
      );

  List<TextInputFormatter> get _inputFormatters => UnitQuantityRules.inputFormatters(
        unit: _unit,
        productAllowsFractional: widget.allowsFractionalQuantity,
      );

  /// The whole widget is width-clamped so the caption and (much longer)
  /// error message wrap inside the column instead of widening it — an
  /// unclamped column pushes past the space the parent row can spare and
  /// overflows the moment a unit switch produces a non-integer value.
  ///
  /// Kept deliberately narrow: on a 360dp phone this column sits beside a
  /// checkbox *and* the product name, and anything wider truncates the
  /// name away to nothing. [_minColumnWidth] is what a one- or two-digit
  /// value takes (the common case, and the width this column always used
  /// to be); a longer value grows the column — and so the field — up to
  /// [_maxColumnWidth], sized to fit the longest realistic entry
  /// ("10000pcs") at the default text scale.
  ///
  /// Growing this far does squeeze the product name hard on a 320dp
  /// screen, but only while a 5-digit quantity is actually entered, and
  /// the name ellipsizes rather than overflowing (see PriorityProductCard,
  /// whose only fixed-width parts are an 18dp bar and gutter) — a clipped
  /// number the user can't read back is the worse failure.
  static const double _minColumnWidth = 148;
  static const double _maxColumnWidth = 228;
  static const double _stepperSize = 40;

  /// Width the numeric field's own content needs: the digits plus the
  /// "pcs" suffix (empty in the toggle variant, where the unit lives in
  /// the segmented button instead), measured in the real style and text
  /// scale so it holds up under accessibility font sizes.
  ///
  /// The padding allowance covers the caret and [InputDecoration.isDense]'s
  /// content insets — without it the last glyph sits under the caret.
  double _fieldContentWidth(String suffix) {
    final text = _controller.text.isEmpty ? '0' : _controller.text;
    final painter = TextPainter(
      text: TextSpan(text: '$text$suffix', style: Theme.of(context).textTheme.bodyLarge),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    return painter.width + 16;
  }

  /// The stepper buttons are fixed, so whatever the field needs decides the
  /// column — clamped at both ends. Past [_maxColumnWidth] the [TextField]
  /// falls back to its own horizontal scrolling rather than clipping.
  double _columnWidthFor(String suffix) =>
      (_stepperSize * 2 + _fieldContentWidth(suffix)).clamp(_minColumnWidth, _maxColumnWidth);

  @override
  Widget build(BuildContext context) {
    final availableUnits = _availableUnits;
    final showToggle = availableUnits.length > 1;

    if (!showToggle) {
      return SizedBox(
        width: _columnWidthFor('pcs'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _stepperButton(suffix: 'minus', icon: Icons.remove, onPressed: _decrementOrNull),
                // Expanded, not a fixed width: the field takes whatever the
                // column has left over after the two steppers, so it can
                // never push the row past the column and overflow.
                Expanded(
                  child: TextField(
                    key: Key('kulakan_qty_field_${widget.productId}'),
                    controller: _controller,
                    keyboardType: _keyboardType,
                    inputFormatters: _inputFormatters,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(suffixText: 'pcs', isDense: true),
                    onChanged: _onTextChanged,
                  ),
                ),
                _stepperButton(suffix: 'plus', icon: Icons.add, onPressed: () => _step(1)),
              ],
            ),
            if (_error != null) _errorText(),
          ],
        ),
      );
    }

    return SizedBox(
      // No suffix here — the segmented button below names the unit.
      width: _columnWidthFor(''),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _stepperButton(suffix: 'minus', icon: Icons.remove, onPressed: _decrementOrNull),
              Expanded(
                child: TextField(
                  key: Key('kulakan_qty_field_${widget.productId}'),
                  controller: _controller,
                  keyboardType: _keyboardType,
                  inputFormatters: _inputFormatters,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(isDense: true),
                  onChanged: _onTextChanged,
                ),
              ),
              _stepperButton(suffix: 'plus', icon: Icons.add, onPressed: () => _step(1)),
            ],
          ),
          const SizedBox(height: 4),
          SegmentedButton<EnteredUnit>(
            key: Key('kulakan_qty_unit_toggle_${widget.productId}'),
            showSelectedIcon: false,
            // Default segment padding makes three segments wider than
            // _columnWidth; trimmed so pcs/pack/dus fit without overflow.
            style: SegmentedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              textStyle: const TextStyle(fontSize: 12),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            segments: [
              for (final unit in availableUnits)
                ButtonSegment(value: unit, label: Text(_unitLabel(unit))),
            ],
            selected: {_unit},
            onSelectionChanged: (selection) => _changeUnit(selection.first),
          ),
          if (_unit != EnteredUnit.pcs) ...[
            const SizedBox(height: 2),
            Text(
              UnitConversion.formatCaption(
                value: _currentValue,
                unit: _unit,
                unitsPerPack: widget.unitsPerPack,
                unitsPerDus: widget.unitsPerDus,
              ),
              key: Key('kulakan_qty_caption_${widget.productId}'),
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
          if (_error != null) _errorText(),
        ],
      ),
    );
  }

  Widget _errorText() {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        _error!,
        key: Key('kulakan_qty_error_${widget.productId}'),
        textAlign: TextAlign.end,
        style: const TextStyle(fontSize: 11, color: Colors.red, height: 1.25),
      ),
    );
  }

  VoidCallback? get _decrementOrNull => _currentValue > 0 ? () => _step(-1) : null;

  /// A tappable 40x40 target — comfortably above the usual ~44dp minimum
  /// touch-target guidance — since this list is used by a non-technical,
  /// older user who needs to adjust quantities without precise taps.
  Widget _stepperButton({
    required String suffix,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        key: Key('kulakan_qty_stepper_${suffix}_${widget.productId}'),
        icon: Icon(icon, size: 20),
        padding: EdgeInsets.zero,
        onPressed: onPressed,
      ),
    );
  }

  String _unitLabel(EnteredUnit unit) {
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
