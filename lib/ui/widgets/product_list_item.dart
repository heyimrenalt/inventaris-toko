import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/models/product.dart';

/// A single row in the Produk list: a left-edge color bar (green/red by
/// stock level — an actual visible strip, not a small dot, per the "color
/// used meaningfully" design principle), a thumbnail, name/category, and
/// current stock.
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

  bool get _isLowStock => product.currentStock < product.minStockThreshold;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 76,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              key: Key('stock_indicator_${product.id}'),
              width: 6,
              color: _isLowStock ? Colors.red : Colors.green,
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _Thumbnail(photoPath: product.photoPath),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    categoryName,
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${_formatQuantity(product.currentStock)} ${product.unit}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _isLowStock ? Colors.red[700] : Colors.green[700],
                ),
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
      color: Colors.grey[300],
      child: Icon(Icons.inventory_2_outlined, color: Colors.grey[600]),
    );
  }
}
