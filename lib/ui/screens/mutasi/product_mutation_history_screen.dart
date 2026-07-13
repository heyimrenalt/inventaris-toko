import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';

import '../../../data/models/product.dart';
import '../../../data/models/stock_mutation.dart';
import '../../../data/repositories/stock_mutation_repository.dart';
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final mutations = await _mutationRepository.getHistoryForProduct(widget.product.id);
    if (!mounted) return;
    setState(() {
      _mutations = mutations;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Riwayat ${widget.product.name}')),
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
              : _buildHistory(),
    );
  }

  // Same day-group headers ("Hari ini" / "Kemarin" / absolute date) as the
  // Mutasi tab, via the shared groupMutationsByDay/formatDayLabel/DayHeader
  // in day_grouped_mutations.dart — kept identical on purpose so the two
  // screens never drift apart.
  Widget _buildHistory() {
    final grouped = groupMutationsByDay(_mutations);

    return ListView(
      children: [
        // Already sorted newest-first by the repository, so grouping by
        // insertion order naturally keeps both the day groups and each
        // day's entries in newest-first order too.
        for (final entry in grouped.entries) ...[
          DayHeader(label: formatDayLabel(entry.key)),
          for (final mutation in entry.value)
            MutationListItem(
              mutation: mutation,
              productName: widget.product.name,
              unit: widget.product.unit,
            ),
        ],
      ],
    );
  }
}
