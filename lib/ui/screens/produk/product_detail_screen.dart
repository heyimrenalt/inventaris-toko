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
import '../../../domain/hpp_calculator.dart';
import '../../../domain/unit_conversion.dart';
import '../../../services/photo_storage_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_header.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/mutation_list_item.dart';
import '../mutasi/catat_mutasi_screen.dart';
import '../mutasi/catat_stok_keluar_batch_screen.dart';
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

  static const int _recentMutationsLimit = 7;

  Product? _product;
  String? _categoryBreadcrumb;
  List<StockMutation> _recentMutations = [];
  bool _hasMoreMutations = false;
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
    // Fetch one more than we display so we can tell whether a
    // "Selengkapnya" button is warranted (more than the 7 shown exist)
    // without a separate count query.
    final recentPlusOne = product == null
        ? <StockMutation>[]
        : await _stockMutationRepository.getRecentHistoryForProduct(
            product.id,
            _recentMutationsLimit + 1,
          );
    final hasMore = recentPlusOne.length > _recentMutationsLimit;
    final recentMutations = recentPlusOne.take(_recentMutationsLimit).toList();
    if (!mounted) return;
    setState(() {
      _product = product;
      _categoryBreadcrumb = categoryBreadcrumb;
      _recentMutations = recentMutations;
      _hasMoreMutations = hasMore;
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

  Future<void> _openBatchStokKeluar() async {
    final product = _product;
    if (product == null) return;

    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CatatStokKeluarBatchScreen(isar: widget.isar, initialProduct: product),
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
          // TODO(ui-migration): fontSize 18 has no matching AppTextStyles token.
          title: const Text('Tidak Bisa Dihapus', style: TextStyle(fontSize: 18)),
          content: Text(
            'Produk ini memiliki ${e.mutationCount} riwayat mutasi stok dan tidak '
            'dapat dihapus. Anda bisa mengarsipkan produk ini agar tidak muncul '
            'di daftar utama, tanpa menghapus riwayatnya.',
            // TODO(ui-migration): the fontSize 16 in this dialog (content and
            // both action labels) can't become AppTextStyles.subheading — that
            // token also forces w400 -> w700, which is not a neutral swap.
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

  void _showProductMenu(Product product) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        // TODO(ui-migration): bottom-sheet top radius 20 — no
        // semantically-correct radius token (pillRadius is 20 but means a pill).
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'Kelola Produk',
                  style: AppTextStyles.heading,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: AppColors.primary),
                title: const Text('Edit produk'),
                onTap: () {
                  Navigator.pop(context);
                  _editProduct();
                },
              ),
              if (product.isArchived)
                ListTile(
                  leading: const Icon(Icons.unarchive_rounded, color: AppColors.primary),
                  title: const Text('Pulihkan produk'),
                  onTap: () {
                    Navigator.pop(context);
                    _unarchiveProduct(product);
                  },
                )
              else ...[
                ListTile(
                  leading: const Icon(Icons.archive_rounded, color: AppColors.primary),
                  title: const Text('Arsipkan produk'),
                  onTap: () {
                    Navigator.pop(context);
                    _archiveProduct(product);
                  },
                ),
                ListTile(
                  // TODO(ui-migration): Colors.red (0xFFF44336) has no exact
                  // token — AppColors.redPrimary/redText are different hexes,
                  // so swapping would change the rendered color.
                  leading: const Icon(Icons.delete_rounded, color: Colors.red),
                  title: const Text('Hapus produk', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDelete();
                  },
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = _product;
    return Scaffold(
      appBar: AppHeader.withBack(
        title: 'Detail Produk',
        onBack: () => Navigator.of(context).pop(),
        trailing: product == null
            ? null
            : IconButton(
                key: const Key('product_detail_menu_button'),
                icon: const Icon(Icons.more_vert_rounded),
                onPressed: () => _showProductMenu(product),
              ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : product == null
              // TODO(ui-migration): fontSize 16 -> subheading would also change
              // w400 -> w700; not a neutral swap.
              ? const Center(child: Text('Produk tidak ditemukan', style: TextStyle(fontSize: 16)))
              : _buildContent(product),
    );
  }

  Widget _buildContent(Product product) {
    final isLow = product.currentStock < product.minStockThreshold;
    // TODO(ui-migration): low-stock indicator color is display logic, left as
    // is. Colors.red/Colors.green also have no exact AppColors equivalent.
    final stockColor = isLow ? Colors.red : Colors.green;

    return SingleChildScrollView(
      // Always allow the gesture even when content is short, and reserve the
      // system nav-bar inset at the bottom so the last rows/buttons scroll
      // fully clear of it (the "scroll terasa belum dinamis" report).
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: _buildPhoto(product.photoPath)),
          const SizedBox(height: AppSpacing.lg),
          if (product.isArchived) ...[
            Container(
              // TODO(ui-migration): horizontal 14 / vertical 10 are off the
              // AppSpacing scale; grey[200] has no exact token (gray300/gray100
              // are different hexes); radius 10 has no semantically-correct
              // token (stockBadgeRadius is 10 but means a stock chip).
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Diarsipkan pada ${_formatDate(product.archivedAt)}',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.gray700),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          Text(
            product.name,
            key: const Key('product_detail_name'),
            style: AppTextStyles.heading,
          ),
          if (product.code != null && product.code!.isNotEmpty) ...[
            // TODO(ui-migration): 6 off-scale
            const SizedBox(height: 6),
            Text(
              'Kode: ${product.code}',
              style: AppTextStyles.body.copyWith(color: AppColors.gray700),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          _infoRow('Kategori', _categoryBreadcrumb ?? 'Lainnya'),
          _infoRow('Harga jual', _formatCurrency(product.sellPrice)),
          _infoRow('Satuan', product.unit),
          const SizedBox(height: AppSpacing.md),
          Container(
            // TODO(ui-migration): horizontal 14 is off the AppSpacing scale;
            // radius 10 has no semantically-correct token here.
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: AppSpacing.md),
            decoration: BoxDecoration(
              color: stockColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: stockColor, width: 1.5),
            ),
            child: Text(
              'Stok saat ini: ${_formatQuantity(product.currentStock)} ${product.unit}'
              '${isLow ? ' (di bawah batas minimum)' : ''}',
              style: AppTextStyles.bodyMedium.copyWith(color: stockColor),
            ),
          ),
          if (_stockConversionLine(product.currentStock, product.unitsPerPack, product.unitsPerDus)
              case final conversion?)
            Padding(
              // TODO(ui-migration): top 6 is off the AppSpacing scale;
              // grey[600] has no exact token (gray700/gray500 differ).
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                conversion,
                key: const Key('product_detail_stock_conversion'),
                style: AppTextStyles.caption.copyWith(color: Colors.grey[600]),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          _infoRow('Batas minimum', '${_formatQuantity(product.minStockThreshold)} ${product.unit}'),
          const SizedBox(height: AppSpacing.md),
          _buildHppSection(product),
          _buildKemasanSection(product),
          const SizedBox(height: AppSpacing.md),
          if (product.isArchived)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _unarchiveProduct(product),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                icon: const Icon(Icons.unarchive_outlined),
                // TODO(ui-migration): AppTextStyles.body would force
                // color: darkText over the button's white foreground.
                label: const Text('Pulihkan produk', style: TextStyle(fontSize: 14)),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openCatatMutasi(StockMutationType.stockIn),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    icon: const Icon(Icons.add_box_outlined),
                    // TODO(ui-migration): AppTextStyles.body would force
                    // color: darkText over the button's white foreground.
                    label: const Text('Stok masuk', style: TextStyle(fontSize: 14)),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _openBatchStokKeluar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.redPrimary,
                    ),
                    icon: const Icon(Icons.remove_circle_outline),
                    // TODO(ui-migration): AppTextStyles.body would force
                    // color: darkText over the button's white foreground.
                    label: const Text('Stok keluar', style: TextStyle(fontSize: 14)),
                  ),
                ),
              ],
            ),
          const SizedBox(height: AppSpacing.xxl),
          // Heading with the "Lihat semua" action inline on the right — only
          // shown when there's more history than the 7 rows below, so the
          // user reaches the full list without scrolling past every row.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('Riwayat Mutasi', style: AppTextStyles.subheading),
              const Spacer(),
              if (_hasMoreMutations)
                TextButton.icon(
                  key: const Key('product_detail_selengkapnya_button'),
                  onPressed: () => _openFullHistory(product),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.primary),
                  iconAlignment: IconAlignment.end,
                  label: Text(
                    'Lihat semua',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (_recentMutations.isEmpty)
            Text(
              'Belum ada riwayat mutasi.',
              // TODO(ui-migration): grey[600] has no exact token.
              style: AppTextStyles.body.copyWith(color: Colors.grey[600]),
            )
          else
            for (final mutation in _recentMutations)
              MutationListItem(mutation: mutation, productName: product.name, unit: product.unit),
        ],
      ),
    );
  }

  Widget _buildPhoto(String? photoPath) {
    if (photoPath == null || photoPath.isEmpty) {
      // TODO(ui-migration): image radius 12 has no semantically-correct token
      // (inputRadius is 12 but means a form field); grey[600] has no exact
      // token.
      return Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          color: AppColors.gray300,
          borderRadius: BorderRadius.circular(12),
        ),
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
          color: AppColors.gray300,
          child: const Icon(Icons.broken_image),
        ),
      ),
    );
  }

  Widget _buildHppSection(Product product) {
    final avgCost = product.averageCostPrice;
    final profit = HppCalculator.profitPerUnit(product.sellPrice, avgCost);
    final margin = HppCalculator.marginPercent(product.sellPrice, avgCost);

    return Container(
      key: const Key('product_detail_hpp_section'),
      width: double.infinity,
      // TODO(ui-migration): horizontal 14 is off the AppSpacing scale; radius
      // 10 has no semantically-correct token here.
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.gray100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow('HPP', avgCost == null ? 'Belum ada data harga modal' : '${_formatCurrency(avgCost)}/unit'),
          if (profit != null) _infoRow('Untung per unit', _formatCurrency(profit)),
          if (margin != null) _infoRow('Margin', '${margin.round()}%'),
        ],
      ),
    );
  }

  /// Shown whenever the product has any packaging tier configured — a
  /// pack, a dus, or both. A dus can be defined directly in pcs without a
  /// pack tier (see UnitConversion), so this must not require unitsPerPack
  /// to be set — that was hiding the whole section for dus-only products.
  Widget _buildKemasanSection(Product product) {
    final unitsPerPack = product.unitsPerPack;
    final unitsPerDus = product.unitsPerDus;
    if (unitsPerPack == null && unitsPerDus == null) return const SizedBox.shrink();

    final lines = <String>[];
    if (unitsPerPack != null) {
      lines.add('1 pack = ${_formatGrouped(unitsPerPack.toDouble())} pcs');
    }
    if (unitsPerDus != null) {
      if (unitsPerPack != null) {
        lines.add(
          '1 dus = ${_formatGrouped(unitsPerDus.toDouble())} pack = '
          '${_formatGrouped((unitsPerDus * unitsPerPack).toDouble())} pcs',
        );
      } else {
        // Dus defined directly in pcs, skipping the pack tier entirely.
        lines.add('1 dus = ${_formatGrouped(unitsPerDus.toDouble())} pcs');
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Container(
        key: const Key('product_detail_kemasan_section'),
        width: double.infinity,
        // TODO(ui-migration): horizontal 14 is off the AppSpacing scale; radius
        // 10 has no semantically-correct token here.
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.gray100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kemasan', style: AppTextStyles.bodyMedium),
            const SizedBox(height: AppSpacing.sm),
            for (var i = 0; i < lines.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.xs),
              Text(lines[i], style: AppTextStyles.body),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    final isHeading = ['HPP', 'Untung per unit', 'Margin', 'Stok saat ini'].contains(label);
    final labelColor = isHeading ? AppColors.primary : AppColors.gray700;
    return Padding(
      // TODO(ui-migration): vertical 6 is off the AppSpacing scale.
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: AppTextStyles.body.copyWith(color: labelColor)),
          ),
          Expanded(
            child: Text(value, style: AppTextStyles.bodyMedium),
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

/// Handles negative values (unlike a plain price formatter would need to) —
/// "Untung per unit" can be negative when the cost price exceeds the sell
/// price, so the sign is split off before grouping digits.
String _formatCurrency(double value) {
  final isNegative = value < 0;
  final digits = value.abs().round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final positionFromEnd = digits.length - i;
    buffer.write(digits[i]);
    if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
      buffer.write('.');
    }
  }
  return 'Rp ${isNegative ? '-' : ''}$buffer';
}

/// "= 6 pack = 1 dus" breakdown of [currentStock] — each tier shown only
/// when it independently divides evenly (epsilon 0.001), `null` when
/// neither tier is configured or neither divides evenly.
String? _stockConversionLine(double currentStock, int? unitsPerPack, int? unitsPerDus) {
  final parts = <String>[];
  if (unitsPerPack != null) {
    final packs = UnitConversion.fromPcs(
      qtyInPcs: currentStock,
      unit: EnteredUnit.pack,
      unitsPerPack: unitsPerPack,
      unitsPerDus: unitsPerDus,
    );
    if (_isWholeNumber(packs)) parts.add('${_formatGrouped(packs)} pack');
  }
  if (unitsPerDus != null) {
    final dus = UnitConversion.fromPcs(
      qtyInPcs: currentStock,
      unit: EnteredUnit.dus,
      unitsPerPack: unitsPerPack,
      unitsPerDus: unitsPerDus,
    );
    if (_isWholeNumber(dus)) parts.add('${_formatGrouped(dus)} dus');
  }
  if (parts.isEmpty) return null;
  return '= ${parts.join(' = ')}';
}

bool _isWholeNumber(double value) => (value - value.roundToDouble()).abs() < 0.001;

String _formatGrouped(double value) {
  final digits = value.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final positionFromEnd = digits.length - i;
    buffer.write(digits[i]);
    if (positionFromEnd > 1 && positionFromEnd % 3 == 1) buffer.write('.');
  }
  return buffer.toString();
}
