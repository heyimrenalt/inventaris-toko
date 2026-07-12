import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';

import '../../../data/models/category.dart';
import '../../../data/models/product.dart';
import '../../../data/repositories/app_settings_repository.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/stock_mutation_repository.dart';
import '../../widgets/product_list_item.dart';
import 'product_detail_screen.dart';
import 'product_form_screen.dart';

class ProdukScreen extends StatefulWidget {
  const ProdukScreen({super.key, required this.isar});

  final Isar isar;

  @override
  State<ProdukScreen> createState() => _ProdukScreenState();
}

class _ProdukScreenState extends State<ProdukScreen> {
  late final ProductRepository _productRepository = ProductRepository(
    widget.isar,
    StockMutationRepository(widget.isar),
    AppSettingsRepository(widget.isar),
  );
  late final CategoryRepository _categoryRepository = CategoryRepository(widget.isar);

  List<Product> _products = [];
  List<Category> _categories = [];
  int? _selectedCategoryId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final categories = await _categoryRepository.getAll();
    final categoryId = _selectedCategoryId;
    final products = categoryId == null
        ? await _productRepository.getAll()
        : await _productRepository.getByCategory(categoryId);
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _products = products;
      _loading = false;
    });
  }

  void _selectCategory(int? categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
      _loading = true;
    });
    _loadData();
  }

  Future<void> _openAddForm() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProductFormScreen(isar: widget.isar)),
    );
    await _loadData();
  }

  Future<void> _openDetail(Product product) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(isar: widget.isar, productId: product.id),
      ),
    );
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Produk')),
      body: Column(
        children: [
          _buildCategoryChips(),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                    ? _buildEmptyState()
                    : _buildProductList(),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _openAddForm,
              icon: const Icon(Icons.add),
              label: const Text('Tambah Produk', style: TextStyle(fontSize: 16)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: const Text('Semua', style: TextStyle(fontSize: 14)),
              selected: _selectedCategoryId == null,
              onSelected: (_) => _selectCategory(null),
            ),
          ),
          for (final category in _categories)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(category.name, style: const TextStyle(fontSize: 14)),
                selected: _selectedCategoryId == category.id,
                onSelected: (_) => _selectCategory(category.id),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          _selectedCategoryId == null
              ? 'Belum ada produk. Tambahkan produk pertama untuk mulai.'
              : 'Tidak ada produk pada kategori ini.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildProductList() {
    final categoryNameById = {for (final category in _categories) category.id: category.name};

    return ListView.separated(
      itemCount: _products.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final product = _products[index];
        return ProductListItem(
          product: product,
          categoryName: categoryNameById[product.categoryId] ?? '-',
          onTap: () => _openDetail(product),
        );
      },
    );
  }
}
