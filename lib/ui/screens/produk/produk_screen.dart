import 'dart:async';

import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';

import '../../../data/models/category.dart';
import '../../../data/models/product.dart';
import '../../../data/repositories/app_settings_repository.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/stock_mutation_repository.dart';
import '../../navigation/keyboard_safe_push.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_search_bar.dart';
import '../../widgets/glass_bottom_nav.dart';
import '../../widgets/category_tree_picker.dart';
import '../../widgets/product_grid_card.dart';
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

  /// [_products] (already scoped to the selected category, archived
  /// excluded) filtered in memory by [_searchQuery], then sorted by
  /// [_sortMode]. In-memory filtering is cheap at this app's data scale.
  List<Product> get _visibleProducts {
    final filtered = filterProducts(products: _products, searchQuery: _searchQuery);
    return sortProducts(products: filtered, sortMode: _sortMode);
  }

  Future<void> _openAddForm() async {
    await keyboardSafePush<bool>(
      context,
      MaterialPageRoute(builder: (_) => ProductFormScreen(isar: widget.isar)),
    );
    await _loadData();
  }

  Future<void> _openDetail(Product product) async {
    // keyboardSafePush keeps the search keyboard from popping back up when
    // we return to this list — see its doc for the ModalRoute focus bug.
    await keyboardSafePush<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(isar: widget.isar, productId: product.id),
      ),
    );
    await _loadData();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(title: 'Produk'),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: CustomScrollView(
          controller: widget.scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: AppSpacing.md),
                  AppSearchBar(
                    controller: _searchController,
                    hintText: 'Cari produk...',
                    onChanged: (query) => setState(() => _searchQuery = query),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildFilterBar(),
                  // The list rows used to sit flush under the filter bar,
                  // separated by their own dividers. Cards need real air
                  // above them instead.
                  const SizedBox(height: AppSpacing.xs),
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
            // Clears the floating glass nav bar below the last product.
            // extendBody already reports the bar's full height as
            // padding.bottom, so this is just that plus a small gap.
            if (!_loading && _visibleProducts.isNotEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  // Nav bar (reported as padding.bottom thanks to
                  // extendBody, so it follows the real bar rather than a
                  // hardcoded height) plus the FAB, which floats over the
                  // right-hand column and would otherwise sit on the last
                  // card's price and stock once the list is scrolled to
                  // the end. Both are cleared, so scrolling all the way
                  // down always leaves the final row fully readable.
                  height: MediaQuery.of(context).padding.bottom +
                      GlassBottomNav.contentGap +
                      _fabSize +
                      AppSpacing.md,
                ),
              ),
          ],
        ),
      ),
      // extendBody (for the glass nav) makes the body — and so the FAB's
      // default anchor — run to the screen bottom, which would tuck the FAB
      // under the floating nav. Lift it by the bar's height (which
      // extendBody reports as padding.bottom) minus the FAB's own default
      // margin, so it sits a small gap above the bar.
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          // Clamped at 0: when this screen is shown standalone (e.g. in a
          // widget test) there's no glass nav, so padding.bottom is 0 and
          // the raw expression would go negative — an invalid EdgeInsets.
          bottom: (MediaQuery.of(context).padding.bottom -
                  kFloatingActionButtonMargin +
                  GlassBottomNav.contentGap)
              .clamp(0.0, double.infinity),
        ),
        // 40dp instead of the 56dp default: at 56 the button covered the
        // stock number of the last row. The icon stays deliberately large
        // (28 vs the 24 default) so the compact circle still reads as a
        // bold "+" rather than a small glyph adrift in empty space.
        child: SizedBox(
          width: _fabSize,
          height: _fabSize,
          child: FloatingActionButton(
            onPressed: _openAddForm,
            shape: const CircleBorder(),
            child: const Icon(Icons.add, size: 28),
          ),
        ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              key: const Key('produk_category_filter'),
              onTap: _openCategoryFilterPicker,
              borderRadius: BorderRadius.circular(AppDimensions.inputRadius),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: AppColors.gray100,
                  borderRadius: BorderRadius.circular(AppDimensions.inputRadius),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: AppTextStyles.bodyMedium,
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
          const SizedBox(width: AppSpacing.sm),
          Container(
            // TODO(ui-migration): no clean token — 40x40 tap target has no
            // size token; icon size 24 has no icon-size token either.
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.gray100,
              borderRadius: BorderRadius.circular(AppDimensions.inputRadius),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: const Key('produk_sort_button'),
                onTap: _toggleSort,
                borderRadius: BorderRadius.circular(AppDimensions.inputRadius),
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
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Text(
          message,
          textAlign: TextAlign.center,
          // TODO(ui-migration): no clean token — 16px at regular weight has
          // no AppTextStyles entry (subheading is 16/w700, which would
          // change the rendered weight). Kept as body scaled to 16, which
          // matches what the inline TextStyle(fontSize: 16) inherited.
          style: AppTextStyles.body.copyWith(fontSize: 16),
        ),
      ),
    );
  }

  /// Gutter between grid cards, and the screen inset on either side. The
  /// two are deliberately different: [AppSpacing.md] between cards and
  /// [AppSpacing.lg] at the edges, so the pair reads as a pair rather
  /// than as two things drifting toward the screen borders.
  /// Diameter of the add-FAB. Named because the bottom scroll padding
  /// has to clear it, not just the nav bar.
  static const double _fabSize = 40;

  static const double _gridGutter = AppSpacing.md;
  static const double _gridInset = AppSpacing.lg;
  static const int _gridColumns = 2;

  Widget _buildProductList() {
    final categoryNameById = {for (final category in _categories) category.id: category.name};
    final visible = _visibleProducts;

    // The card's height follows from its width, so it is computed once
    // here and handed to the delegate as a fixed extent rather than
    // guessed at through childAspectRatio — the photo band and the text
    // block below it then cannot disagree about how tall a cell is.
    final gridWidth = MediaQuery.of(context).size.width - _gridInset * 2;
    final cardWidth =
        (gridWidth - _gridGutter * (_gridColumns - 1)) / _gridColumns;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: _gridInset),
      sliver: SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _gridColumns,
          crossAxisSpacing: _gridGutter,
          mainAxisSpacing: _gridGutter,
          mainAxisExtent: ProductGridCard.extentFor(cardWidth),
        ),
        itemCount: visible.length,
        itemBuilder: (context, index) {
          final product = visible[index];
          final categoryId = product.categoryId;
          return ProductGridCard(
            product: product,
            categoryName:
                categoryId == null ? 'Lainnya' : (categoryNameById[categoryId] ?? '-'),
            onTap: () => _openDetail(product),
          );
        },
      ),
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
