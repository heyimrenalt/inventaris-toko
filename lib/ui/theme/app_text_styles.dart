import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Plus Jakarta Sans text styles at the app's fixed set of sizes. Sizes are
/// unchanged from the pre-overhaul UI — only font family/weight/color
/// changed — so screens keep their existing layout metrics.
abstract final class AppTextStyles {
  static const fontFamily = 'PlusJakartaSans';

  static const heading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: AppColors.darkText,
  );

  static const subheading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.darkText,
  );

  static const body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.darkText,
  );

  static const bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.darkText,
  );

  static const caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.gray700,
  );

  static const statNumber = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    color: AppColors.darkText,
  );

  /// 28px bold — display number for prominent headline figures (e.g. the
  /// profit headline), sitting between [heading] (20) and [statNumber] (32).
  /// Structured like [statNumber] so call sites can move between the two.
  static const displayNumber = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.darkText,
  );

  static const stockNumber = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w800,
    color: AppColors.darkText,
  );
}
