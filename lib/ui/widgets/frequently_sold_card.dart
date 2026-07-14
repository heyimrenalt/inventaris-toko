import 'package:flutter/material.dart';

import '../../data/models/product.dart';
import '../../domain/prioritas_kulakan_calculator.dart';

/// A compact card for a product ranked by sales velocity: name, average
/// daily sales, and current stock. Used by Beranda's "Sering keluar"
/// horizontal-scroll section — deliberately separate from
/// [PriorityProductCard], which is about restock urgency (a different
/// axis) rather than sales frequency.
class FrequentlySoldCard extends StatelessWidget {
  const FrequentlySoldCard({super.key, required this.result, required this.onTap});

  final PrioritasKulakanResult result;
  final VoidCallback onTap;

  Product get _product => result.product;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('frequently_sold_card_${_product.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue[100]!),
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
              '~${_formatQuantity(result.dailyVelocity)}/hari',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue[800]),
            ),
            const SizedBox(height: 4),
            Text(
              'Stok: ${_formatQuantity(_product.currentStock)} ${_product.unit}',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
