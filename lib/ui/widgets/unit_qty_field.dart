import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/product.dart';
import '../../data/models/stock_mutation.dart';
import '../../domain/unit_conversion.dart';
import '../../domain/unit_quantity_rules.dart';

/// Editable pcs/pack/dus quantity input for stock mutation entry (Catat
/// Mutasi, batch stok keluar). Offers a toggle only for the units
/// [product] actually supports (see [UnitConversion.availableUnitsFor])
/// — a pcs-only product renders a plain field with no toggle, a
/// pack-capable product gets a 2-way toggle, a dus-capable product gets
/// all three.
///
/// Whether a fractional value is accepted is never decided here:
/// [UnitQuantityRules.allowsDecimal] owns that classification for every
/// quantity field in the app, so pack/dus stay discrete and pcs defers to
/// [Product.allowsFractionalQuantity] in exactly one place.
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

  /// Whether the currently selected unit forbids a decimal part — see
  /// [UnitQuantityRules], which is the only place that rule is decided.
  bool _requiresIntegerIn(EnteredUnit unit) => !UnitQuantityRules.allowsDecimal(
        unit: unit,
        productAllowsFractional: widget.product.allowsFractionalQuantity,
      );

  void _applyValue(double value) {
    if (_requiresIntegerIn(_unit) && value != value.roundToDouble()) {
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
        if (widget.product.unitsPerPack == null) {
          return 'Jumlah pack harus bilangan bulat';
        }
        return 'Hanya bisa dijual per pack. Gunakan kelipatan ${widget.product.unitsPerPack} pcs';
      case EnteredUnit.dus:
        if (widget.product.unitsPerDus == null) {
          return 'Jumlah dus harus bilangan bulat';
        }
        final dusInPcs = widget.product.unitsPerPack == null
            ? widget.product.unitsPerDus!
            : widget.product.unitsPerDus! * widget.product.unitsPerPack!;
        return 'Hanya bisa dijual per dus. Gunakan kelipatan $dusInPcs pcs';
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
    final displayValue = _fromPcs(_toPcs(_currentValue, _unit), newUnit);

    // Switching into a unit the current value doesn't divide evenly into
    // (1 pcs → dus, 2.5 kg → pack) clears the field rather than rounding
    // it. Rounding here used to be silent, and silence is the problem: the
    // user taps "dus", the number changes under them, and a quantity they
    // never entered is what gets written to the ledger.
    //
    // The switch itself still goes through — refusing it would strand the
    // user in the unit they're trying to leave, since every tap would
    // appear to do nothing — so they land in the requested unit with an
    // empty field and an explicit note about why.
    if (_requiresIntegerIn(newUnit) && displayValue != displayValue.roundToDouble()) {
      setState(() {
        _unit = newUnit;
        _controller.text = '';
        _error = 'Jumlah dikosongkan: nilai sebelumnya tidak pas dalam '
            '${_unitLabel(newUnit)}. Masukkan jumlah baru.';
      });
      // Zero, not the old quantity — submit rejects it ("Jumlah harus
      // lebih dari 0"), so an abandoned switch can't record a stale value.
      widget.onChanged(0, newUnit, 0);
      return;
    }

    setState(() {
      _unit = newUnit;
      _error = null;
      _controller.text = _formatNumber(displayValue);
    });
    widget.onChanged(_toPcs(displayValue, newUnit), newUnit, displayValue);
  }

  VoidCallback? get _decrementOrNull => _currentValue > 0 ? () => _step(-1) : null;

  List<TextInputFormatter> get _inputFormatters => UnitQuantityRules.inputFormatters(
        unit: _unit,
        productAllowsFractional: widget.product.allowsFractionalQuantity,
      );

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
                keyboardType: UnitQuantityRules.keyboardType(
                  unit: _unit,
                  productAllowsFractional: widget.product.allowsFractionalQuantity,
                ),
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
