import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar_community/isar.dart';
import 'package:share_plus/share_plus.dart';

import '../../../data/models/product.dart';
import '../../../data/models/stock_mutation.dart';
import '../../../data/repositories/app_settings_repository.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/stock_mutation_repository.dart';
import '../../../domain/prioritas_kulakan_calculator.dart';
import '../../widgets/priority_product_card.dart';
import '../produk/product_detail_screen.dart';

class PrioritasKulakanScreen extends StatefulWidget {
  const PrioritasKulakanScreen({super.key, required this.isar});

  final Isar isar;

  @override
  State<PrioritasKulakanScreen> createState() => _PrioritasKulakanScreenState();
}

class _PrioritasKulakanScreenState extends State<PrioritasKulakanScreen> {
  late final StockMutationRepository _mutationRepository = StockMutationRepository(widget.isar);
  late final ProductRepository _productRepository = ProductRepository(
    widget.isar,
    _mutationRepository,
    AppSettingsRepository(widget.isar),
  );
  static const _calculator = PrioritasKulakanCalculator();

  List<PrioritasKulakanResult> _results = [];
  bool _loading = true;

  /// Which products' checkboxes are currently ticked. Defaulted once per
  /// product the first time it's seen (see [_seenProductIds]) — red/yellow
  /// urgency starts checked, neutral starts unchecked — then left entirely
  /// to the user's own toggling from that point on, so a background
  /// [_load] triggered by an unrelated mutation elsewhere in the app never
  /// silently resets a choice the user already made on this screen.
  final Set<int> _checkedProductIds = {};
  final Set<int> _seenProductIds = {};

  StreamSubscription<void>? _productsSubscription;
  StreamSubscription<void>? _mutationsSubscription;

  @override
  void initState() {
    super.initState();
    _load();
    _productsSubscription = widget.isar.products.watchLazy().listen((_) => _load());
    _mutationsSubscription = widget.isar.stockMutations.watchLazy().listen((_) => _load());
  }

  @override
  void dispose() {
    _productsSubscription?.cancel();
    _mutationsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final products = await _productRepository.getAll();

    final stockOutByProduct = <int, List<StockMutation>>{};
    for (final product in products) {
      stockOutByProduct[product.id] =
          await _mutationRepository.getStockOutHistoryForProduct(product.id);
    }

    final results = _calculator.calculateAll(
      products: products,
      stockOutMutationsByProductId: stockOutByProduct,
    );

    for (final result in results) {
      if (_seenProductIds.add(result.product.id) && result.urgency != PriorityUrgency.neutral) {
        _checkedProductIds.add(result.product.id);
      }
    }

    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  Future<void> _openDetail(Product product) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(isar: widget.isar, productId: product.id),
      ),
    );
    await _load();
  }

  void _toggleChecked(int productId) {
    setState(() {
      if (!_checkedProductIds.remove(productId)) {
        _checkedProductIds.add(productId);
      }
    });
  }

  Future<void> _shareList() async {
    final text = buildKulakanShareText(results: _results, checkedProductIds: _checkedProductIds);
    await SharePlus.instance.share(ShareParams(text: text));
  }

  Future<void> _copyList() async {
    final text = buildKulakanShareText(results: _results, checkedProductIds: _checkedProductIds);
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Teks disalin ke clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCheckedItems = _checkedProductIds.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prioritas Kulakan'),
        actions: _results.isEmpty
            ? null
            : [
                IconButton(
                  key: const Key('kulakan_share_button'),
                  icon: const Icon(Icons.share),
                  tooltip: 'Bagikan daftar belanja',
                  onPressed: hasCheckedItems ? _shareList : null,
                ),
                IconButton(
                  key: const Key('kulakan_copy_button'),
                  icon: const Icon(Icons.copy),
                  tooltip: 'Salin teks',
                  onPressed: hasCheckedItems ? _copyList : null,
                ),
              ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  key: const Key('prioritas_kulakan_list'),
                  itemCount: _results.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final result = _results[index];
                    return Row(
                      children: [
                        Checkbox(
                          key: Key('kulakan_checkbox_${result.product.id}'),
                          value: _checkedProductIds.contains(result.product.id),
                          onChanged: (_) => _toggleChecked(result.product.id),
                        ),
                        Expanded(
                          child: PriorityProductCard(
                            result: result,
                            onTap: () => _openDetail(result.product),
                          ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      key: const Key('prioritas_kulakan_empty_state'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Belum ada data penjualan untuk dihitung. Catat beberapa mutasi '
          'stok keluar dulu.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey[700]),
        ),
      ),
    );
  }
}

const _shareMonths = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

/// Formatted shopping-list text for the currently-checked items only —
/// unchecked items are left out of both the shared text and the "Total"
/// count, so "Bagikan" and "Salin teks" never send the user's own
/// deliberately-unchecked items along by accident. Both actions call this
/// same function so they can never drift out of sync with each other. A
/// top-level function (not a private method) so it's directly
/// unit-testable without needing to drive the share sheet or clipboard.
String buildKulakanShareText({
  required List<PrioritasKulakanResult> results,
  required Set<int> checkedProductIds,
  DateTime? now,
}) {
  final checked = results.where((result) => checkedProductIds.contains(result.product.id)).toList();

  final buffer = StringBuffer()
    ..writeln('Daftar Belanja Kulakan')
    ..writeln('Toko Mama · ${_formatShareDate(now ?? DateTime.now())}')
    ..writeln('─────────────────────');
  for (final result in checked) {
    buffer.writeln(
      '✓ ${result.product.name} — ${result.suggestedRestockQty} ${result.product.unit}',
    );
  }
  buffer
    ..writeln('─────────────────────')
    ..writeln('Total: ${checked.length} barang')
    ..write('Dibuat dari aplikasi inventaris toko');

  return buffer.toString();
}

String _formatShareDate(DateTime date) => '${date.day} ${_shareMonths[date.month - 1]} ${date.year}';
