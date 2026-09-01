import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';

import '../../../data/models/product.dart';
import '../../../data/models/stock_mutation.dart';
import '../../../data/repositories/stock_mutation_repository.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_snack.dart';
import '../../widgets/date_range_filter.dart';
import '../../widgets/day_grouped_mutations.dart';
import '../../widgets/mutation_list_item.dart';

/// Full stock mutation history for a single product ("Lihat semua" from
/// Product Detail's recent-history preview).
class ProductMutationHistoryScreen extends StatefulWidget {
  const ProductMutationHistoryScreen({super.key, required this.isar, required this.product});

  final Isar isar;
  final Product product;

  @override
  State<ProductMutationHistoryScreen> createState() => _ProductMutationHistoryScreenState();
}

class _ProductMutationHistoryScreenState extends State<ProductMutationHistoryScreen> {
  late final StockMutationRepository _mutationRepository = StockMutationRepository(widget.isar);

  List<StockMutation> _mutations = [];
  int? _mostRecentMutationId;
  bool _loading = true;

  /// Default newest-first (matches the Mutasi tab); the toggle flips to
  /// oldest-first.
  bool _newestFirst = true;

  /// Optional date-range narrowing, entered via the same manual
  /// DD/MM/YYYY [DateRangeFilterBar] used on the Mutasi tab.
  DateTimeRange? _selectedRange;

  /// Lower bound for [_selectedRange]'s fields: the oldest mutation in
  /// the whole ledger, resolved once when the screen opens. Ledger-wide
  /// rather than per-product on purpose — the same shared
  /// [DateRangeFilterBar] bound as the Mutasi tab, so the two screens
  /// accept exactly the same set of days.
  DateTime? _earliestMutationDate;

  @override
  void initState() {
    super.initState();
    _load();
    _loadEarliestMutationBound();
  }

  Future<void> _loadEarliestMutationBound() async {
    final earliest = await _mutationRepository.getEarliestMutationDate();
    if (!mounted) return;
    setState(() => _earliestMutationDate = earliest);
  }

  Future<void> _load() async {
    final mutations = await _mutationRepository.getHistoryForProduct(widget.product.id);
    final mostRecent = await _mutationRepository.getMostRecentMutationForProduct(widget.product.id);
    if (!mounted) return;
    setState(() {
      _mutations = mutations;
      _mostRecentMutationId = mostRecent?.id;
      _loading = false;
    });
  }

  /// [_mutations] (repository order = newest-first) narrowed by
  /// [_selectedRange] and re-ordered per [_newestFirst].
  List<StockMutation> get _visibleMutations {
    Iterable<StockMutation> result = _mutations;
    final range = _selectedRange;
    if (range != null) {
      final startInclusive = DateTime(range.start.year, range.start.month, range.start.day);
      final endExclusive =
          DateTime(range.end.year, range.end.month, range.end.day).add(const Duration(days: 1));
      result = result.where(
        (m) => !m.createdAt.isBefore(startInclusive) && m.createdAt.isBefore(endExclusive),
      );
    }
    final list = result.toList();
    list.sort((a, b) =>
        _newestFirst ? b.createdAt.compareTo(a.createdAt) : a.createdAt.compareTo(b.createdAt));
    return list;
  }

  /// Cancels immediately and offers an "Urungkan" action in the SnackBar
  /// instead of a pre-confirm dialog — same reversible pattern as the
  /// Mutasi tab. Stock re-adjusts on its own through the stockMutations
  /// watch stream on the Produk/Detail pages.
  Future<void> _cancelMutation(StockMutation mutation) async {
    final reversal = await _mutationRepository.undoMutation(mutation.id);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    AppSnack.action(
      context,
      message: 'Mutasi dibatalkan',
      actionLabel: 'Urungkan',
      duration: const Duration(seconds: 5),
      onAction: () async {
        await _mutationRepository.undoMutation(reversal.id);
        await _load();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader.withBack(
        title: 'Riwayat ${widget.product.name}',
        onBack: () => Navigator.of(context).pop(),
        trailing: _mutations.isEmpty
            ? null
            : IconButton(
                key: const Key('mutation_history_sort_toggle'),
                tooltip: _newestFirst ? 'Urut: Terbaru dulu' : 'Urut: Terlama dulu',
                icon: Icon(_newestFirst ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded),
                onPressed: () => setState(() => _newestFirst = !_newestFirst),
              ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _mutations.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Belum ada riwayat mutasi.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                )
              : _buildHistory(context),
    );
  }

  // Same day-group headers ("Hari ini" / "Kemarin" / absolute date) as the
  // Mutasi tab, via the shared groupMutationsByDay/formatDayLabel/DayHeader
  // in day_grouped_mutations.dart — kept identical on purpose so the two
  // screens never drift apart.
  Widget _buildHistory(BuildContext context) {
    final now = DateTime.now();
    final visible = _visibleMutations;
    final grouped = groupMutationsByDay(visible);

    return ListView(
      // Bottom inset clears the Android system nav bar so the last row
      // isn't cut off.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: DateRangeFilterBar(
            selectedRange: _selectedRange,
            // Empty ledger: today — an honest empty bound rather than an
            // invented one. See the note on [_earliestMutationDate].
            firstDate: _earliestMutationDate ?? now,
            lastDate: now,
            onChanged: (range) => setState(() => _selectedRange = range),
          ),
        ),
        const Divider(height: 0.5, thickness: 0.5),
        if (visible.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Tidak ada mutasi pada rentang tanggal ini.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          )
        else
          for (final entry in grouped.entries) ...[
            DayHeader(label: formatDayLabel(entry.key)),
            for (final mutation in entry.value)
              MutationListItem(
                mutation: mutation,
                productName: widget.product.name,
                unit: widget.product.unit,
                canCancel: _mostRecentMutationId == mutation.id,
                onCancel: () => _cancelMutation(mutation),
              ),
          ],
      ],
    );
  }
}
