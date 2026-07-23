import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/product.dart';
import '../../data/models/stock_mutation.dart';
import '../../domain/unit_conversion.dart';

/// Editable pcs/pack/dus quantity input for stock mutation entry (Catat
/// Mutasi, batch stok keluar). Offers a toggle only for the units
/// [product] actually supports (see [UnitConversion.availableUnitsFor])
/// — a pcs-only product renders a plain field with no toggle, a
/// pack-capable product gets a 2-way toggle, a dus-capable product gets
/// all three.
///
/// Whether a fractional value is accepted is driven uniformly by
/// [Product.allowsFractionalQuantity] across every unit — unlike
/// [RestockQtyField] before its own fix, there's no hardcoded "pack/dus
/// is always whole, pcs is always fractional" assumption here.
class UnitQtyField extends StatefulWidget {
  const UnitQtyField({
    super.key,
    required this.product,
    required this.initialQtyInPcs,
    required this.initialEnteredUnit,
    required this.onChanged,
    this.label,
  });

  final Product product;
  final double initialQtyInPcs;
  final EnteredUnit initialEnteredUnit;

  /// Called with the canonical pcs quantity, the unit it was entered in,
  /// and the raw value in that unit, on every valid edit.
  final void Function(double qtyInPcs, EnteredUnit enteredUnit, double enteredValue) onChanged;

  /// Optional label shown on the text field itself (e.g. "Jumlah") — left
  /// `null` for compact contexts like a cart row, where the surrounding
  /// layout already makes the field's purpose clear.
  final String? label;

  @override
  State<UnitQtyField> createState() => _UnitQtyFieldState();
}

class _UnitQtyFieldState extends State<UnitQtyField> {
  late EnteredUnit _unit;
  late final TextEditingController _controller;
  String? _error;

  List<EnteredUnit> get _availableUnits => UnitConversion.availableUnitsFor(
        unitsPerPack: widget.product.unitsPerPack,
        unitsPerDus: widget.product.unitsPerDus,
      );

  @override
  void initState() {
    super.initState();
    // Falls back to pcs if the initial unit isn't (or is no longer)
    // offerable for this product — e.g. a product's unitsPerDus was
    // cleared after a mutation was entered in dus.
    _unit = _availableUnits.contains(widget.initialEnteredUnit)
        ? widget.initialEnteredUnit
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
        unitsPerPack: widget.product.unitsPerPack,
        unitsPerDus: widget.product.unitsPerDus,
      );

  double _fromPcs(double qtyInPcs, EnteredUnit unit) => UnitConversion.fromPcs(
        qtyInPcs: qtyInPcs,
        unit: unit,
        unitsPerPack: widget.product.unitsPerPack,
        unitsPerDus: widget.product.unitsPerDus,
      );

  void _onTextChanged(String text) {
    final value = double.tryParse(text.replaceAll(',', '.'));
    if (value == null) return;
    _applyValue(value);
  }

  void _applyValue(double value) {
    // Pack/dus are always whole-number units — you can't buy half a pack —
    // regardless of the product's own fractional-quantity setting, which
    // only governs the base pcs unit.
    final requiresInteger = _unit != EnteredUnit.pcs || !widget.product.allowsFractionalQuantity;
    if (requiresInteger && value != value.roundToDouble()) {
      setState(() => _error = _integerErrorFor(_unit));
      return;
    }

    final qtyInPcs = _toPcs(value, _unit);
    setState(() => _error = null);
    widget.onChanged(qtyInPcs, _unit, value);
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

  /// Steps by 1 in whatever unit is currently displayed.
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
    widget.onChanged(currentQtyInPcs, newUnit, displayValue);
  }

  VoidCallback? get _decrementOrNull => _currentValue > 0 ? () => _step(-1) : null;

  /// Decimals only make sense for a fractional-unit product entered in pcs
  /// (kg/liter/ml). Pack/dus are always whole, and a non-fractional product
  /// is whole in pcs too — so the "."/"," keys are blocked for those rather
  /// than only flagged after typing.
  bool get _decimalAllowed => _unit == EnteredUnit.pcs && widget.product.allowsFractionalQuantity;

  List<TextInputFormatter> get _inputFormatters => _decimalAllowed
      ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]
      : [FilteringTextInputFormatter.digitsOnly];

  @override
  Widget build(BuildContext context) {
    final productId = widget.product.id;
    final availableUnits = _availableUnits;
    final showToggle = availableUnits.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _stepperButton(suffix: 'minus', icon: Icons.remove, onPressed: _decrementOrNull),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                key: Key('unit_qty_field_$productId'),
                controller: _controller,
                keyboardType: TextInputType.numberWithOptions(decimal: _decimalAllowed),
                inputFormatters: _inputFormatters,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(labelText: widget.label, isDense: true),
                onChanged: _onTextChanged,
              ),
            ),
            const SizedBox(width: 4),
            _stepperButton(suffix: 'plus', icon: Icons.add, onPressed: () => _step(1)),
          ],
        ),
        if (showToggle) ...[
          const SizedBox(height: 4),
          SegmentedButton<EnteredUnit>(
            key: Key('unit_qty_toggle_$productId'),
            showSelectedIcon: false,
            segments: [
              for (final unit in availableUnits)
                ButtonSegment(value: unit, label: Text(_unitLabel(unit))),
            ],
            selected: {_unit},
            onSelectionChanged: (selection) => _changeUnit(selection.first),
          ),
        ],
        if (showToggle && _unit != EnteredUnit.pcs)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              UnitConversion.formatCaption(
                value: _currentValue,
                unit: _unit,
                unitsPerPack: widget.product.unitsPerPack,
                unitsPerDus: widget.product.unitsPerDus,
              ),
              key: Key('unit_qty_caption_$productId'),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              _error!,
              key: Key('unit_qty_error_$productId'),
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          ),
      ],
    );
  }

  /// A tappable 40x40 target, matching [RestockQtyField]'s own stepper
  /// sizing — this app's user is non-technical and often older, so
  /// buttons stay comfortably above the ~44dp minimum touch-target
  /// guidance.
  Widget _stepperButton({
    required String suffix,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        key: Key('unit_qty_stepper_${suffix}_${widget.product.id}'),
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
