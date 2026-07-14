import 'dart:async';

import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';

import '../../../data/models/product.dart';
import '../../../data/models/stock_mutation.dart';
import '../../../data/repositories/app_settings_repository.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/stock_mutation_repository.dart';
import '../../../domain/prioritas_kulakan_calculator.dart';
import '../../widgets/frequently_sold_card.dart';
import '../../widgets/priority_product_card.dart';
import '../../widgets/product_search_bar.dart';
import '../produk/product_detail_screen.dart';
import 'prioritas_kulakan_screen.dart';

class BerandaScreen extends StatefulWidget {
  const BerandaScreen({super.key, required this.isar});

  final Isar isar;

  @override
  State<BerandaScreen> createState() => _BerandaScreenState();
}

class _BerandaScreenState extends State<BerandaScreen> {
  late final StockMutationRepository _mutationRepository = StockMutationRepository(widget.isar);
  late final ProductRepository _productRepository = ProductRepository(
    widget.isar,
    _mutationRepository,
    AppSettingsRepository(widget.isar),
  );
  static const _calculator = PrioritasKulakanCalculator();
  static const int _previewCount = 5;

  int _totalProducts = 0;
  List<PrioritasKulakanResult> _priorityResults = [];
  List<PrioritasKulakanResult> _frequentlySoldResults = [];
  bool _loading = true;

  StreamSubscription<void>? _productsSubscription;
  StreamSubscription<void>? _mutationsSubscription;

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
  }

  @override
  void dispose() {
    _productsSubscription?.cancel();
    _mutationsSubscription?.cancel();
    super.dispose();
  }

  /// Archived products are excluded from every part of this screen (the
  /// count, the priority calculation, and — via [ProductRepository]
  /// already excluding them internally — search) per this task's
  /// requirement to treat them as if they don't exist here.
  Future<void> _load() async {
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
    );

    // Same eligible results as the priority list, just re-sorted by raw
    // sales frequency instead of urgency — a product can be a top seller
    // while still being well stocked, which "Prioritas Kulakan" alone
    // wouldn't surface.
    final byVelocity = results.toList()
      ..sort((a, b) => b.dailyVelocity.compareTo(a.dailyVelocity));

    if (!mounted) return;
    setState(() {
      _totalProducts = products.length;
      _priorityResults = results;
      _frequentlySoldResults = byVelocity.take(_previewCount).toList();
      _loading = false;
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Beranda')),
      // One scrollable body (not a Column with a fixed-size search
      // header + Expanded content) so nothing overflows when the search
      // dropdown or the keyboard grows — same reasoning as
      // MutasiScreen/ProdukScreen's body.
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ProductSearchBar(
                  productRepository: _productRepository,
                  onProductSelected: _openDetail,
                ),
                const SizedBox(height: 16),
                _buildSummaryCards(),
                const SizedBox(height: 24),
                _buildPrioritasKulakanSection(),
                if (_frequentlySoldResults.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildFrequentlySoldSection(),
                ],
              ],
            ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            key: const Key('beranda_summary_total_produk'),
            label: 'Total Produk',
            value: _totalProducts,
            color: Colors.blue[700]!,
            icon: Icons.inventory_2_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            key: const Key('beranda_summary_perlu_kulakan'),
            label: 'Perlu Kulakan',
            value: _perluKulakanCount,
            color: Colors.orange[800]!,
            icon: Icons.priority_high,
          ),
        ),
      ],
    );
  }

  Widget _buildPrioritasKulakanSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Prioritas Kulakan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (_priorityResults.isNotEmpty)
              TextButton(
                key: const Key('beranda_lihat_semua_button'),
                onPressed: _openPrioritasKulakan,
                child: const Text('Lihat semua', style: TextStyle(fontSize: 14)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_priorityResults.isEmpty)
          Padding(
            key: const Key('beranda_priority_empty_state'),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Belum ada data penjualan untuk dihitung. Catat beberapa mutasi '
              'stok keluar dulu.',
              style: TextStyle(fontSize: 15, color: Colors.grey[700]),
            ),
          )
        else
          SizedBox(
            key: const Key('beranda_priority_preview_list'),
            height: 130,
            child: ListView.separated(
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
        const Text(
          'Sering keluar',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SizedBox(
          key: const Key('beranda_frequently_sold_list'),
          height: 130,
          child: ListView.separated(
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final int value;
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
            '$value',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
