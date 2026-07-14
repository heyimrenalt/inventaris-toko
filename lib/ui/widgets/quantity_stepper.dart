import 'package:flutter/material.dart';

/// A `-` / quantity / `+` control for whole-unit counts, used by the
/// multi-item stock-out cart. The quantity display is itself tappable so
/// a large change doesn't require many taps of `+`/`-`.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onChanged,
    this.min = 1,
    this.max,
  });

  final int quantity;
  final ValueChanged<int> onChanged;
  final int min;
  final int? max;

  bool get _canDecrement => quantity > min;
  bool get _canIncrement => max == null || quantity < max!;

  Future<void> _editManually(BuildContext context) async {
    final controller = TextEditingController(text: quantity.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        String? errorText;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void submit() {
              final value = int.tryParse(controller.text.trim());
              if (value == null || value < min || (max != null && value > max!)) {
                setDialogState(() {
                  errorText = max == null
                      ? 'Masukkan angka bulat minimal $min'
                      : 'Masukkan angka bulat antara $min dan $max';
                });
                return;
              }
              Navigator.of(dialogContext).pop(value);
            }

            return AlertDialog(
              title: const Text('Ubah jumlah', style: TextStyle(fontSize: 18)),
              content: TextField(
                key: const Key('quantity_stepper_manual_field'),
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(errorText: errorText),
                onSubmitted: (_) => submit(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Batal', style: TextStyle(fontSize: 16)),
                ),
                TextButton(
                  key: const Key('quantity_stepper_manual_save'),
                  onPressed: submit,
                  child: const Text('Simpan', style: TextStyle(fontSize: 16)),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const Key('quantity_stepper_decrement'),
          onPressed: _canDecrement ? () => onChanged(quantity - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        ),
        InkWell(
          key: const Key('quantity_stepper_display'),
          onTap: () => _editManually(context),
          child: Container(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            alignment: Alignment.center,
            child: Text(
              '$quantity',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        IconButton(
          key: const Key('quantity_stepper_increment'),
          onPressed: _canIncrement ? () => onChanged(quantity + 1) : null,
          icon: const Icon(Icons.add_circle_outline),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        ),
      ],
    );
  }
}
