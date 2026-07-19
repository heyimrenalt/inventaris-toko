import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/models/product.dart';
import '../../domain/prioritas_kulakan_calculator.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// A single full-width row in [FrequentlySoldScreen]'s "Lihat Semua" list:
/// photo, name, average daily sales, and current stock.
class FrequentlySoldListItem extends StatelessWidget {
  const FrequentlySoldListItem({super.key, required this.result, required this.onTap});

  final PrioritasKulakanResult result;
  final VoidCallback onTap;

  Product get _product => result.product;

  String get _velocityLine {
    final v = formatVelocity(result.dailyVelocity);
    return _product.currentStock <= 0
        ? 'Rata-rata terjual ~$v/hari (stok kosong)'
        : 'Rata-rata terjual ~$v/hari';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('frequently_sold_row_${_product.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _Thumbnail(photoPath: _product.photoPath),
            const SizedBox(width: 12),
            // "Stok: X unit" used to sit beside this column as a separate
            // Row child, stealing width from it — on a long velocity line
            // ("Rata-rata terjual ~5.5/hari (stok kosong)") that squeezed
            // it down to an ellipsis a non-technical user (this app's
            // primary audience) would have to guess the rest of. Folding
            // it into the column as its own line gives every line the
            // full row width instead.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _product.name,
                    style: AppTextStyles.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _velocityLine,
                    key: Key('frequently_sold_velocity_${_product.id}'),
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.greenText,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'berdasarkan rata-rata ${result.dataAgeDays} hari terakhir',
                    key: Key('frequently_sold_caption_${_product.id}'),
                    style: AppTextStyles.caption.copyWith(color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Stok: ${_formatQuantity(_product.currentStock)} ${_product.unit}',
                    key: Key('frequently_sold_stock_${_product.id}'),
                    style: AppTextStyles.body.copyWith(color: Colors.grey[700]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
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

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.photoPath});

  final String? photoPath;

  @override
  Widget build(BuildContext context) {
    final path = photoPath;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 48,
        height: 48,
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
      color: Colors.grey[300],
      child: Icon(Icons.inventory_2_outlined, color: Colors.grey[600]),
    );
  }
}
