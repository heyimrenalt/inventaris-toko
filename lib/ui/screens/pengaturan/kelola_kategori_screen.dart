import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';

import '../../../data/models/category.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/repository_exceptions.dart';
import '../../widgets/category_form_dialog.dart';
import '../../widgets/confirm_dialog.dart';

class KelolaKategoriScreen extends StatefulWidget {
  const KelolaKategoriScreen({super.key, required this.isar});

  final Isar isar;

  @override
  State<KelolaKategoriScreen> createState() => _KelolaKategoriScreenState();
}

class _KelolaKategoriScreenState extends State<KelolaKategoriScreen> {
  late final CategoryRepository _repository = CategoryRepository(widget.isar);

  List<Category> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await _repository.getAll();
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _loading = false;
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showCategoryFormDialog({Category? existing}) async {
    final result = await showCategoryFormDialog(
      context: context,
      repository: _repository,
      existing: existing,
    );
    if (result == null) return;
    await _loadCategories();
    _showSnackBar(existing == null ? 'Kategori ditambahkan' : 'Kategori diperbarui');
  }

  Future<void> _confirmDelete(Category category) async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Hapus Kategori',
      message: "Hapus kategori '${category.name}'? Tindakan ini tidak bisa dibatalkan.",
      confirmLabel: 'Hapus',
      isDestructive: true,
    );
    if (confirmed != true) return;
    if (!mounted) return;

    try {
      await _repository.delete(category.id);
      await _loadCategories();
      _showSnackBar('Kategori dihapus');
    } on CategoryInUseException catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Tidak Bisa Dihapus', style: TextStyle(fontSize: 18)),
          content: Text(
            'Kategori ini masih dipakai oleh ${e.productCount} produk. '
            'Hapus atau pindahkan produk tersebut terlebih dahulu.',
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Kategori')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
              ? _buildEmptyState()
              : _buildCategoryList(),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => _showCategoryFormDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Kategori', style: TextStyle(fontSize: 16)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Belum ada kategori. Tambahkan kategori pertama untuk mulai.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildCategoryList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _categories.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final category = _categories[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  category.name,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
                onPressed: () => _showCategoryFormDialog(existing: category),
                icon: const Icon(Icons.edit),
                label: const Text('Ubah', style: TextStyle(fontSize: 16)),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  minimumSize: const Size(64, 48),
                  foregroundColor: Colors.red,
                ),
                onPressed: () => _confirmDelete(category),
                icon: const Icon(Icons.delete),
                label: const Text('Hapus', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        );
      },
    );
  }
}
