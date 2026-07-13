import 'package:flutter/material.dart';

import '../../data/models/stock_mutation.dart';

/// A single row for a stock mutation: product name, a clear green
/// up-arrow (stock-in) or red down-arrow (stock-out) — an actual visual
/// distinction, not decorative color, per the "color used meaningfully"
/// design principle — quantity, optional note, and a human-readable
/// relative timestamp. Reused across the Mutasi tab, Product Detail's
/// recent-history section, and the full per-product history screen.
class MutationListItem extends StatelessWidget {
  const MutationListItem({
    super.key,
    required this.mutation,
    required this.productName,
    required this.unit,
  });

  final StockMutation mutation;
  final String productName;
  final String unit;

  bool get _isIn => mutation.type == StockMutationType.stockIn;

  @override
  Widget build(BuildContext context) {
    final color = _isIn ? Colors.green[700]! : Colors.red[700]!;
    final icon = _isIn ? Icons.arrow_upward : Icons.arrow_downward;
    final sign = _isIn ? '+' : '-';
    final note = mutation.note;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (note != null && note.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    note,
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  formatRelativeTime(mutation.createdAt),
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$sign${formatMutationQuantity(mutation.quantity)} $unit',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}

String formatMutationQuantity(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(1);
}

/// Exactly two tiers, no "N jam lalu" in between: under an hour old shows
/// "Baru saja" / "N menit lalu"; an hour or older switches immediately to
/// the exact clock time ("13.05"), no matter how many hours or days old —
/// callers that need the day too (e.g. the Mutasi tab) already show it
/// separately via their own day-group header.
String formatRelativeTime(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);

  if (diff.inMinutes < 1) return 'Baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';

  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$hour.$minute';
}
