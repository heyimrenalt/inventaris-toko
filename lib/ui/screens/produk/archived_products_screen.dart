import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';

import '../../../data/models/category.dart';
import '../../../data/models/product.dart';
import '../../../data/repositories/app_settings_repository.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/stock_mutation_repository.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_snack.dart';

class ArchivedProductsScreen extends StatefulWidget {
  const ArchivedProductsScreen({super.key, required this.isar});

  final Isar isar;

  @override
  State<ArchivedProductsScreen> createState() => _ArchivedProductsScreenState();
}

class _ArchivedProductsScreenState extends State<ArchivedProductsScreen> {
  late final ProductRepository _productRepository = ProductRepository(
    widget.isar,
    StockMutationRepository(widget.isar),
    AppSettingsRepository(widget.isar),
  );
  late final CategoryRepository _categoryRepository = CategoryRepository(widget.isar);

  List<Product> _products = [];
  List<Category> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final products = await _productRepository.getArchived();
    final categories = await _categoryRepository.getAll();
    if (!mounted) return;
    setState(() {
      _products = products;
      _categories = categories;
      _loading = false;
    });
  }

  Future<void> _restore(Product product) async {
    await _productRepository.unarchive(product.id);
    if (!mounted) return;
    AppSnack.success(context, 'Produk dipulihkan');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader.withBack(
        title: 'Produk Diarsipkan',
        onBack: () => Navigator.of(context).pop(),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? _buildEmptyState()
              : _buildList(context),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Belum ada produk yang diarsipkan.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final categoryNameById = {for (final category in _categories) category.id: category.name};

    return ListView.separated(
      // Bottom inset clears the Android system nav bar so the last row
      // isn't cut off.
      padding: EdgeInsets.only(
        top: 8,
        bottom: 8 + MediaQuery.of(context).padding.bottom,
      ),
      itemCount: _products.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final product = _products[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.categoryId == null
                          ? 'Lainnya'
                          : (categoryNameById[product.categoryId] ?? '-'),
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Diarsipkan pada ${_formatDate(product.archivedAt)}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
                onPressed: () => _restore(product),
                icon: const Icon(Icons.unarchive_outlined),
                label: const Text('Pulihkan', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _formatDate(DateTime? date) {
  if (date == null) return '-';
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}
