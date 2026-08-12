import 'dart:async';

import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';
import 'package:sliver_tools/sliver_tools.dart';

import '../../../data/models/app_settings.dart';
import '../../../data/models/product.dart';
import '../../../data/models/stock_mutation.dart';
import '../../../data/repositories/app_settings_repository.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/stock_mutation_repository.dart';
import '../../../domain/prioritas_kulakan_calculator.dart';
import '../../navigation/keyboard_safe_push.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_search_bar.dart';
import '../../widgets/category_tree_picker.dart';
import '../../widgets/frequently_sold_chart.dart';
import '../../widgets/frequently_sold_list_item.dart';
import '../produk/product_detail_screen.dart';

/// Full "Sering Keluar" list, opened from Beranda's "Lihat Semua". Every
/// non-archived product with at least one real stockOut mutation
/// (dailyVelocity > 0), ranked by sales frequency — independent of
/// current stock, so an out-of-stock top seller still shows up here. See
/// [FrequentlySoldListItem] for how each row explains that.
class FrequentlySoldScreen extends StatefulWidget {
  const FrequentlySoldScreen({super.key, required this.isar});

  final Isar isar;

  @override
  State<FrequentlySoldScreen> createState() => _FrequentlySoldScreenState();
}

class _FrequentlySoldScreenState extends State<FrequentlySoldScreen> {
  late final StockMutationRepository _mutationRepository = StockMutationRepository(widget.isar);
  late final AppSettingsRepository _settingsRepository = AppSettingsRepository(widget.isar);
  late final ProductRepository _productRepository = ProductRepository(
    widget.isar,
    _mutationRepository,
    _settingsRepository,
  );
  static const _calculator = PrioritasKulakanCalculator();

  /// Cap on the "Lihat Semua" list in its default view — see
  /// [_isDefaultView]. The chart above it always caps separately at 7
  /// (its own `maxBars` default), regardless of this limit.
  static const _listLimit = 20;

  final TextEditingController _searchController = TextEditingController();

  List<PrioritasKulakanResult> _results = [];
  CategorySelection _selection = const CategorySelection.all();
  String _searchQuery = '';
  bool _loading = true;

  StreamSubscription<void>? _productsSubscription;
  StreamSubscription<void>? _mutationsSubscription;
  StreamSubscription<void>? _settingsSubscription;

  @override
  void initState() {
    super.initState();
    _load();
    _productsSubscription = widget.isar.products.watchLazy().listen((_) => _load());
    _mutationsSubscription = widget.isar.stockMutations.watchLazy().listen((_) => _load());
    _settingsSubscription = widget.isar.appSettings.watchLazy().listen((_) => _load());
  }

  @override
  void dispose() {
    _productsSubscription?.cancel();
    _mutationsSubscription?.cancel();
    _settingsSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final settings = await _settingsRepository.get();

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

    final stockOutByProduct = <int, List<StockMutation>>{};
    for (final product in products) {
      stockOutByProduct[product.id] =
          await _mutationRepository.getStockOutHistoryForProduct(product.id);
    }

    final results = _calculator.calculateAll(
      products: products,
      stockOutMutationsByProductId: stockOutByProduct,
      restockLeadTimeDays: settings.restockLeadTimeDays,
      restockCoverDays: settings.restockCoverDays,
    );

    if (!mounted) return;
    setState(() {
      _results = sortFrequentlySold(results);
      _loading = false;
    });
  }

  List<PrioritasKulakanResult> get _visibleResults =>
      filterFrequentlySold(results: _results, searchQuery: _searchQuery);

  /// True when there's no active search or category narrowing — the
  /// state in which [_listLimit] applies. Once the user searches or picks
  /// a specific category, they've already narrowed the results
  /// themselves, so capping further would hide matches they asked for.
  bool get _isDefaultView => _searchQuery.trim().isEmpty && _selection.isAll;

  /// What [_buildList] actually renders: [_visibleResults] capped to
  /// [_listLimit] in the default (no search, no category filter) view.
  List<PrioritasKulakanResult> get _displayedListResults {
    final visible = _visibleResults;
    if (_isDefaultView && visible.length > _listLimit) {
      return visible.take(_listLimit).toList();
    }
    return visible;
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
    _load();
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
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader.withBack(
        title: 'Sering Keluar',
        onBack: () => Navigator.of(context).pop(),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildCaption()),
          // Search and category filter stay pinned to the top as
          // everything below scrolls — [SliverPinnedHeader] sizes itself
          // to the child's natural height every build. The chart (up to 7
          // bars) is deliberately NOT part of this pinned block: with it
          // included, the sticky area could eat most of the viewport and
          // leave almost no room to see the list underneath.
          SliverPinnedHeader(child: _buildPinnedHeader()),
          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_visibleResults.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: _buildEmptyState())
          else ...[
            SliverToBoxAdapter(child: FrequentlySoldChart(results: _visibleResults)),
            const SliverToBoxAdapter(child: Divider(height: 1)),
            if (_buildListLimitCaption() case final caption?)
              SliverToBoxAdapter(child: caption),
            _buildList(),
            // Clears the Android system navigation bar so the last row
            // isn't cut off at the bottom of the scroll.
            SliverToBoxAdapter(
              child: SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPinnedHeader() {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSearchField(),
          _buildCategoryFilter(),
          // Marks the boundary between the pinned block and the scrolling
          // content beneath it — the one visual cue a non-technical user has
          // that content keeps going below the fold.
          const Divider(height: 1),
        ],
      ),
    );
  }

  Widget _buildCaption() {
    return Padding(
      key: const Key('frequently_sold_page_caption'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Text(
        'Barang yang paling sering terjual, dihitung dari riwayat stok '
        'keluar. Angka ini rata-rata penjualan, bukan sisa stok.',
        style: AppTextStyles.body.copyWith(color: Colors.grey[700]),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
      child: AppSearchBar(
        key: const Key('frequently_sold_search'),
        controller: _searchController,
        hintText: 'Cari produk...',
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: InkWell(
        key: const Key('frequently_sold_category_filter'),
        onTap: _openCategoryFilterPicker,
        borderRadius: BorderRadius.circular(10),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Kategori',
            labelStyle: AppTextStyles.body.copyWith(color: Colors.grey[600]),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.body,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.arrow_drop_down, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    // No sales history at all (in the selected category) is shown
    // distinctly from "search yielded nothing" — same distinction
    // ProdukScreen makes between its two empty-state messages.
    if (_results.isEmpty) {
      return Center(
        key: const Key('frequently_sold_empty_state'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Belum ada riwayat penjualan',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Catat mutasi stok keluar di Tab Mutasi untuk mulai melacak '
                'barang yang sering terjual.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      key: const Key('frequently_sold_no_match_state'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Tidak ditemukan.',
          textAlign: TextAlign.center,
          style: AppTextStyles.body.copyWith(color: Colors.grey[700]),
        ),
      ),
    );
  }

  /// Tells the user why the list stops at [_listLimit] instead of
  /// silently truncating — null when the cap isn't in effect (see
  /// [_displayedListResults]).
  Widget? _buildListLimitCaption() {
    final visible = _visibleResults;
    if (!_isDefaultView || visible.length <= _listLimit) return null;

    return Padding(
      key: const Key('frequently_sold_list_limit_caption'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Text(
        'Menampilkan $_listLimit dari ${visible.length} produk. '
        'Gunakan pencarian untuk melihat produk lainnya.',
        style: AppTextStyles.caption.copyWith(color: Colors.grey[600]),
      ),
    );
  }

  Widget _buildList() {
    final visible = _displayedListResults;
    return SliverList.builder(
      key: const Key('frequently_sold_full_list'),
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final result = visible[index];
        return Column(
          children: [
            FrequentlySoldListItem(
              result: result,
              onTap: () => _openDetail(result.product),
            ),
            if (index < visible.length - 1)
              const Divider(height: 1, thickness: 0.5),
          ],
        );
      },
    );
  }
}

/// "Sering Keluar" eligibility + ordering: products with dailyVelocity > 0
/// (a velocity-0 product isn't "sering keluar") sorted by dailyVelocity
/// descending, ties broken by product name ascending (case-insensitive)
/// for stable ordering.
List<PrioritasKulakanResult> sortFrequentlySold(List<PrioritasKulakanResult> results) {
  final eligible = results.where((result) => result.dailyVelocity > 0).toList();
  eligible.sort((a, b) {
    final velocityCompare = b.dailyVelocity.compareTo(a.dailyVelocity);
    if (velocityCompare != 0) return velocityCompare;
    return a.product.name.toLowerCase().compareTo(b.product.name.toLowerCase());
  });
  return eligible;
}

/// Same substring-match rule as ProdukScreen's `filterProducts`, applied
/// to already-computed [PrioritasKulakanResult]s.
List<PrioritasKulakanResult> filterFrequentlySold({
  required List<PrioritasKulakanResult> results,
  String searchQuery = '',
}) {
  final query = searchQuery.trim().toLowerCase();
  if (query.isEmpty) return results;

  return results.where((result) {
    final product = result.product;
    final nameMatch = product.name.toLowerCase().contains(query);
    final codeMatch = (product.code ?? '').toLowerCase().contains(query);
    return nameMatch || codeMatch;
  }).toList();
}
