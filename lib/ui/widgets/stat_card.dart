import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

/// Color variant for [StatCard].
enum StatCardVariant { green, red, yellow }

/// A colored stat tile: label, big number, optional subtitle. Used on
/// Beranda for things like "Total produk" / "Perlu kulakan".
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.variant,
    this.subtitle,
  });

  final String label;
  final String value;
  final String? subtitle;
  final StatCardVariant variant;

  @override
  Widget build(BuildContext context) {
    final background = switch (variant) {
      StatCardVariant.green => AppColors.greenSubtle,
      StatCardVariant.red => AppColors.redSubtle,
      StatCardVariant.yellow => AppColors.yellowSubtle,
    };
    final labelColor = switch (variant) {
      StatCardVariant.green => AppColors.greenText,
      StatCardVariant.red => AppColors.redText,
      StatCardVariant.yellow => AppColors.yellowText,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        boxShadow: AppDimensions.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: labelColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(value, style: AppTextStyles.statNumber),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: AppTextStyles.caption),
          ],
        ],
      ),
    );
  }
}
