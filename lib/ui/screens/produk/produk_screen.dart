import 'dart:async';

import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';

import '../../../data/models/category.dart';
import '../../../data/models/product.dart';
import '../../../data/repositories/app_settings_repository.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/stock_mutation_repository.dart';
import '../../widgets/category_tree_picker.dart';
import '../../widgets/product_list_item.dart';
import 'archived_products_screen.dart';
import 'product_detail_screen.dart';
import 'product_form_screen.dart';

class ProdukScreen extends StatefulWidget {
  const ProdukScreen({super.key, required this.isar});

  final Isar isar;

  @override
  State<ProdukScreen> createState() => _ProdukScreenState();
}

class _ProdukScreenState extends State<ProdukScreen> {
  late final ProductRepository _productRepository = ProductRepository(
    widget.isar,
    StockMutationRepository(widget.isar),
    AppSettingsRepository(widget.isar),
  );
  late final CategoryRepository _categoryRepository = CategoryRepository(widget.isar);

  final TextEditingController _searchController = TextEditingController();

  List<Product> _products = [];
  List<Category> _categories = [];
  CategorySelection _selection = const CategorySelection.all();
  String _searchQuery = '';
  bool _loading = true;

  StreamSubscription<void>? _productsSubscription;
  StreamSubscription<void>? _categoriesSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    // MainScaffold keeps every tab alive in an IndexedStack, so this
    // screen's own initState only runs once — recording a stock mutation
    // from Product Detail or the Mutasi tab (both separately-mounted
    // screens) changes Product.currentStock without this list ever
    // reloading. watchLazy() fires whenever the products collection
    // changes anywhere in the app, so the list stays correct without a
    // manual reload. Same pattern as MutasiScreen's mutation stream.
    _productsSubscription = widget.isar.products.watchLazy().listen((_) => _loadData());
    // Same reasoning for categories: adding/renaming one from Kelola
    // Kategori (Pengaturan tab, a separately-mounted screen) needs to
    // reach both the filter chips here and the dropdown in
    // CategoryPickerField without a manual reload or app restart.
    _categoriesSubscription = widget.isar.categories.watchLazy().listen((_) => _loadData());
  }

  @override
  void dispose() {
    _productsSubscription?.cancel();
    _categoriesSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final categories = await _categoryRepository.getAll();
    final selection = _selection;
    final Future<List<Product>> productsFuture;
    if (selection.isUncategorized) {
      productsFuture = _productRepository.getUncategorized();
    } else if (selection.isCategory) {
      productsFuture = _productRepository.getByCategoryIncludingDescendants(selection.categoryId!);
    } else {
      productsFuture = _productRepository.getAll();
    }
    final products = await productsFuture;
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _products = products;
      _loading = false;
    });
  }

  Future<void> _openCategoryFilterPicker() async {
    final result = await showCategoryTreePicker(
      context: context,
      isar: widget.isar,
      includeAllOption: true,
      current: _selection,
    );
    if (result == null) return;

    setState(() {
      _selection = result;
      _loading = true;
    });
    _loadData();
  }

  /// [_products] (already scoped to the selected category, and always
  /// excluding archived products, by [_loadData]'s repository query)
  /// further filtered by [_searchQuery] in memory — same reasoning as
  /// MutasiScreen's `_visibleMutations`: this app's expected data scale
  /// makes in-memory filtering of the already-loaded list cheap, so
  /// there's no need for a separate repository query per keystroke.
  List<Product> get _visibleProducts =>
      filterProducts(products: _products, searchQuery: _searchQuery);

  Future<void> _openAddForm() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProductFormScreen(isar: widget.isar)),
    );
    await _loadData();
  }

  Future<void> _openDetail(Product product) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(isar: widget.isar, productId: product.id),
      ),
    );
    await _loadData();
  }

  Future<void> _openArchivedProducts() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => ArchivedProductsScreen(isar: widget.isar)),
    );
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Produk')),
      // One CustomScrollView for the whole body (header controls as
      // sliver-wrapped boxes, the product list as a sliver list) rather
      // than a Column with a fixed-size header + Expanded list: with the
      // latter, a short viewport (landscape orientation, a small phone,
      // or a keyboard eating vertical space) can't shrink the header
      // controls, so once their combined height exceeds what's left
      // after the bottomNavigationBar and AppBar, the Expanded child gets
      // squeezed to nothing and the layout still overflows. A single
      // scrollable lets the whole screen — header included — scroll
      // instead, so it never overflows regardless of viewport size. Same
      // reasoning as MutasiScreen's body (see its build() comment).
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildSearchField()),
          SliverToBoxAdapter(child: _buildCategoryFilter()),
          const SliverToBoxAdapter(child: Divider(height: 1)),
          SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _openArchivedProducts,
                icon: const Icon(Icons.archive_outlined),
                label: const Text('Lihat produk diarsipkan', style: TextStyle(fontSize: 14)),
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_visibleProducts.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: _buildEmptyState())
          else
            _buildProductList(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _openAddForm,
              icon: const Icon(Icons.add),
              label: const Text('Tambah Produk', style: TextStyle(fontSize: 16)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: TextField(
        key: const Key('produk_search'),
        controller: _searchController,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          labelText: 'Cari produk',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  /// A tappable filter row rather than the flat horizontal chips this
  /// screen used before nesting existed — a deep category tree doesn't
  /// fit into a single-row chip list, so filtering now opens
  /// [CategoryTreePicker] (with fixed "Semua"/"Lainnya" options above the
  /// tree) instead.
  Widget _buildCategoryFilter() {
    final selection = _selection;
    final String label;
    if (selection.isAll) {
      label = 'Semua';
    } else if (selection.isUncategorized) {
      label = 'Lainnya';
    } else {
      label = selection.breadcrumb!;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: InkWell(
        key: const Key('produk_category_filter'),
        onTap: _openCategoryFilterPicker,
        borderRadius: BorderRadius.circular(8),
        child: InputDecorator(
          decoration: const InputDecoration(labelText: 'Kategori'),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    // Search/category yielding nothing from a non-empty product list is
    // shown distinctly from "there are no products (in this category) at
    // all" — same distinction MutasiScreen makes between "Tidak
    // ditemukan." and its own no-history empty state.
    final message = _products.isEmpty
        ? (_selection.isAll
            ? 'Belum ada produk. Tambahkan produk pertama untuk mulai.'
            : 'Tidak ada produk pada kategori ini.')
        : 'Tidak ditemukan.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildProductList() {
    final categoryNameById = {for (final category in _categories) category.id: category.name};
    final visible = _visibleProducts;

    return SliverList.separated(
      itemCount: visible.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final product = visible[index];
        final categoryId = product.categoryId;
        return ProductListItem(
          product: product,
          categoryName: categoryId == null ? 'Lainnya' : (categoryNameById[categoryId] ?? '-'),
          onTap: () => _openDetail(product),
        );
      },
    );
  }
}

/// Pure filtering logic, extracted so it's directly unit-testable — same
/// reasoning as MutasiScreen's `filterMutations`. Matches product name or
/// code (when present), case-insensitive substring.
List<Product> filterProducts({
  required List<Product> products,
  String searchQuery = '',
}) {
  final query = searchQuery.trim().toLowerCase();
  if (query.isEmpty) return products;

  return products.where((product) {
    final nameMatch = product.name.toLowerCase().contains(query);
    final codeMatch = (product.code ?? '').toLowerCase().contains(query);
    return nameMatch || codeMatch;
  }).toList();
}
