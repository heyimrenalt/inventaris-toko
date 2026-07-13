import 'dart:async';

import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prioritas Kulakan')),
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
                    return PriorityProductCard(
                      result: result,
                      onTap: () => _openDetail(result.product),
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
