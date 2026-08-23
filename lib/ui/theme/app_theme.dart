import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_dimensions.dart';
import 'app_text_styles.dart';

/// Single source of truth for the app's `ThemeData`, applied at the
/// `MaterialApp` level so every screen restyle later on just inherits it.
abstract final class AppTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.white,
      error: AppColors.redPrimary,
      surface: AppColors.white,
    ).copyWith(
      // `ColorScheme.fromSeed` derives the whole `surfaceContainer*` family
      // by blending the seed (our green) into the neutral tones, so every
      // Material 3 surface that falls back to one of them — dialogs
      // (`surfaceContainerHigh`), bottom sheets (`surfaceContainerLow`),
      // chips (`surfaceContainerHighest`) — came out visibly green-tinted
      // next to the neutral #EEEEEE scaffold the main screens use. Pin the
      // family to our own neutral greys so no surface picks up the cast.
      surfaceContainerLowest: AppColors.white,
      surfaceContainerLow: AppColors.gray50,
      surfaceContainer: AppColors.gray100,
      surfaceContainerHigh: AppColors.gray100,
      surfaceContainerHighest: AppColors.gray300,
      // Kills Material 3's elevation tint overlay app-wide: an elevated
      // surface stays its own colour instead of drifting towards green.
      surfaceTint: Colors.transparent,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.scaffoldBackground,
      fontFamily: AppTextStyles.fontFamily,
      textTheme: _textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.darkText,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: AppTextStyles.heading,
        iconTheme: IconThemeData(color: AppColors.darkText),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.gray100,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.inputRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.inputRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.inputRadius),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.gray300,
          disabledForegroundColor: AppColors.gray500,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentTextStyle: const TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          color: AppColors.white,
          fontSize: 14,
        ),
        actionTextColor: AppColors.white,
      ),
      // Explicit white for the two surface types that otherwise inherit a
      // derived container colour — dialogs and modal sheets sit on top of
      // the neutral scaffold and should read as plain white cards.
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.gray300, thickness: 1),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.gray500,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  static TextTheme get _textTheme {
    return const TextTheme(
      headlineSmall: AppTextStyles.heading,
      titleMedium: AppTextStyles.subheading,
      bodyMedium: AppTextStyles.body,
      bodyLarge: AppTextStyles.bodyMedium,
      labelSmall: AppTextStyles.caption,
    );
  }
}
