import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/ui/theme/app_colors.dart';
import 'package:inventaris_toko/ui/theme/app_dimensions.dart';
import 'package:inventaris_toko/ui/theme/app_text_styles.dart';
import 'package:inventaris_toko/ui/theme/app_theme.dart';

void main() {
  test('color tokens match the exact design-brief hex values', () {
    expect(AppColors.primary.toARGB32(), 0xFF00AA0D);
    expect(AppColors.primaryDark.toARGB32(), 0xFF008A0A);
    expect(AppColors.primaryGradientEnd.toARGB32(), 0xFF00CC10);
    expect(AppColors.greenSubtle.toARGB32(), 0xFFE8F5E9);
    expect(AppColors.greenText.toARGB32(), 0xFF2E7D32);
    expect(AppColors.yellowSubtle.toARGB32(), 0xFFFFF3E0);
    expect(AppColors.yellowText.toARGB32(), 0xFFE65100);
    expect(AppColors.redSubtle.toARGB32(), 0xFFFFEBEE);
    expect(AppColors.redText.toARGB32(), 0xFFC62828);
    expect(AppColors.redPrimary.toARGB32(), 0xFFD32F2F);
    expect(AppColors.darkText.toARGB32(), 0xFF1C1C1C);
    expect(AppColors.gray700.toARGB32(), 0xFF616161);
    expect(AppColors.gray500.toARGB32(), 0xFF9E9E9E);
    expect(AppColors.gray300.toARGB32(), 0xFFE0E0E0);
    expect(AppColors.gray100.toARGB32(), 0xFFF5F5F5);
    expect(AppColors.white.toARGB32(), 0xFFFFFFFF);
  });

  test('text styles use the registered font family, size, and weight', () {
    expect(AppTextStyles.heading.fontFamily, AppTextStyles.fontFamily);
    expect(AppTextStyles.heading.fontSize, 20);
    expect(AppTextStyles.heading.fontWeight, FontWeight.w800);

    expect(AppTextStyles.subheading.fontSize, 16);
    expect(AppTextStyles.subheading.fontWeight, FontWeight.w700);

    expect(AppTextStyles.body.fontSize, 14);
    expect(AppTextStyles.body.fontWeight, FontWeight.w400);

    expect(AppTextStyles.bodyMedium.fontSize, 14);
    expect(AppTextStyles.bodyMedium.fontWeight, FontWeight.w600);

    expect(AppTextStyles.caption.fontSize, 12);
    expect(AppTextStyles.caption.fontWeight, FontWeight.w400);

    expect(AppTextStyles.statNumber.fontSize, 32);
    expect(AppTextStyles.statNumber.fontWeight, FontWeight.w800);

    expect(AppTextStyles.stockNumber.fontSize, 17);
    expect(AppTextStyles.stockNumber.fontWeight, FontWeight.w800);
  });

  test('shape tokens are defined', () {
    expect(AppDimensions.cardRadius, 16);
    expect(AppDimensions.buttonRadius, 14);
    expect(AppDimensions.badgeRadius, 8);
    expect(AppDimensions.pillRadius, 20);
    expect(AppDimensions.inputRadius, 12);
    expect(AppDimensions.cardShadow, isNotEmpty);
    expect(AppDimensions.elevatedSearchShadow, isNotEmpty);
  });

  test('AppTheme.light registers PlusJakartaSans as the default font family', () {
    final theme = AppTheme.light;
    expect(theme.textTheme.bodyMedium?.fontFamily, 'PlusJakartaSans');
    expect(theme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, AppColors.scaffoldBackground);
    expect(theme.colorScheme.primary, AppColors.primary);
  });

  testWidgets('AppTheme.light compiles and applies to a MaterialApp', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: Text('hello')),
    ));

    final context = tester.element(find.text('hello'));
    final theme = Theme.of(context);
    expect(theme.textTheme.bodyMedium?.fontFamily, 'PlusJakartaSans');
  });
}
