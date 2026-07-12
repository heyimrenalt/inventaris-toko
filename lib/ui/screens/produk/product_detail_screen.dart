import 'dart:io';

import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';

import '../../../data/models/category.dart';
import '../../../data/models/product.dart';
import '../../../data/repositories/app_settings_repository.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/repository_exceptions.dart';
import '../../../data/repositories/stock_mutation_repository.dart';
import '../../../services/photo_storage_service.dart';
import '../../widgets/confirm_dialog.dart';
import 'product_form_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.isar,
    required this.productId,
    PhotoStorageService? photoStorageService,
  }) : photoStorageService = photoStorageService ?? const ImagePickerPhotoStorageService();

  final Isar isar;
  final int productId;
  final PhotoStorageService photoStorageService;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late final ProductRepository _productRepository = ProductRepository(
    widget.isar,
    StockMutationRepository(widget.isar),
    AppSettingsRepository(widget.isar),
  );
  late final CategoryRepository _categoryRepository = CategoryRepository(widget.isar);

  Product? _product;
  Category? _category;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final product = await _productRepository.getById(widget.productId);
    final category = product == null ? null : await _categoryRepository.getById(product.categoryId);
    if (!mounted) return;
    setState(() {
      _product = product;
      _category = category;
      _loading = false;
    });
  }

  void _showNotAvailable() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fitur ini belum tersedia')),
    );
  }

  Future<void> _editProduct() async {
    final product = _product;
    if (product == null) return;

    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProductFormScreen(
          isar: widget.isar,
          existing: product,
          photoStorageService: widget.photoStorageService,
        ),
      ),
    );
    await _load();
  }

  Future<void> _confirmDelete() async {
    final product = _product;
    if (product == null) return;

    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Hapus Produk',
      message: "Hapus produk '${product.name}'? Tindakan ini tidak bisa dibatalkan.",
      confirmLabel: 'Hapus',
      isDestructive: true,
    );
    if (confirmed != true) return;
    if (!mounted) return;

    try {
      await _productRepository.delete(product.id);
      final photoPath = product.photoPath;
      if (photoPath != null && photoPath.isNotEmpty) {
        await widget.photoStorageService.deletePhoto(photoPath);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produk dihapus')),
      );
      Navigator.of(context).pop(true);
    } on ProductHasHistoryException catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Tidak Bisa Dihapus', style: TextStyle(fontSize: 18)),
          content: Text(
            'Produk ini memiliki ${e.mutationCount} riwayat mutasi stok dan tidak '
            'dapat dihapus.',
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = _product;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Produk'),
        actions: product == null
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Edit',
                  onPressed: _editProduct,
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') _confirmDelete();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Hapus produk',
                        style: TextStyle(color: Colors.red, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : product == null
              ? const Center(child: Text('Produk tidak ditemukan', style: TextStyle(fontSize: 16)))
              : _buildContent(product),
    );
  }

  Widget _buildContent(Product product) {
    final isLow = product.currentStock < product.minStockThreshold;
    final stockColor = isLow ? Colors.red : Colors.green;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: _buildPhoto(product.photoPath)),
          const SizedBox(height: 16),
          Text(product.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          if (product.code != null && product.code!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Kode: ${product.code}',
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
          ],
          const SizedBox(height: 12),
          _infoRow('Kategori', _category?.name ?? '-'),
          _infoRow('Harga jual', _formatCurrency(product.sellPrice)),
          _infoRow('Satuan', product.unit),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: stockColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: stockColor),
            ),
            child: Text(
              'Stok saat ini: ${_formatQuantity(product.currentStock)} ${product.unit}'
              '${isLow ? ' (di bawah batas minimum)' : ''}',
              style: TextStyle(fontSize: 16, color: stockColor, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          _infoRow('Batas minimum', '${_formatQuantity(product.minStockThreshold)} ${product.unit}'),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showNotAvailable,
                  icon: const Icon(Icons.add_box_outlined),
                  label: const Text('Stok masuk', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showNotAvailable,
                  icon: const Icon(Icons.remove_circle_outline),
                  label: const Text('Stok keluar', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Riwayat Mutasi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Riwayat mutasi belum tersedia',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoto(String? photoPath) {
    if (photoPath == null || photoPath.isEmpty) {
      return Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(12)),
        child: Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[600]),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(
        File(photoPath),
        width: 160,
        height: 160,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 160,
          height: 160,
          color: Colors.grey[300],
          child: const Icon(Icons.broken_image),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: TextStyle(fontSize: 16, color: Colors.grey[700])),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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

String _formatCurrency(double value) {
  final rounded = value.round();
  final digits = rounded.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final positionFromEnd = digits.length - i;
    buffer.write(digits[i]);
    if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
      buffer.write('.');
    }
  }
  return 'Rp $buffer';
}
