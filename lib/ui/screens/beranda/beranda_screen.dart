import 'dart:async';
import 'package:intl/intl.dart';

import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';

import '../../../data/models/app_settings.dart';
import '../../../data/models/product.dart';
import '../../../data/models/stock_mutation.dart';
import '../../../data/repositories/app_settings_repository.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/stock_mutation_repository.dart';
import '../../../domain/prioritas_kulakan_calculator.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_header.dart';
import '../../widgets/frequently_sold_card.dart';
import '../../widgets/priority_product_card.dart';
import '../../widgets/product_search_bar.dart';
import '../../widgets/section_header.dart';
import '../../widgets/stat_card.dart';
import '../produk/product_detail_screen.dart';
import 'frequently_sold_screen.dart';
import 'prioritas_kulakan_screen.dart';

class BerandaScreen extends StatefulWidget {
  const BerandaScreen({
    super.key,
    required this.isar,
    this.scrollController,
    this.mutationRepository,
    this.settingsRepository,
    this.productRepository,
  });

  final Isar isar;

  /// Owned by [MainScaffold] so a re-tap of the Beranda nav item (while
  /// already on this tab) can animate this screen's list back to the top
  /// without this screen needing to know about the nav bar at all.
  final ScrollController? scrollController;

  /// Test seams only — real callers always let these default to real
  /// repositories built from [isar]. Lets a widget test inject a
  /// call-counting fake to verify pull-to-refresh actually re-queries.
  final StockMutationRepository? mutationRepository;
  final AppSettingsRepository? settingsRepository;
  final ProductRepository? productRepository;

  @override
  State<BerandaScreen> createState() => _BerandaScreenState();
}

class _BerandaScreenState extends State<BerandaScreen> {
  late final StockMutationRepository _mutationRepository =
      widget.mutationRepository ?? StockMutationRepository(widget.isar);
  late final AppSettingsRepository _settingsRepository =
      widget.settingsRepository ?? AppSettingsRepository(widget.isar);
  late final ProductRepository _productRepository = widget.productRepository ??
      ProductRepository(
        widget.isar,
        _mutationRepository,
        _settingsRepository,
      );
  static const _calculator = PrioritasKulakanCalculator();
  static const int _previewCount = 5;

  int _totalProducts = 0;
  List<PrioritasKulakanResult> _priorityResults = [];
  List<PrioritasKulakanResult> _frequentlySoldResults = [];
  double _totalProfit = 0.0;
  bool _loading = true;

  StreamSubscription<void>? _productsSubscription;
  StreamSubscription<void>? _mutationsSubscription;
  StreamSubscription<void>? _settingsSubscription;

  @override
  void initState() {
    super.initState();
    _load();
    // MainScaffold keeps every tab alive in an IndexedStack, so this
    // screen's own initState only runs once — a stock mutation recorded
    // from Product Detail or the Mutasi tab (both separately-mounted
    // screens) changes both the product list and the priority
    // calculation without this tab ever reloading on its own. Same
    // watchLazy() pattern as MutasiScreen/ProdukScreen.
    _productsSubscription = widget.isar.products.watchLazy().listen((_) => _load());
    _mutationsSubscription = widget.isar.stockMutations.watchLazy().listen((_) => _load());
    // Editing restockLeadTimeDays/restockCoverDays in Pengaturan changes
    // this screen's urgency/quantity math even though no product or
    // mutation changed — without this, a settings edit wouldn't show up
    // here until some unrelated reload happened to fire.
    _settingsSubscription = widget.isar.appSettings.watchLazy().listen((_) => _load());
  }

  @override
  void dispose() {
    _productsSubscription?.cancel();
    _mutationsSubscription?.cancel();
    _settingsSubscription?.cancel();
    super.dispose();
  }

  /// Archived products are excluded from every part of this screen (the
  /// count, the priority calculation, and — via [ProductRepository]
  /// already excluding them internally — search) per this task's
  /// requirement to treat them as if they don't exist here.
  Future<void> _load() async {
    final settings = await _settingsRepository.get();
    final products = await _productRepository.getAll();

    // A small store's product catalog is small enough that one query per
    // product (rather than a single bulk query plus a manual group-by)
    // stays cheap — same reasoning MutasiScreen/ProdukScreen apply to
    // their own in-memory filtering.
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

    // Same eligible results as the priority list, just re-sorted by raw
    // sales frequency instead of urgency — a product can be a top seller
    // while still being well stocked, which "Prioritas Kulakan" alone
    // wouldn't surface.
    final byVelocity = results.toList()
      ..sort((a, b) => b.dailyVelocity.compareTo(a.dailyVelocity));

    final totalProfit = await _mutationRepository.calculateTotalProfit();

    if (!mounted) return;
    setState(() {
      _totalProducts = products.length;
      _priorityResults = results;
      _frequentlySoldResults = byVelocity.take(_previewCount).toList();
      _totalProfit = totalProfit;
      _loading = false;
    });
  }

  /// Wrapped with a minimum visible duration so a fast local Isar query
  /// doesn't make the RefreshIndicator flash and vanish — that would read
  /// as broken to a non-technical user pulling to refresh an offline app.
  Future<void> _handleRefresh() async {
    await Future.wait([
      _load(),
      Future<void>.delayed(const Duration(milliseconds: 300)),
    ]);
  }

  int get _perluKulakanCount =>
      _priorityResults.where((result) => result.urgency != PriorityUrgency.neutral).length;

  Future<void> _openDetail(Product product) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(isar: widget.isar, productId: product.id),
      ),
    );
    await _load();
  }

  void _openPrioritasKulakan() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PrioritasKulakanScreen(isar: widget.isar)),
    );
  }

  void _openFrequentlySold() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FrequentlySoldScreen(isar: widget.isar)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: const AppHeader(title: 'Beranda'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _handleRefresh,
              child: ListView(
                controller: widget.scrollController,
                // AlwaysScrollable so the pull-to-refresh gesture still
                // works even when the content is short enough to not
                // otherwise need scrolling (e.g. no priority/frequently
                // sold sections yet).
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  _buildSearchBar(),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildSummaryCards(),
                  ),
                  _buildPrioritasKulakanSection(),
                  if (_frequentlySoldResults.isNotEmpty) _buildFrequentlySoldSection(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  /// Wraps the shared [ProductSearchBar] with the elevated white card
  /// treatment the mockup gives Beranda's search field specifically — a
  /// local [Theme] override rather than a change to the shared widget, so
  /// its other embedding (Mutasi's batch stock-out screen) keeps its
  /// existing plain look.
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          boxShadow: AppDimensions.elevatedSearchShadow,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        // The search-results dropdown's ListTiles paint their background/ink
        // on the nearest Material ancestor — without this, that would be
        // whatever Scaffold-level Material sits behind this Container's own
        // painted background, which Flutter flags as unsafe (invisible ink).
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          child: Theme(
            data: Theme.of(context).copyWith(
              // Every border variant must be overridden explicitly — Material
              // only falls back to `border` for the *enabled* state; leaving
              // `focusedBorder` unset makes InputDecorator derive one that
              // tints the outline with the theme's primary color (a green
              // ring on focus), which is exactly the artifact this is
              // avoiding.
              //
              // `filled` is explicitly forced to false here — the app's
              // global inputDecorationTheme (app_theme.dart) sets
              // `filled: true, fillColor: gray100` for every other text field
              // in the app, and `copyWith` only overrides the fields listed
              // here, so simply omitting `filled` would silently inherit that
              // `true`. The white rounded pill is already fully painted by
              // this method's own Container below; a filled TextField on top
              // of it paints a *second*, unrounded background — a
              // sharp-cornered box peeking out from under the rounded pill at
              // all four corners.
              inputDecorationTheme: Theme.of(context).inputDecorationTheme.copyWith(
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                  ),
            ),
            child: ProductSearchBar(
              productRepository: _productRepository,
              onProductSelected: _openDetail,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Column(
      children: [
        // First row: Total Produk + Perlu Kulakan
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: StatCard(
                  key: const Key('beranda_summary_total_produk'),
                  label: 'Total Produk',
                  value: '$_totalProducts',
                  variant: StatCardVariant.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  key: const Key('beranda_summary_perlu_kulakan'),
                  label: 'Perlu Kulakan',
                  value: '$_perluKulakanCount',
                  variant: StatCardVariant.red,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Second row: Total Keuntungan (spans both columns, same width as top row)
        Row(
          children: [
            Expanded(
              child: StatCard(
                key: const Key('beranda_summary_total_keuntungan'),
                label: 'Total Keuntungan',
                value: _formatCurrency(_totalProfit),
                variant: StatCardVariant.yellow,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatCurrency(double value) {
    final formatter = NumberFormat('#,##0', 'id_ID');
    return 'Rp ${formatter.format(value.toInt())}';
  }

  Widget _buildPrioritasKulakanSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Prioritas Kulakan',
          actionLabel: _priorityResults.isNotEmpty ? 'Lihat semua' : null,
          actionKey: const Key('beranda_lihat_semua_button'),
          onActionTap: _openPrioritasKulakan,
        ),
        if (_priorityResults.isEmpty)
          Padding(
            key: const Key('beranda_priority_empty_state'),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              'Belum ada data penjualan untuk dihitung. Catat beberapa mutasi '
              'stok keluar dulu.',
              style: AppTextStyles.body.copyWith(color: AppColors.gray700),
            ),
          )
        else
          SizedBox(
            key: const Key('beranda_priority_preview_list'),
            height: 130,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _priorityResults.take(_previewCount).length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final result = _priorityResults[index];
                return PriorityProductCard(
                  result: result,
                  compact: true,
                  onTap: () => _openDetail(result.product),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildFrequentlySoldSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Sering keluar',
          actionLabel: 'Lihat semua',
          actionKey: const Key('beranda_frequently_sold_lihat_semua_button'),
          onActionTap: _openFrequentlySold,
        ),
        SizedBox(
          key: const Key('beranda_frequently_sold_list'),
          // Taller than the priority-preview list (130): this card has an
          // extra data-age/confidence caption line under the velocity
          // figure that the priority card doesn't, plus a StockBadge
          // (17px extrabold number chip) that needs more room than the
          // plain caption text it replaced. 180 (rather than a tighter fit)
          // leaves headroom for the velocity/data-age captions to each wrap
          // to their allowed 2 lines without clipping mid-word.
          height: 180,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: _frequentlySoldResults.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final result = _frequentlySoldResults[index];
              return FrequentlySoldCard(
                result: result,
                onTap: () => _openDetail(result.product),
              );
            },
          ),
        ),
      ],
    );
  }
}
