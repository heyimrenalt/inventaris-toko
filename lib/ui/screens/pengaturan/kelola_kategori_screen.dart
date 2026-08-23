import 'dart:async';

import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';

import '../../../data/models/category.dart';
import '../../../data/models/product.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/app_settings_repository.dart';
import '../../../data/repositories/stock_mutation_repository.dart';
import '../../../data/repositories/repository_exceptions.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_search_bar.dart';
import '../../widgets/app_snack.dart';
import '../../widgets/category_form_dialog.dart';
import '../../widgets/confirm_dialog.dart';

/// The "Kelola Kategori" management UI, presented as a bottom sheet from
/// Pengaturan rather than a pushed page.
class KelolaKategoriScreen extends StatefulWidget {
  const KelolaKategoriScreen({super.key, required this.isar});

  final Isar isar;

  /// Opens this screen as a modal bottom sheet with rounded top corners.
  static Future<void> show(BuildContext context, {required Isar isar}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => KelolaKategoriScreen(isar: isar),
    );
  }

  @override
  State<KelolaKategoriScreen> createState() => _KelolaKategoriScreenState();
}

class _KelolaKategoriScreenState extends State<KelolaKategoriScreen> {
  late final CategoryRepository _categoryRepository = CategoryRepository(widget.isar);
  late final ProductRepository _productRepository = ProductRepository(
    widget.isar,
    StockMutationRepository(widget.isar),
    AppSettingsRepository(widget.isar),
  );

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<Category> _categories = [];
  List<Product> _products = [];
  bool _loading = true;
  final Set<int> _expandedIds = {};

  StreamSubscription<void>? _categoriesSubscription;
  StreamSubscription<void>? _productsSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    // A product's category (or existence) can change from a separately
    // mounted screen (Produk tab, product form) while this sheet stays
    // open above it — the aggregate product-count badges need to reflect
    // that without a manual reload.
    _categoriesSubscription = widget.isar.categories.watchLazy().listen((_) => _loadData());
    _productsSubscription = widget.isar.products.watchLazy().listen((_) => _loadData());
  }

  @override
  void dispose() {
    _categoriesSubscription?.cancel();
    _productsSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final categories = await _categoryRepository.getAll();
    // Aggregate counts intentionally include archived products, matching
    // CategoryRepository.delete's in-use check — archiving a product
    // doesn't remove its category reference, so it must still count
    // towards "this category/subtree is in use".
    final products = await _productRepository.getAll(includeArchived: true);
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _products = products;
      _loading = false;
    });
  }

  Map<int?, List<Category>> _childrenByParentIdOf(List<Category> categories) {
    final map = <int?, List<Category>>{};
    for (final category in categories) {
      map.putIfAbsent(category.parentId, () => []).add(category);
    }
    for (final siblings in map.values) {
      siblings.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return map;
  }

  /// Aggregate product count per category id (this category's direct
  /// products plus every descendant's), computed once from the already
  /// loaded flat lists rather than one repository round-trip per node.
  Map<int, int> _aggregateProductCounts() {
    final childrenByParentId = _childrenByParentIdOf(_categories);
    final directCounts = <int, int>{};
    for (final product in _products) {
      final categoryId = product.categoryId;
      if (categoryId != null) {
        directCounts[categoryId] = (directCounts[categoryId] ?? 0) + 1;
      }
    }

    final aggregate = <int, int>{};
    int compute(int id) {
      if (aggregate.containsKey(id)) return aggregate[id]!;
      var total = directCounts[id] ?? 0;
      for (final child in childrenByParentId[id] ?? const <Category>[]) {
        total += compute(child.id);
      }
      aggregate[id] = total;
      return total;
    }

    for (final category in _categories) {
      compute(category.id);
    }
    return aggregate;
  }

  /// Categories to render: everything when there's no search query;
  /// otherwise name matches plus their ancestors, so a matched child stays
  /// reachable under its parent instead of floating without context.
  List<Category> _visibleCategories() {
    if (_searchQuery.isEmpty) return _categories;
    final query = _searchQuery.toLowerCase();
    final byId = {for (final c in _categories) c.id: c};
    final keep = <int>{};
    for (final category in _categories) {
      if (!category.name.toLowerCase().contains(query)) continue;
      var current = category;
      while (true) {
        keep.add(current.id);
        final parentId = current.parentId;
        if (parentId == null) break;
        final parent = byId[parentId];
        if (parent == null) break;
        current = parent;
      }
    }
    return _categories.where((c) => keep.contains(c.id)).toList();
  }

  Future<void> _showCategoryFormDialog({Category? existing, int? parentId}) async {
    final result = await showCategoryFormDialog(
      context: context,
      repository: _categoryRepository,
      existing: existing,
      parentId: parentId,
    );
    if (result == null) return;
    if (parentId != null) {
      setState(() => _expandedIds.add(parentId));
    }
    await _loadData();
    if (!mounted) return;
    AppSnack.success(
      context,
      existing == null ? 'Kategori ditambahkan' : 'Kategori diperbarui',
    );
  }

  Future<void> _confirmDelete(Category category) async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Hapus Kategori',
      message: "Hapus kategori '${category.name}'? Tindakan ini tidak bisa dibatalkan.",
      confirmLabel: 'Hapus',
      isDestructive: true,
    );
    if (confirmed != true) return;
    if (!mounted) return;

    try {
      await _categoryRepository.delete(category.id);
      await _loadData();
      if (!mounted) return;
      AppSnack.success(context, 'Kategori dihapus');
    } on CategoryInUseException catch (e) {
      if (!mounted) return;
      await _showBlockedDialog(
        'Kategori ini masih dipakai oleh ${e.productCount} produk (termasuk sub-kategori). '
        'Hapus atau pindahkan produk tersebut terlebih dahulu.',
      );
    } on CategoryHasChildrenException catch (e) {
      if (!mounted) return;
      await _showBlockedDialog(
        'Kategori ini masih memiliki ${e.childCount} sub-kategori. '
        'Hapus seluruh sub-kategori terlebih dahulu sebelum menghapus kategori ini.',
      );
    }
  }

  Future<void> _showBlockedDialog(String message) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tidak Bisa Dihapus', style: AppTextStyles.subheading),
        content: Text(message, style: AppTextStyles.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK', style: AppTextStyles.bodyMedium),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleCategories = _visibleCategories();
    final childrenByParentId = _childrenByParentIdOf(visibleCategories);
    final aggregateCounts = _aggregateProductCounts();
    final roots = childrenByParentId[null] ?? const <Category>[];
    final searching = _searchQuery.isNotEmpty;

    // While searching, force every matched branch open so results stay
    // visible regardless of the user's manual expand/collapse state.
    final effectiveExpandedIds = searching
        ? childrenByParentId.keys.whereType<int>().toSet()
        : _expandedIds;

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.cardRadius)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.gray300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Kelola kategori', style: AppTextStyles.heading),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.gray700),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppSearchBar(
                controller: _searchController,
                hintText: 'Cari kategori',
                onChanged: (value) => setState(() => _searchQuery = value.trim()),
              ),
            ),
            Flexible(
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(AppSpacing.xxl),
                      child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    )
                  : roots.isEmpty
                      ? _buildEmptyState(searching)
                      : ListView(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                          children: [
                            for (final root in roots)
                              _CategoryTreeTile(
                                category: root,
                                depth: 0,
                                childrenByParentId: childrenByParentId,
                                aggregateCounts: aggregateCounts,
                                expandedIds: effectiveExpandedIds,
                                onToggleExpand: (id) => setState(() {
                                  if (!_expandedIds.add(id)) _expandedIds.remove(id);
                                }),
                                onRename: (category) =>
                                    _showCategoryFormDialog(existing: category),
                                onDelete: _confirmDelete,
                                onAddChild: (parent) =>
                                    _showCategoryFormDialog(parentId: parent.id),
                              ),
                          ],
                        ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _showCategoryFormDialog(),
                    icon: const Icon(Icons.add, color: AppColors.primary),
                    label: const Text(
                      'Tambah kategori',
                      style: TextStyle(
                        fontFamily: AppTextStyles.fontFamily,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool searching) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Center(
        child: Text(
          searching
              ? 'Kategori tidak ditemukan.'
              : 'Belum ada kategori. Tambahkan kategori pertama untuk mulai.',
          textAlign: TextAlign.center,
          style: AppTextStyles.body.copyWith(color: AppColors.gray500),
        ),
      ),
    );
  }
}

class _CategoryTreeTile extends StatelessWidget {
  const _CategoryTreeTile({
    required this.category,
    required this.depth,
    required this.childrenByParentId,
    required this.aggregateCounts,
    required this.expandedIds,
    required this.onToggleExpand,
    required this.onRename,
    required this.onDelete,
    required this.onAddChild,
  });

  final Category category;
  final int depth;
  final Map<int?, List<Category>> childrenByParentId;
  final Map<int, int> aggregateCounts;
  final Set<int> expandedIds;
  final ValueChanged<int> onToggleExpand;
  final ValueChanged<Category> onRename;
  final ValueChanged<Category> onDelete;
  final ValueChanged<Category> onAddChild;

  @override
  Widget build(BuildContext context) {
    final children = childrenByParentId[category.id] ?? const <Category>[];
    final expanded = expandedIds.contains(category.id);
    final count = aggregateCounts[category.id] ?? 0;
    final countLabel = children.isEmpty
        ? '$count produk'
        : '$count produk (termasuk sub-kategori)';
    final isRoot = depth == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.sm,
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < depth; i++) _buildIndentGuide(),
                SizedBox(
                  width: 28,
                  child: children.isEmpty
                      ? null
                      : IconButton(
                          key: Key('kelola_kategori_expand_${category.id}'),
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            expanded ? Icons.expand_more : Icons.chevron_right,
                            color: AppColors.gray700,
                          ),
                          onPressed: () => onToggleExpand(category.id),
                        ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(category.name, style: AppTextStyles.bodyMedium),
                        Text(
                          countLabel,
                          style: AppTextStyles.caption.copyWith(color: AppColors.gray500),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isRoot)
                  IconButton(
                    key: Key('kelola_kategori_add_child_${category.id}'),
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    color: AppColors.primary,
                    tooltip: 'Tambah sub-kategori',
                    onPressed: () => onAddChild(category),
                  ),
                IconButton(
                  key: Key('kelola_kategori_rename_${category.id}'),
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  color: AppColors.gray700,
                  tooltip: 'Ubah',
                  onPressed: () => onRename(category),
                ),
                IconButton(
                  key: Key('kelola_kategori_delete_${category.id}'),
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: AppColors.gray700,
                  tooltip: 'Hapus',
                  onPressed: () => onDelete(category),
                ),
              ],
            ),
          ),
        ),
        Divider(height: 1, color: AppColors.gray100),
        if (expanded)
          for (final child in children)
            _CategoryTreeTile(
              category: child,
              depth: depth + 1,
              childrenByParentId: childrenByParentId,
              aggregateCounts: aggregateCounts,
              expandedIds: expandedIds,
              onToggleExpand: onToggleExpand,
              onRename: onRename,
              onDelete: onDelete,
              onAddChild: onAddChild,
            ),
      ],
    );
  }

  Widget _buildIndentGuide() {
    return SizedBox(
      width: AppSpacing.xl,
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(width: 1.5, color: AppColors.gray300),
      ),
    );
  }
}
