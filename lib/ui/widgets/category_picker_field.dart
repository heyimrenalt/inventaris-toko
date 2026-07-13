import 'dart:async';

import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';

import '../../data/models/category.dart';
import '../../data/repositories/category_repository.dart';
import 'category_tree_picker.dart';

/// Tappable field showing the product's assigned category as a full
/// "Parent > Child" breadcrumb (or "Lainnya (tanpa kategori)" when
/// unassigned), opening [CategoryTreePicker] on tap to change it.
///
/// Category assignment is optional, so there is always a valid selection
/// — [errorText] exists only for the rare case a previously-selected
/// category no longer exists (e.g. deleted from another screen while
/// this form was open), not for "nothing picked yet".
class CategoryPickerField extends StatefulWidget {
  const CategoryPickerField({
    super.key,
    required this.isar,
    required this.selectedCategoryId,
    required this.onChanged,
    this.errorText,
  });

  final Isar isar;
  final int? selectedCategoryId;
  final ValueChanged<int?> onChanged;
  final String? errorText;

  @override
  State<CategoryPickerField> createState() => _CategoryPickerFieldState();
}

class _CategoryPickerFieldState extends State<CategoryPickerField> {
  late final CategoryRepository _repository = CategoryRepository(widget.isar);

  List<Category> _categories = [];
  bool _loading = true;

  StreamSubscription<void>? _categoriesSubscription;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    // This field is embedded in ProductFormScreen, which stays mounted
    // while the user fills out the rest of the form — a category added
    // from Kelola Kategori (Pengaturan tab, a separately-mounted screen)
    // needs to reach this field's breadcrumb resolution without a
    // manual reload or app restart.
    _categoriesSubscription = widget.isar.categories.watchLazy().listen((_) => _loadCategories());
  }

  @override
  void dispose() {
    _categoriesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final categories = await _repository.getAll();
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _loading = false;
    });
  }

  String _breadcrumbFor(int categoryId) {
    final byId = {for (final category in _categories) category.id: category};
    final category = byId[categoryId];
    if (category == null) return 'Lainnya (tanpa kategori)';

    final parts = [category.name];
    var current = category;
    while (current.parentId != null) {
      final parent = byId[current.parentId];
      if (parent == null) break;
      parts.insert(0, parent.name);
      current = parent;
    }
    return parts.join(' > ');
  }

  Future<void> _openPicker() async {
    final selectedId = widget.selectedCategoryId;
    final current = selectedId == null
        ? const CategorySelection.uncategorized()
        : CategorySelection.category(selectedId, _breadcrumbFor(selectedId));

    final result = await showCategoryTreePicker(
      context: context,
      isar: widget.isar,
      includeAllOption: false,
      current: current,
    );
    if (result == null) return;
    widget.onChanged(result.categoryId);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 56,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final selectedId = widget.selectedCategoryId;
    final label = selectedId == null ? 'Lainnya (tanpa kategori)' : _breadcrumbFor(selectedId);

    return InkWell(
      key: const Key('category_picker_field'),
      onTap: _openPicker,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Kategori',
          errorText: widget.errorText,
        ),
        child: Text(label, style: const TextStyle(fontSize: 16, color: Colors.black87)),
      ),
    );
  }
}
