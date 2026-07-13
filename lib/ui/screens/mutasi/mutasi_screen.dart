import 'dart:async';

import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';

import '../../../data/models/product.dart';
import '../../../data/models/stock_mutation.dart';
import '../../../data/repositories/app_settings_repository.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/stock_mutation_repository.dart';
import '../../widgets/date_range_filter.dart';
import '../../widgets/day_grouped_mutations.dart';
import '../../widgets/mutation_list_item.dart';
import 'catat_mutasi_screen.dart';

class MutasiScreen extends StatefulWidget {
  const MutasiScreen({super.key, required this.isar});

  final Isar isar;

  @override
  State<MutasiScreen> createState() => _MutasiScreenState();
}

class _MutasiScreenState extends State<MutasiScreen> {
  late final StockMutationRepository _mutationRepository = StockMutationRepository(widget.isar);
  late final ProductRepository _productRepository = ProductRepository(
    widget.isar,
    _mutationRepository,
    AppSettingsRepository(widget.isar),
  );

  final TextEditingController _searchController = TextEditingController();

  List<StockMutation> _allMutations = [];
  Map<int, Product> _productById = {};
  StockMutationTotals _totals = const StockMutationTotals(stockIn: 0, stockOut: 0);
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
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final mutations = await _mutationRepository.getAllMutations();
    final totals = await _mutationRepository.getTotalsSince(
      DateTime.now().subtract(const Duration(days: 7)),
    );
    // includeArchived so mutation history for an archived product still
    // shows a real product name instead of falling back to "-".
    final products = await _productRepository.getAll(includeArchived: true);
    if (!mounted) return;
    setState(() {
      _allMutations = mutations;
      _totals = totals;
      _productById = {for (final product in products) product.id: product};
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

  Future<void> _openCatat() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CatatMutasiScreen(isar: widget.isar)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mutasi')),
      // The whole body is one scrollable ListView (not a Column with a
      // fixed-size header + Expanded list) specifically so nothing can
      // ever overflow when the on-screen keyboard opens for the search
      // field: a Column's fixed-height children (summary card, search
      // field, filter bar) don't shrink, and when the keyboard eats
      // enough vertical space the Expanded list was pushed to used to
      // report a bottom overflow. A single ListView just scrolls
      // instead, regardless of how much space the keyboard takes.
      body: _loading ? const Center(child: CircularProgressIndicator()) : _buildBody(),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _openCatat,
              icon: const Icon(Icons.add),
              label: const Text('Catat', style: TextStyle(fontSize: 16)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _SummaryTile(
              key: const Key('mutasi_summary_in'),
              label: 'Stok masuk (7 hari)',
              value: _totals.stockIn,
              color: Colors.green[700]!,
              icon: Icons.arrow_upward,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryTile(
              key: const Key('mutasi_summary_out'),
              label: 'Stok keluar (7 hari)',
              value: _totals.stockOut,
              color: Colors.red[700]!,
              icon: Icons.arrow_downward,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        key: const Key('mutasi_search'),
        controller: _searchController,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          labelText: 'Cari produk atau catatan',
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

  Widget _buildFilterBar() {
    final now = DateTime.now();
    return DateRangeFilterBar(
      selectedRange: _selectedRange,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      onChanged: (range) => setState(() => _selectedRange = range),
    );
  }

  /// Everything — summary card, search field, filter bar, and the
  /// (possibly day-grouped) history — as children of one ListView, so
  /// the whole screen scrolls as a unit instead of relying on a fixed
  /// header + a separately-scrolling Expanded list (see the comment on
  /// `body:` in build() for why that split caused a keyboard overflow).
  Widget _buildBody() {
    final hasAnyMutations = _allMutations.isNotEmpty;
    final visible = hasAnyMutations ? _visibleMutations : const <StockMutation>[];
    final grouped = groupMutationsByDay(visible);

    return ListView(
      children: [
        _buildSummaryCard(),
        const Divider(height: 1),
        if (hasAnyMutations) ...[
          _buildSearchField(),
          _buildFilterBar(),
          const Divider(height: 1),
        ],
        if (!hasAnyMutations)
          _buildMessage('Belum ada riwayat mutasi stok.')
        else if (visible.isEmpty)
          _buildMessage('Tidak ditemukan.')
        else
          // Already sorted newest-first by the repository, so grouping
          // by insertion order naturally keeps both the day groups and
          // each day's entries in newest-first order too.
          for (final entry in grouped.entries) ...[
            DayHeader(label: formatDayLabel(entry.key)),
            for (final mutation in entry.value)
              MutationListItem(
                mutation: mutation,
                productName: _productById[mutation.productId]?.name ?? '-',
                unit: _productById[mutation.productId]?.unit ?? '',
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

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final double value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            formatMutationQuantity(value),
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
