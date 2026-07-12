import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';

import '../../data/models/category.dart';
import '../../data/repositories/category_repository.dart';
import 'category_form_dialog.dart';

/// Dropdown of existing categories with an inline "add new category" item
/// that opens the shared category dialog without leaving the current
/// screen. On successful creation, the new category is auto-selected.
///
/// Selection is a controlled value owned by the parent (via
/// [selectedCategoryId]/[onChanged]); this widget only owns the category
/// *list*, since it needs to reload that after creating a new one.
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
  static const int _addNewSentinel = -1;

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

  Future<void> _handleAddNewCategory() async {
    final created = await showCategoryFormDialog(context: context, repository: _repository);
    if (created == null) return;
    await _loadCategories();
    widget.onChanged(created.id);
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
    final hasSelectedCategory = _categories.any((category) => category.id == selectedId);

    return DropdownButtonFormField<int>(
      initialValue: hasSelectedCategory ? selectedId : null,
      decoration: InputDecoration(
        labelText: 'Kategori',
        errorText: widget.errorText,
      ),
      style: const TextStyle(fontSize: 16, color: Colors.black87),
      items: [
        for (final category in _categories)
          DropdownMenuItem(value: category.id, child: Text(category.name)),
        const DropdownMenuItem(
          value: _addNewSentinel,
          child: Text(
            '+ Tambah kategori baru',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
      onChanged: (value) {
        if (value == _addNewSentinel) {
          _handleAddNewCategory();
        } else {
          widget.onChanged(value);
        }
      },
    );
  }
}
