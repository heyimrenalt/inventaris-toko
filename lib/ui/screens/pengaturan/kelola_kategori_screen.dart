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
import '../../widgets/category_form_dialog.dart';
import '../../widgets/confirm_dialog.dart';

class KelolaKategoriScreen extends StatefulWidget {
  const KelolaKategoriScreen({super.key, required this.isar});

  final Isar isar;

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
    // mounted screen (Produk tab, product form) while this screen stays
    // alive underneath in MainScaffold's IndexedStack — the aggregate
    // product-count badges need to reflect that without a manual reload.
    _categoriesSubscription = widget.isar.categories.watchLazy().listen((_) => _loadData());
    _productsSubscription = widget.isar.products.watchLazy().listen((_) => _loadData());
  }

  @override
  void dispose() {
    _categoriesSubscription?.cancel();
    _productsSubscription?.cancel();
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

  Map<int?, List<Category>> get _childrenByParentId {
    final map = <int?, List<Category>>{};
    for (final category in _categories) {
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
    final childrenByParentId = _childrenByParentId;
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

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
    _showSnackBar(existing == null ? 'Kategori ditambahkan' : 'Kategori diperbarui');
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
      _showSnackBar('Kategori dihapus');
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
        title: const Text('Tidak Bisa Dihapus', style: TextStyle(fontSize: 18)),
        content: Text(message, style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Kategori')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
              ? _buildEmptyState()
              : _buildCategoryTree(),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => _showCategoryFormDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Kategori', style: TextStyle(fontSize: 16)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Belum ada kategori. Tambahkan kategori pertama untuk mulai.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildCategoryTree() {
    final childrenByParentId = _childrenByParentId;
    final aggregateCounts = _aggregateProductCounts();
    final roots = childrenByParentId[null] ?? const <Category>[];

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final root in roots)
          _CategoryTreeTile(
            category: root,
            depth: 0,
            childrenByParentId: childrenByParentId,
            aggregateCounts: aggregateCounts,
            expandedIds: _expandedIds,
            onToggleExpand: (id) => setState(() {
              if (!_expandedIds.add(id)) _expandedIds.remove(id);
            }),
            onRename: (category) => _showCategoryFormDialog(existing: category),
            onDelete: _confirmDelete,
            onAddChild: (parent) => _showCategoryFormDialog(parentId: parent.id),
          ),
      ],
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 16.0 + depth * 20, right: 4, top: 4, bottom: 4),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: children.isEmpty
                    ? null
                    : IconButton(
                        key: Key('kelola_kategori_expand_${category.id}'),
                        padding: EdgeInsets.zero,
                        icon: Icon(expanded ? Icons.expand_more : Icons.chevron_right),
                        onPressed: () => onToggleExpand(category.id),
                      ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      countLabel,
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: Key('kelola_kategori_add_child_${category.id}'),
                icon: const Icon(Icons.add),
                tooltip: 'Tambah sub-kategori',
                onPressed: () => onAddChild(category),
              ),
              IconButton(
                key: Key('kelola_kategori_rename_${category.id}'),
                icon: const Icon(Icons.edit),
                tooltip: 'Ubah',
                onPressed: () => onRename(category),
              ),
              IconButton(
                key: Key('kelola_kategori_delete_${category.id}'),
                icon: const Icon(Icons.delete),
                tooltip: 'Hapus',
                color: Colors.red,
                onPressed: () => onDelete(category),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
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
}
