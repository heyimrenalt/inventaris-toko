import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';

import '../../../data/models/product.dart';
import '../../../data/models/stock_mutation.dart';
import '../../../data/repositories/app_settings_repository.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/repository_exceptions.dart';
import '../../../data/repositories/stock_mutation_repository.dart';
import '../../../services/photo_storage_service.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/mutation_list_item.dart';
import '../mutasi/catat_mutasi_screen.dart';
import '../mutasi/product_mutation_history_screen.dart';
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
  late final StockMutationRepository _stockMutationRepository = StockMutationRepository(widget.isar);
  late final ProductRepository _productRepository = ProductRepository(
    widget.isar,
    _stockMutationRepository,
    AppSettingsRepository(widget.isar),
  );
  late final CategoryRepository _categoryRepository = CategoryRepository(widget.isar);

  static const int _recentMutationsLimit = 5;

  Product? _product;
  String? _categoryBreadcrumb;
  List<StockMutation> _recentMutations = [];
  bool _loading = true;

  StreamSubscription<void>? _mutationsSubscription;

  @override
  void initState() {
    super.initState();
    _load();
    // Every Product.currentStock change goes through
    // StockMutationRepository.recordMutation, which always writes a
    // StockMutation alongside it — so watching the stockMutations
    // collection (same pattern as MutasiScreen) is enough to catch every
    // stock change for this product without a manual reload after
    // navigation.
    _mutationsSubscription = widget.isar.stockMutations.watchLazy().listen((_) => _load());
  }

  @override
  void dispose() {
    _mutationsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final product = await _productRepository.getById(widget.productId);
    final categoryId = product?.categoryId;
    final categoryBreadcrumb = categoryId == null ? null : await _buildCategoryBreadcrumb(categoryId);
    final recentMutations = product == null
        ? <StockMutation>[]
        : await _stockMutationRepository.getRecentHistoryForProduct(
            product.id,
            _recentMutationsLimit,
          );
    if (!mounted) return;
    setState(() {
      _product = product;
      _categoryBreadcrumb = categoryBreadcrumb;
      _recentMutations = recentMutations;
      _loading = false;
    });
  }

  /// Walks up the parent chain so a nested category shows its full
  /// "Parent > Child" path here, same as the tree picker's selected-value
  /// label on the product form — a bare leaf name would be ambiguous
  /// once the same name can exist under different parents.
  Future<String> _buildCategoryBreadcrumb(int categoryId) async {
    final category = await _categoryRepository.getById(categoryId);
    if (category == null) return '-';

    final parts = [category.name];
    var current = category;
    while (current.parentId != null) {
      final parent = await _categoryRepository.getById(current.parentId!);
      if (parent == null) break;
      parts.insert(0, parent.name);
      current = parent;
    }
    return parts.join(' > ');
  }

  Future<void> _openCatatMutasi(StockMutationType type) async {
    final product = _product;
    if (product == null) return;

    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CatatMutasiScreen(isar: widget.isar, product: product, initialType: type),
      ),
    );
    await _load();
  }

  void _openFullHistory(Product product) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductMutationHistoryScreen(isar: widget.isar, product: product),
      ),
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
      // Blocked by mutation history: offer archiving right here instead
      // of leaving the user at a dead end.
      final shouldArchive = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Tidak Bisa Dihapus', style: TextStyle(fontSize: 18)),
          content: Text(
            'Produk ini memiliki ${e.mutationCount} riwayat mutasi stok dan tidak '
            'dapat dihapus. Anda bisa mengarsipkan produk ini agar tidak muncul '
            'di daftar utama, tanpa menghapus riwayatnya.',
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Tutup', style: TextStyle(fontSize: 16)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Arsipkan produk ini', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      );
      if (shouldArchive == true) {
        await _archiveProduct(product, requireConfirmation: false);
      }
    }
  }

  Future<void> _archiveProduct(Product product, {bool requireConfirmation = true}) async {
    if (requireConfirmation) {
      final confirmed = await showConfirmDialog(
        context: context,
        title: 'Arsipkan Produk',
        message:
            "Arsipkan produk '${product.name}'? Produk tidak akan muncul di daftar "
            'utama, tapi bisa dipulihkan kapan saja.',
        confirmLabel: 'Arsipkan',
      );
      if (confirmed != true) return;
      if (!mounted) return;
    }

    await _productRepository.archive(product.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Produk diarsipkan')),
    );
    Navigator.of(context).pop(true);
  }

  Future<void> _unarchiveProduct(Product product) async {
    await _productRepository.unarchive(product.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Produk dipulihkan')),
    );
    await _load();
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
                    switch (value) {
                      case 'delete':
                        _confirmDelete();
                      case 'archive':
                        _archiveProduct(product);
                      case 'unarchive':
                        _unarchiveProduct(product);
                    }
                  },
                  itemBuilder: (context) => [
                    if (product.isArchived)
                      const PopupMenuItem(
                        value: 'unarchive',
                        child: Text('Pulihkan produk', style: TextStyle(fontSize: 16)),
                      )
                    else ...[
                      const PopupMenuItem(
                        value: 'archive',
                        child: Text('Arsipkan produk', style: TextStyle(fontSize: 16)),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Hapus produk',
                          style: TextStyle(color: Colors.red, fontSize: 16),
                        ),
                      ),
                    ],
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
          if (product.isArchived) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Diarsipkan pada ${_formatDate(product.archivedAt)}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            product.name,
            key: const Key('product_detail_name'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          if (product.code != null && product.code!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Kode: ${product.code}',
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
          ],
          const SizedBox(height: 12),
          _infoRow('Kategori', _categoryBreadcrumb ?? 'Lainnya'),
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
          if (product.isArchived)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _unarchiveProduct(product),
                icon: const Icon(Icons.unarchive_outlined),
                label: const Text('Pulihkan produk', style: TextStyle(fontSize: 16)),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openCatatMutasi(StockMutationType.stockIn),
                    icon: const Icon(Icons.add_box_outlined),
                    label: const Text('Stok masuk', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openCatatMutasi(StockMutationType.stockOut),
                    icon: const Icon(Icons.remove_circle_outline),
                    label: const Text('Stok keluar', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 24),
          const Text('Riwayat Mutasi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_recentMutations.isEmpty)
            Text(
              'Belum ada riwayat mutasi.',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            )
          else ...[
            for (final mutation in _recentMutations)
              MutationListItem(mutation: mutation, productName: product.name, unit: product.unit),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _openFullHistory(product),
                child: const Text('Lihat semua', style: TextStyle(fontSize: 14)),
              ),
            ),
          ],
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

String _formatDate(DateTime? date) {
  if (date == null) return '-';
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
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
