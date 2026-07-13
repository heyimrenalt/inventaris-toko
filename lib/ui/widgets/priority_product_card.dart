import 'package:flutter/material.dart';

import '../../data/models/product.dart';
import '../../domain/prioritas_kulakan_calculator.dart';

/// A single "prioritas kulakan" entry: product name, current stock, and
/// the estimated-days label with its urgency color (an actual visible
/// border/background tint, not a small dot, per the "color used
/// meaningfully" design principle). Reused as a fixed-width card in
/// Beranda's horizontal preview row ([compact]) and as a full-width row
/// in the full Prioritas Kulakan list.
class PriorityProductCard extends StatelessWidget {
  const PriorityProductCard({
    super.key,
    required this.result,
    required this.onTap,
    this.compact = false,
  });

  final PrioritasKulakanResult result;
  final VoidCallback onTap;
  final bool compact;

  Product get _product => result.product;

  Color get _urgencyColor {
    switch (result.urgency) {
      case PriorityUrgency.red:
        return Colors.red[700]!;
      case PriorityUrgency.yellow:
        return Colors.orange[800]!;
      case PriorityUrgency.neutral:
        return Colors.grey[700]!;
    }
  }

  String get _daysLabel {
    if (result.isOutOfStock) return 'Stok habis sekarang';
    return '${result.estimatedDaysRemaining.round()} hari lagi';
  }

  @override
  Widget build(BuildContext context) {
    return compact ? _buildCompact(context) : _buildFull(context);
  }

  Widget _buildCompact(BuildContext context) {
    final color = _urgencyColor;
    return InkWell(
      key: Key('priority_card_${_product.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _product.name,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Text(
              'Stok: ${_formatQuantity(_product.currentStock)} ${_product.unit}',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              _daysLabel,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFull(BuildContext context) {
    final color = _urgencyColor;
    return InkWell(
      key: Key('priority_card_${_product.id}'),
      onTap: onTap,
      child: SizedBox(
        height: 68,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 6, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _product.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Stok: ${_formatQuantity(_product.currentStock)} ${_product.unit}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                _daysLabel,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatQuantity(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(1);
}
