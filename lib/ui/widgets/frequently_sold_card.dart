import 'package:flutter/material.dart';

import '../../data/models/product.dart';
import '../../domain/prioritas_kulakan_calculator.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';
import 'stock_badge.dart';

/// A compact card for a product ranked by sales velocity: name, average
/// daily sales (contextualized — a bare "~9/hari" reads as meaningless
/// noise, especially on an out-of-stock product), and current stock. Used
/// by Beranda's "Sering keluar" horizontal-scroll section — deliberately
/// separate from [PriorityProductCard], which is about restock urgency (a
/// different axis) rather than sales frequency.
class FrequentlySoldCard extends StatelessWidget {
  const FrequentlySoldCard({super.key, required this.result, required this.onTap});

  final PrioritasKulakanResult result;
  final VoidCallback onTap;

  Product get _product => result.product;

  String get _velocityLine {
    if (result.dataAgeDays == 0) return 'Belum ada riwayat penjualan';
    final v = formatVelocity(result.dailyVelocity);
    return _product.currentStock <= 0
        ? 'Rata-rata terjual ~$v/hari (stok kosong)'
        : 'Rata-rata terjual ~$v/hari';
  }

  /// One line under [_velocityLine]: the data-age caption, or null when
  /// there's no sales history to date it.
  String? get _secondaryLine {
    if (result.dataAgeDays == 0) return null;
    return 'berdasarkan rata-rata ${result.dataAgeDays} hari terakhir';
  }

  /// Reuses the same urgency signal [PriorityProductCard] shows, so a
  /// product that's both a top seller and low on stock reads consistently
  /// across both Beranda sections.
  StockLevel get _stockLevel {
    if (result.isOutOfStock) return StockLevel.danger;
    switch (result.urgency) {
      case PriorityUrgency.red:
        return StockLevel.danger;
      case PriorityUrgency.yellow:
        return StockLevel.warning;
      case PriorityUrgency.neutral:
        return StockLevel.safe;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('frequently_sold_card_${_product.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
      child: Container(
        width: 176,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          boxShadow: AppDimensions.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _product.name,
              style: AppTextStyles.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _velocityLine,
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_secondaryLine != null)
                  Text(
                    _secondaryLine!,
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
            StockBadge(
              text: '${_formatQuantity(_product.currentStock)} ${_product.unit}',
              level: _stockLevel,
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
