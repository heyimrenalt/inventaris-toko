import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

/// Color variant for [StatusBadge].
enum StatusBadgeVariant { success, warning, danger }

/// A small colored pill of text — e.g. "Stok habis", "3 hari lagi", "Stok
/// aman" on the priority-kulakan cards.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.text, required this.variant});

  final String text;
  final StatusBadgeVariant variant;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (variant) {
      StatusBadgeVariant.success => (AppColors.greenSubtle, AppColors.greenText),
      StatusBadgeVariant.warning => (AppColors.yellowSubtle, AppColors.yellowText),
      StatusBadgeVariant.danger => (AppColors.redSubtle, AppColors.redText),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppDimensions.badgeRadius),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}
