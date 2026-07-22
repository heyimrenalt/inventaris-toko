import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Rounded gray placeholder with a package icon — the fallback shown
/// wherever a product has no photo.
class ProductThumb extends StatelessWidget {
  const ProductThumb({super.key, this.size = 52});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.gray100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        Icons.inventory_2_outlined,
        color: AppColors.gray500,
        size: size * 0.42,
      ),
    );
  }
}
