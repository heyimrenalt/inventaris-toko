import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

/// Color level for [StockBadge].
enum StockLevel { safe, warning, danger }

/// The colored stock-number chip used in product list rows (e.g. the "0" /
/// "8" / "36" pcs figure next to a product).
class StockBadge extends StatelessWidget {
  const StockBadge({super.key, required this.text, required this.level});

  final String text;
  final StockLevel level;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (level) {
      StockLevel.safe => (AppColors.greenSubtle, AppColors.greenText),
      StockLevel.warning => (AppColors.yellowSubtle, AppColors.yellowText),
      StockLevel.danger => (AppColors.redSubtle, AppColors.redText),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppDimensions.stockBadgeRadius),
      ),
      child: Text(text, style: AppTextStyles.stockNumber.copyWith(color: foreground)),
    );
  }
}
