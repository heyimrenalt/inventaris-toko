import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

/// An in-list search field styled to match Beranda's search bar exactly —
/// a white, rounded, elevated pill with a leading search icon. Unlike
/// [ProductSearchBar] (which shows an overlay dropdown and navigates to a
/// product on tap), this one just reports every keystroke through
/// [onChanged] so the embedding screen can filter its own list in place.
///
/// Used on Produk, Mutasi, Sering Keluar, and Prioritas Kulakan so all
/// four share one consistent look with Beranda while keeping their own
/// list-filtering behaviour.
class AppSearchBar extends StatelessWidget {
  const AppSearchBar({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          boxShadow: AppDimensions.elevatedSearchShadow,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          style: AppTextStyles.body,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: AppTextStyles.body.copyWith(color: AppColors.gray500),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppColors.gray500,
              size: 22,
            ),
            // Fully transparent field — the white rounded pill is painted by
            // the Container above; a filled/bordered field on top would peek
            // sharp corners out from under the rounded pill.
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }
}
