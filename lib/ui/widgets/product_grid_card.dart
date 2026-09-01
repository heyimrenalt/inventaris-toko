import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/models/product.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'stock_badge.dart';

/// One card in the Produk grid: a large product photo on top, then name,
/// category, price and stock.
///
/// Replaces the full-width [ProductListItem] row on the Produk tab. The
/// point of the layout is the photo: at 52x52 in the old row it was an
/// identifying glance, here it fills the card's whole width — roughly
/// nine times the area — because the shop owner reads the shelf by
/// picture faster than by name.
///
/// The stock figure keeps [StockLevel]'s colour but not [StockBadge]'s
/// chip. A chip that wide would compete with the photo, while dropping
/// the colour entirely would throw away the only low-stock signal on
/// this screen, so the level tints the number itself.
class ProductGridCard extends StatelessWidget {
  const ProductGridCard({
    super.key,
    required this.product,
    required this.categoryName,
    required this.onTap,
  });

  final Product product;
  final String categoryName;
  final VoidCallback onTap;

  /// The photo band's shape. Landscape rather than square: a square band
  /// on a half-width card pushes the text so far down that only two rows
  /// of products fit on screen at once.
  static const double _photoAspectRatio = 16 / 10;

  /// How many lines the product name may occupy. Two, not one: real
  /// names on a half-width card run past it constantly — "Silverqueen -
  /// Almond" and "Chitato sapi panggang" both ellipsised at one line,
  /// hiding the very word that tells two variants apart.
  static const int _nameMaxLines = 2;

  /// Height of everything below the photo — name, category, and the
  /// price/stock row, plus their padding. Fixed so the grid can size its
  /// cells without measuring; it therefore has to reserve the name's
  /// full [_nameMaxLines], since a taller name on one card would
  /// otherwise push that card's price row out of its cell.
  ///
  /// 112 = 92 for a one-line name plus ~20 for the second line of
  /// [AppTextStyles.bodyMedium] (14px at its default line height). Cards
  /// whose name fits on one line keep the difference as slack above the
  /// price row, which the [Spacer] absorbs — so every price and stock
  /// figure in a row still sits on the same baseline.
  static const double _textBlockHeight = 112;

  /// Cell height for a given card width, so the grid delegate and this
  /// card can't disagree about it.
  static double extentFor(double cardWidth) =>
      cardWidth / _photoAspectRatio + _textBlockHeight;

  StockLevel get _stockLevel {
    if (product.currentStock <= 0) return StockLevel.danger;
    if (product.currentStock < product.minStockThreshold) return StockLevel.warning;
    return StockLevel.safe;
  }

  Color get _stockColor => switch (_stockLevel) {
        StockLevel.safe => AppColors.greenText,
        StockLevel.warning => AppColors.yellowText,
        StockLevel.danger => AppColors.redText,
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: _photoAspectRatio,
              child: _Photo(
                photoPath: product.photoPath,
                productName: product.name,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: AppTextStyles.bodyMedium,
                      maxLines: _nameMaxLines,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      categoryName,
                      style: AppTextStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(
                            'Rp ${_formatPrice(product.sellPrice)}',
                            style: AppTextStyles.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          _formatQuantity(product.currentStock),
                          style: AppTextStyles.stockNumber.copyWith(color: _stockColor),
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Text(product.unit, style: AppTextStyles.caption),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The photo band, or — far more often, until the shop has photographed
/// its catalogue — a placeholder.
class _Photo extends StatelessWidget {
  const _Photo({required this.photoPath, required this.productName});

  final String? photoPath;
  final String productName;

  @override
  Widget build(BuildContext context) {
    final path = photoPath;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppDimensions.cardRadius),
      ),
      child: Container(
        color: AppColors.gray100,
        width: double.infinity,
        child: (path == null || path.isEmpty)
            ? _Placeholder(productName: productName)
            : Image.file(
                File(path),
                // Contain, not cover: a photo of a packet shot on a
                // counter loses its label to a centre crop, and the label
                // is the whole point of showing it.
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    _Placeholder(productName: productName),
              ),
      ),
    );
  }
}

/// Shown for a product with no photo yet.
///
/// Not the old grey box with a package icon: at this size a screen of
/// those is a wall of identical rectangles with nothing to tell them
/// apart. The product's initial at least makes each card distinct at a
/// glance, and the camera hint says the photo is missing rather than
/// broken.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.productName});

  final String productName;

  String get _initial {
    final trimmed = productName.trim();
    return trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _initial,
            style: AppTextStyles.statNumber.copyWith(color: AppColors.gray500),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Icon(
            Icons.photo_camera_outlined,
            size: AppDimensions.iconXs,
            color: AppColors.gray500,
          ),
        ],
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
