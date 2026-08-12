import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/models/product.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'stock_badge.dart';

/// A single row in the Produk list: thumbnail, product name/category info,
/// and stock badge (colored with quantity and unit).
class ProductListItem extends StatelessWidget {
  const ProductListItem({
    super.key,
    required this.product,
    required this.categoryName,
    required this.onTap,
  });

  final Product product;
  final String categoryName;
  final VoidCallback onTap;

  StockLevel get _stockLevel {
    if (product.currentStock <= 0) return StockLevel.danger;
    if (product.currentStock < product.minStockThreshold) return StockLevel.warning;
    return StockLevel.safe;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        // TODO(ui-migration): no clean token — the 14 vertical inset is
        // off-scale (between AppSpacing.md and .lg); left raw so the row
        // height doesn't change.
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 14,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _Thumbnail(photoPath: product.photoPath),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: AppTextStyles.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // TODO(ui-migration): no clean token — 3 is below
                  // AppSpacing.xs (4); left raw to keep the name/subtitle
                  // gap identical.
                  const SizedBox(height: 3),
                  Text(
                    '$categoryName · Rp ${_formatPrice(product.sellPrice)}',
                    style: AppTextStyles.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StockBadge(
                  text: _formatQuantity(product.currentStock),
                  level: _stockLevel,
                ),
                // TODO(ui-migration): no clean token — 2 is below
                // AppSpacing.xs (4); left raw to keep the badge/unit gap
                // identical.
                const SizedBox(height: 2),
                Text(
                  product.unit,
                  // TODO(ui-migration): no clean token — 10px has no
                  // AppTextStyles entry (caption is 12); kept as a caption
                  // override rather than resizing the unit label.
                  style: AppTextStyles.caption.copyWith(fontSize: 10),
                ),
              ],
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

String _formatPrice(double price) {
  return price.toInt().toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (m) => '.',
  );
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.photoPath});

  final String? photoPath;

  @override
  Widget build(BuildContext context) {
    final path = photoPath;
    return ClipRRect(
      // TODO(ui-migration): no clean token — the thumbnail radius is 10,
      // which only numerically matches AppDimensions.stockBadgeRadius (a
      // stock-chip token, different semantic role). No thumbnail/avatar
      // radius token exists yet. Same for the 52x52 size.
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 52,
        height: 52,
        child: (path == null || path.isEmpty)
            ? _placeholder()
            : Image.file(
                File(path),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _placeholder(),
              ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.gray100,
      child: const Icon(Icons.inventory_2_outlined, color: AppColors.gray500),
    );
  }
}
