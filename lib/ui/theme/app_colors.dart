import 'package:flutter/material.dart';

/// The app's Gojek-inspired color palette: bold, high-contrast, no
/// blur/transparency. Every value here is an exact hex from the design
/// brief — do not approximate or substitute a Material default.
abstract final class AppColors {
  static const primary = Color(0xFF00AA0D);
  static const primaryDark = Color(0xFF008A0A);
  static const primaryGradientEnd = Color(0xFF00CC10);

  static const greenSubtle = Color(0xFFE8F5E9);
  static const greenText = Color(0xFF2E7D32);

  static const yellowSubtle = Color(0xFFFFF3E0);
  static const yellowText = Color(0xFFE65100);

  static const redSubtle = Color(0xFFFFEBEE);
  static const redText = Color(0xFFC62828);
  static const redPrimary = Color(0xFFD32F2F);

  static const darkText = Color(0xFF1C1C1C);
  static const gray700 = Color(0xFF616161);
  static const gray500 = Color(0xFF9E9E9E);
  static const gray300 = Color(0xFFE0E0E0);
  static const gray100 = Color(0xFFF5F5F5);
  static const white = Color(0xFFFFFFFF);

  /// The page background behind white cards — deliberately a shade darker
  /// than [gray100] (which is used for fills/surfaces within cards) so
  /// cards visibly separate from the scaffold.
  static const scaffoldBackground = Color(0xFFEEEEEE);

  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryGradientEnd],
  );
}
