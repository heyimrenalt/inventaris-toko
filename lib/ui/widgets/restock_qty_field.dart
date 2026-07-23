import 'package:flutter/material.dart';

import '../../data/models/stock_mutation.dart';
import '../../domain/unit_conversion.dart';

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

  /// Mirrors [Product.allowsFractionalQuantity] — when `false`, pcs input
  /// doesn't accept a fractional value either (see [_applyValue]). Pack
  /// and dus never accept a fractional value regardless of this flag.
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
  }

  @override
  void dispose() {
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

  void _applyValue(double value) {
    // Whether a fractional pcs value is meaningful is a per-product choice
    // (see Product.allowsFractionalQuantity); pack/dus are always
    // whole-number units regardless of that flag — you can't buy half a
    // pack.
    final requiresInteger = _unit != EnteredUnit.pcs || !widget.allowsFractionalQuantity;
    if (requiresInteger && value != value.roundToDouble()) {
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
        return 'Jumlah pack harus bilangan bulat';
      case EnteredUnit.dus:
        return 'Jumlah dus harus bilangan bulat';
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
    final currentQtyInPcs = _toPcs(_currentValue, _unit);
    final displayValue = _fromPcs(currentQtyInPcs, newUnit);
    setState(() {
      _unit = newUnit;
      _error = null;
      _controller.text = _formatNumber(displayValue);
    });
    widget.onChanged(currentQtyInPcs, newUnit == EnteredUnit.pack);
  }

  @override
  Widget build(BuildContext context) {
    final availableUnits = _availableUnits;
    final showToggle = availableUnits.length > 1;

    if (!showToggle) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _stepperButton(suffix: 'minus', icon: Icons.remove, onPressed: _decrementOrNull),
              SizedBox(
                width: 90,
                child: TextField(
                  key: Key('kulakan_qty_field_${widget.productId}'),
                  controller: _controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(suffixText: 'pcs', isDense: true),
                  onChanged: _onTextChanged,
                ),
              ),
              _stepperButton(suffix: 'plus', icon: Icons.add, onPressed: () => _step(1)),
            ],
          ),
          if (_error != null)
            Text(
              _error!,
              key: Key('kulakan_qty_error_${widget.productId}'),
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _stepperButton(suffix: 'minus', icon: Icons.remove, onPressed: _decrementOrNull),
            SizedBox(
              width: 75,
              child: TextField(
                key: Key('kulakan_qty_field_${widget.productId}'),
                controller: _controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
        if (_error != null)
          Text(
            _error!,
            key: Key('kulakan_qty_error_${widget.productId}'),
            style: const TextStyle(fontSize: 12, color: Colors.red),
          ),
      ],
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
