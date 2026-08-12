import 'package:flutter/material.dart';

import '../../data/models/product.dart';
import '../../data/models/stock_mutation.dart';
import '../../domain/prioritas_kulakan_calculator.dart';
import '../../domain/unit_conversion.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'product_thumb.dart';
import 'status_badge.dart';

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

  /// Maps urgency onto the design system's 3-state color-coded badge —
  /// neutral (plenty of days left) reads as "safe", matching the green/
  /// yellow/red convention used everywhere else stock health is shown.
  StatusBadgeVariant get _urgencyVariant {
    switch (result.urgency) {
      case PriorityUrgency.red:
        return StatusBadgeVariant.danger;
      case PriorityUrgency.yellow:
        return StatusBadgeVariant.warning;
      case PriorityUrgency.neutral:
        return StatusBadgeVariant.success;
    }
  }

  /// Urgency label per the "Prioritas Kulakan" rules: out-of-stock always
  /// wins (a fact, not a prediction), then the red/yellow/neutral bands
  /// computed from `restockLeadTimeDays`. Returns `''` only for the rare
  /// case of a product whose velocity rounds to zero — there's no
  /// estimate to show and no urgency to flag.
  String get _daysLabel {
    if (result.isOutOfStock) return 'Stok habis — waktunya kulakan!';

    final days = result.estimatedDaysRemaining;
    if (days == null) return '';

    switch (result.urgency) {
      case PriorityUrgency.red:
        return 'Waktunya kulakan!';
      case PriorityUrgency.yellow:
        return 'Sebentar lagi habis';
      case PriorityUrgency.neutral:
        return formatEstimatedDaysLabel(days);
    }
  }

  /// "= 6 pack = 1 dus" style breakdown of [Product.currentStock], same
  /// whole-number-only rule as the product detail page's stock conversion
  /// line — `null` when neither tier is configured, or when the stock
  /// doesn't divide evenly into any configured tier.
  String? get _stockConversion => _stockConversionLine(
        _product.currentStock,
        _product.unitsPerPack,
        _product.unitsPerDus,
      );

  @override
  Widget build(BuildContext context) {
    return compact ? _buildCompact(context) : _buildFull(context);
  }

  Widget _buildCompact(BuildContext context) {
    return InkWell(
      key: Key('priority_card_${_product.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
      child: Container(
        width: 180,
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
            Row(
              children: [
                const ProductThumb(size: 32),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _product.name,
                    // Just 1 line here (unlike the full-width row's
                    // product name) — the urgency label now needs room
                    // for longer phrases like "Stok habis — waktunya
                    // kulakan!", which can wrap to 2 lines in this card's
                    // narrow fixed width.
                    style: AppTextStyles.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stok: ${_formatQuantity(_product.currentStock)} ${_product.unit}',
                  style: AppTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_stockConversion != null)
                  Text(
                    _stockConversion!,
                    style: AppTextStyles.caption.copyWith(fontSize: 11, color: AppColors.gray500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
            if (_daysLabel.isNotEmpty)
              StatusBadge(text: _daysLabel, variant: _urgencyVariant),
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
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 6, color: color),
            const SizedBox(width: AppSpacing.md),
            // The urgency label used to sit beside the name in its own
            // Flexible column, splitting the row's width between the two.
            // This row is now also squeezed by a checkbox and quantity
            // stepper alongside it (see PrioritasKulakanScreen._buildRow),
            // so there wasn't enough width left to split — even short
            // product names truncated to a couple of characters. Stacking
            // the urgency label under the name instead (same pattern as
            // the compact preview card and the Sering Keluar row) gives
            // each line the full available width.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _product.name,
                      style: AppTextStyles.subheading,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Stok: ${_formatQuantity(_product.currentStock)} ${_product.unit}',
                      style: AppTextStyles.body.copyWith(color: AppColors.gray700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_stockConversion != null)
                      Text(
                        _stockConversion!,
                        style: AppTextStyles.caption.copyWith(color: AppColors.gray500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (_daysLabel.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        _daysLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium.copyWith(color: color),
                      ),
                    ],
                  ],
                ),
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

/// "= 6 pack = 1 dus" breakdown of [currentStock] — each tier shown only
/// when it independently divides evenly (epsilon 0.001), `null` when
/// neither tier is configured or neither divides evenly.
String? _stockConversionLine(double currentStock, int? unitsPerPack, int? unitsPerDus) {
  final parts = <String>[];
  if (unitsPerPack != null) {
    final packs = UnitConversion.fromPcs(
      qtyInPcs: currentStock,
      unit: EnteredUnit.pack,
      unitsPerPack: unitsPerPack,
      unitsPerDus: unitsPerDus,
    );
    if (_isWholeNumber(packs)) parts.add('${_formatGrouped(packs)} pack');
  }
  if (unitsPerDus != null) {
    final dus = UnitConversion.fromPcs(
      qtyInPcs: currentStock,
      unit: EnteredUnit.dus,
      unitsPerPack: unitsPerPack,
      unitsPerDus: unitsPerDus,
    );
    if (_isWholeNumber(dus)) parts.add('${_formatGrouped(dus)} dus');
  }
  if (parts.isEmpty) return null;
  return '= ${parts.join(' = ')}';
}

bool _isWholeNumber(double value) => (value - value.roundToDouble()).abs() < 0.001;

String _formatGrouped(double value) {
  final digits = value.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final positionFromEnd = digits.length - i;
    buffer.write(digits[i]);
    if (positionFromEnd > 1 && positionFromEnd % 3 == 1) buffer.write('.');
  }
  return buffer.toString();
}
