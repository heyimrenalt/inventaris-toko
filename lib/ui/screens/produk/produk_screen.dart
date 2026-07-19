import 'dart:async';

import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';

import '../../../data/models/category.dart';
import '../../../data/models/product.dart';
import '../../../data/repositories/app_settings_repository.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/stock_mutation_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_search_bar.dart';
import '../../widgets/category_tree_picker.dart';
import '../../widgets/product_list_item.dart';
import 'product_detail_screen.dart';
import 'product_form_screen.dart';
import 'sort_mode.dart';

class ProdukScreen extends StatefulWidget {
  const ProdukScreen({
    super.key,
    required this.isar,
    this.scrollController,
    this.productRepository,
    this.categoryRepository,
  });

  final Isar isar;

  /// Owned by [MainScaffold] so a re-tap of the Produk nav item (while
  /// already on this tab) can animate this screen's list back to the top
  /// without this screen needing to know about the nav bar at all.
  final ScrollController? scrollController;

  /// Test seams only — real callers always let these default to real
  /// repositories built from [isar]. Lets a widget test inject a
  /// call-counting fake to verify pull-to-refresh actually re-queries.
  final ProductRepository? productRepository;
  final CategoryRepository? categoryRepository;

  @override
  State<ProdukScreen> createState() => _ProdukScreenState();
}

class _ProdukScreenState extends State<ProdukScreen> {
  late final ProductRepository _productRepository = widget.productRepository ??
      ProductRepository(
        widget.isar,
        StockMutationRepository(widget.isar),
        AppSettingsRepository(widget.isar),
      );
  late final CategoryRepository _categoryRepository =
      widget.categoryRepository ?? CategoryRepository(widget.isar);

  final TextEditingController _searchController = TextEditingController();

  List<Product> _products = [];
  List<Category> _categories = [];
  CategorySelection _selection = const CategorySelection.all();
  String _searchQuery = '';
  bool _loading = true;
  SortMode _sortMode = SortMode.defaultOrder;

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

  /// Wrapped with a minimum visible duration so a fast local Isar query
  /// doesn't make the RefreshIndicator flash and vanish — that would read
  /// as broken to a non-technical user pulling to refresh an offline app.
  /// [_loadData] itself already re-reads the current [_selection] and
  /// [_searchQuery] from state, so the active category filter and search
  /// term carry over automatically.
  Future<void> _handleRefresh() async {
    await Future.wait([
      _loadData(),
      Future<void>.delayed(const Duration(milliseconds: 300)),
    ]);
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
  /// Results are then sorted according to [_sortMode].
  List<Product> get _visibleProducts {
    final filtered = filterProducts(products: _products, searchQuery: _searchQuery);
    return sortProducts(products: filtered, sortMode: _sortMode);
  }

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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const AppHeader(title: 'Produk'),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _handleRefresh,
              child: CustomScrollView(
                controller: widget.scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        AppSearchBar(
                          controller: _searchController,
                          hintText: 'Cari produk...',
                          onChanged: (query) {
                            setState(() => _searchQuery = query);
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildFilterBar(),
                      ],
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
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddForm,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _toggleSort() {
    setState(() {
      _sortMode = _sortMode == SortMode.defaultOrder
          ? SortMode.stockAscending
          : SortMode.defaultOrder;
    });
  }

  Widget _buildFilterBar() {
    final selection = _selection;
    final String label;
    if (selection.isAll) {
      label = 'Semua kategori';
    } else if (selection.isUncategorized) {
      label = 'Lainnya';
    } else {
      label = selection.breadcrumb!;
    }

    final isSorted = _sortMode == SortMode.stockAscending;
    final sortIconColor = isSorted ? AppColors.primary : AppColors.gray700;
    final sortIcon = isSorted
        ? Icons.arrow_downward_rounded
        : Icons.swap_vert_rounded;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              key: const Key('produk_category_filter'),
              onTap: _openCategoryFilterPicker,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.gray100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkText,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: AppColors.gray700,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.gray100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: const Key('produk_sort_button'),
                onTap: _toggleSort,
                borderRadius: BorderRadius.circular(12),
                child: Icon(
                  sortIcon,
                  size: 24,
                  color: sortIconColor,
                ),
              ),
            ),
          ),
        ],
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

    return SliverList.builder(
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final product = visible[index];
        final categoryId = product.categoryId;
        return Column(
          children: [
            ProductListItem(
              product: product,
              categoryName: categoryId == null ? 'Lainnya' : (categoryNameById[categoryId] ?? '-'),
              onTap: () => _openDetail(product),
            ),
            if (index < visible.length - 1)
              const Divider(height: 0.5, thickness: 0.5, indent: 0, endIndent: 0),
          ],
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

/// Pure sorting logic, extracted so it's directly unit-testable.
/// Sorts by the given [sortMode]. When [sortMode] is [SortMode.stockAscending],
/// sorts by stock ascending with ties broken by name ascending.
List<T> sortProducts<T extends Object>({
  required List<T> products,
  required SortMode sortMode,
}) {
  if (sortMode == SortMode.defaultOrder) {
    return products;
  }

  final sorted = [...products];
  sorted.sort((a, b) {
    final aStock = (a as dynamic).currentStock as double;
    final bStock = (b as dynamic).currentStock as double;
    final aName = (a as dynamic).name as String;
    final bName = (b as dynamic).name as String;

    final stockCompare = aStock.compareTo(bStock);
    if (stockCompare != 0) return stockCompare;
    return aName.compareTo(bName);
  });
  return sorted;
}
