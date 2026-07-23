import 'dart:async';

import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';

import '../../../data/models/product.dart';
import '../../../data/models/stock_mutation.dart';
import '../../../data/repositories/app_settings_repository.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/stock_mutation_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../widgets/app_header.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/day_grouped_mutations.dart';
import '../../widgets/mutation_list_item.dart';
import '../../widgets/product_search_bar.dart';
import '../produk/product_detail_screen.dart';
import 'catat_mutasi_screen.dart';
import 'catat_stok_keluar_batch_screen.dart';

class MutasiScreen extends StatefulWidget {
  const MutasiScreen({
    super.key,
    required this.isar,
    this.scrollController,
    this.mutationRepository,
    this.productRepository,
  });

  final Isar isar;

  /// Owned by [MainScaffold] so a re-tap of the Mutasi nav item (while
  /// already on this tab) can animate this screen's list back to the top
  /// without this screen needing to know about the nav bar at all.
  final ScrollController? scrollController;

  /// Test seams only — real callers always let these default to real
  /// repositories built from [isar]. Lets a widget test inject a
  /// call-counting fake to verify pull-to-refresh actually re-queries.
  final StockMutationRepository? mutationRepository;
  final ProductRepository? productRepository;

  @override
  State<MutasiScreen> createState() => _MutasiScreenState();
}

class _MutasiScreenState extends State<MutasiScreen> {
  late final StockMutationRepository _mutationRepository =
      widget.mutationRepository ?? StockMutationRepository(widget.isar);
  late final ProductRepository _productRepository = widget.productRepository ??
      ProductRepository(
        widget.isar,
        _mutationRepository,
        AppSettingsRepository(widget.isar),
      );

  List<StockMutation> _allMutations = [];
  Map<int, Product> _productById = {};
  Map<int, int> _mostRecentMutationIdByProduct = {};
  DateTimeRange? _selectedRange;
  String _searchQuery = '';
  bool _loading = true;

  StreamSubscription<void>? _mutationsSubscription;

  @override
  void initState() {
    super.initState();
    _load();
    // MainScaffold keeps every tab alive in an IndexedStack, so this
    // screen's own initState only runs once — recording a mutation from
    // Product Detail's buttons (a different, separately-mounted screen)
    // was silently not reflected here until something else happened to
    // call _load() again. watchLazy() fires whenever the stockMutations
    // collection changes anywhere in the app, regardless of which screen
    // caused it, so this stays correct without every screen needing its
    // own manually-triggered refresh call. The Produk list and Product
    // Detail screens use the same pattern for the same reason.
    _mutationsSubscription = widget.isar.stockMutations.watchLazy().listen((_) => _load());
  }

  @override
  void dispose() {
    _mutationsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final mutations = await _mutationRepository.getAllMutations();
    final products = await _productRepository.getAll(includeArchived: true);

    final distinctProductIds = mutations.map((m) => m.productId).toSet();
    final mostRecentByProduct = <int, int>{};
    for (final productId in distinctProductIds) {
      final recent = await _mutationRepository.getMostRecentMutationForProduct(productId);
      if (recent != null) mostRecentByProduct[productId] = recent.id;
    }

    if (!mounted) return;
    setState(() {
      _allMutations = mutations;
      _productById = {for (final product in products) product.id: product};
      _mostRecentMutationIdByProduct = mostRecentByProduct;
      _loading = false;
    });
  }

  /// [_allMutations] filtered by the active date range and/or search
  /// query. Recomputed on every build rather than cached — the app's
  /// expected data scale (a small store's mutation history) makes
  /// in-memory filtering of the already-loaded list cheap, so there's no
  /// need for a separate repository query per filter combination.
  List<StockMutation> get _visibleMutations => filterMutations(
        mutations: _allMutations,
        productById: _productById,
        range: _selectedRange,
        searchQuery: _searchQuery,
      );

  /// Wrapped with a minimum visible duration so a fast local Isar query
  /// doesn't make the RefreshIndicator flash and vanish — that would read
  /// as broken to a non-technical user pulling to refresh an offline app.
  /// [_load] itself already re-reads the current [_selectedRange] and
  /// [_searchQuery] from state, so the active date filter and search term
  /// carry over automatically.
  Future<void> _handleRefresh() async {
    await Future.wait([
      _load(),
      Future<void>.delayed(const Duration(milliseconds: 300)),
    ]);
  }

  Future<void> _openCatat() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CatatMutasiScreen(isar: widget.isar)),
    );
  }

  Future<void> _openBatch() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CatatStokKeluarBatchScreen(isar: widget.isar)),
    );
  }

  Future<void> _cancelMutation(StockMutation mutation) async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Batalkan Mutasi',
      message: 'Batalkan mutasi ini? Ini akan membuat entri pembalik di riwayat.',
      confirmLabel: 'Ya, Batalkan',
      isDestructive: true,
    );
    if (confirmed != true) return;
    if (!mounted) return;

    await _mutationRepository.undoMutation(mutation.id);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Mutasi dibatalkan'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(title: 'Mutasi stok'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _handleRefresh, child: _buildBody()),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _openCatat,
                    icon: const Icon(Icons.add),
                    label: const Text('Stok masuk', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00AA0D),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _openBatch,
                    icon: const Icon(Icons.remove),
                    label: const Text('Stok keluar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD32F2F),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          boxShadow: AppDimensions.elevatedSearchShadow,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          child: Theme(
            data: Theme.of(context).copyWith(
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
              onProductSelected: (product) => _openDetail(product),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    final now = DateTime.now();
    final start = _selectedRange?.start ?? now.subtract(const Duration(days: 7));
    final end = _selectedRange?.end ?? now;
    final dateLabel =
        '${start.day} ${_monthName(start.month)} — ${end.day} ${_monthName(end.month)} ${end.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                showDateRangePicker(
                  context: context,
                  firstDate: DateTime(now.year - 2),
                  lastDate: now,
                  initialDateRange: _selectedRange,
                ).then((range) {
                  if (range != null) {
                    setState(() => _selectedRange = range);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        dateLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1C1C1C),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.expand_more, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDetail(Product product) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(isar: widget.isar, productId: product.id),
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des'
    ];
    return months[month - 1];
  }

  Widget _buildBody() {
    final hasAnyMutations = _allMutations.isNotEmpty;
    final visible = hasAnyMutations ? _visibleMutations : const <StockMutation>[];
    final grouped = groupMutationsByDay(visible);

    return ListView(
      controller: widget.scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (hasAnyMutations) ...[
          _buildSearchBar(),
          const SizedBox(height: 12),
          _buildFilterBar(),
          const Divider(height: 0.5, thickness: 0.5),
        ],
        if (!hasAnyMutations)
          _buildMessage('Belum ada riwayat mutasi stok.')
        else if (visible.isEmpty)
          _buildMessage('Tidak ditemukan.')
        else
          for (final entry in grouped.entries) ...[
            DayHeader(label: formatDayLabel(entry.key)),
            for (final mutation in entry.value)
              MutationListItem(
                mutation: mutation,
                productName: _productById[mutation.productId]?.name ?? '-',
                unit: _productById[mutation.productId]?.unit ?? '',
                canCancel: _mostRecentMutationIdByProduct[mutation.productId] == mutation.id,
                onCancel: () => _cancelMutation(mutation),
              ),
          ],
      ],
    );
  }

  Widget _buildMessage(String message) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16),
      ),
    );
  }
}

/// Pure filtering logic, extracted so it's directly unit-testable without
/// needing to drive Flutter's real (fiddly to automate) date-range-picker
/// calendar UI for every edge case — only the end-to-end wiring needs a
/// real widget test; the filtering rules themselves don't.
List<StockMutation> filterMutations({
  required List<StockMutation> mutations,
  required Map<int, Product> productById,
  DateTimeRange? range,
  String searchQuery = '',
}) {
  Iterable<StockMutation> result = mutations;

  if (range != null) {
    final startInclusive = DateTime(range.start.year, range.start.month, range.start.day);
    final endExclusive =
        DateTime(range.end.year, range.end.month, range.end.day).add(const Duration(days: 1));
    result = result.where(
      (mutation) =>
          !mutation.createdAt.isBefore(startInclusive) &&
          mutation.createdAt.isBefore(endExclusive),
    );
  }

  final query = searchQuery.trim().toLowerCase();
  if (query.isNotEmpty) {
    result = result.where((mutation) {
      final productName = productById[mutation.productId]?.name.toLowerCase() ?? '';
      final note = (mutation.note ?? '').toLowerCase();
      return productName.contains(query) || note.contains(query);
    });
  }

  return result.toList();
}

