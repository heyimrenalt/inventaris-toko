import 'dart:async';

import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';

import '../../data/models/category.dart';
import '../../data/repositories/category_repository.dart';
import 'category_form_dialog.dart';

enum _SelectionType { all, uncategorized, category }

/// What the user picked from a [CategoryTreePicker]: either "Semua" (all
/// products, filter-only), "Lainnya" (uncategorized), or a specific
/// category node (identified by [categoryId], with [breadcrumb] as its
/// full "Parent > Child" path for display).
class CategorySelection {
  const CategorySelection.all()
      : _type = _SelectionType.all,
        categoryId = null,
        breadcrumb = null;

  const CategorySelection.uncategorized()
      : _type = _SelectionType.uncategorized,
        categoryId = null,
        breadcrumb = null;

  const CategorySelection.category(int id, this.breadcrumb)
      : _type = _SelectionType.category,
        categoryId = id;

  final _SelectionType _type;
  final int? categoryId;
  final String? breadcrumb;

  bool get isAll => _type == _SelectionType.all;
  bool get isUncategorized => _type == _SelectionType.uncategorized;
  bool get isCategory => _type == _SelectionType.category;
}

/// Opens [CategoryTreePicker] as a scrollable modal bottom sheet and
/// returns the user's [CategorySelection], or `null` if dismissed without
/// picking one.
///
/// [includeAllOption] shows a fixed "Semua" row above the tree — used by
/// the Produk tab's filter (which has 3 states: all/category/none) but
/// not by the product form's category field (a product is always either
/// assigned or Lainnya, never "all categories").
Future<CategorySelection?> showCategoryTreePicker({
  required BuildContext context,
  required Isar isar,
  required bool includeAllOption,
  CategorySelection? current,
}) {
  return showModalBottomSheet<CategorySelection>(
    context: context,
    isScrollControlled: true,
    builder: (_) => CategoryTreePicker(
      isar: isar,
      includeAllOption: includeAllOption,
      current: current,
    ),
  );
}

class CategoryTreePicker extends StatefulWidget {
  const CategoryTreePicker({
    super.key,
    required this.isar,
    required this.includeAllOption,
    this.current,
  });

  final Isar isar;
  final bool includeAllOption;
  final CategorySelection? current;

  @override
  State<CategoryTreePicker> createState() => _CategoryTreePickerState();
}

class _CategoryTreePickerState extends State<CategoryTreePicker> {
  late final CategoryRepository _repository = CategoryRepository(widget.isar);

  List<Category> _categories = [];
  bool _loading = true;
  final Set<int> _expandedIds = {};

  StreamSubscription<void>? _categoriesSubscription;

  @override
  void initState() {
    super.initState();
    _load();
    // Lets a category added from elsewhere in the app (or via this
    // picker's own inline "add" dialogs, which reuse the same
    // repository) show up immediately without closing and reopening the
    // sheet.
    _categoriesSubscription = widget.isar.categories.watchLazy().listen((_) => _load());
  }

  @override
  void dispose() {
    _categoriesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final categories = await _repository.getAll();
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _loading = false;
    });
  }

  Map<int?, List<Category>> _groupByParent() {
    final map = <int?, List<Category>>{};
    for (final category in _categories) {
      map.putIfAbsent(category.parentId, () => []).add(category);
    }
    for (final siblings in map.values) {
      siblings.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return map;
  }

  String _breadcrumbFor(Category category) {
    final byId = {for (final c in _categories) c.id: c};
    final parts = <String>[category.name];
    var current = category;
    while (current.parentId != null) {
      final parent = byId[current.parentId];
      if (parent == null) break;
      parts.insert(0, parent.name);
      current = parent;
    }
    return parts.join(' > ');
  }

  void _select(CategorySelection selection) {
    Navigator.of(context).pop(selection);
  }

  Future<void> _addCategory({int? parentId}) async {
    final created = await showCategoryFormDialog(
      context: context,
      repository: _repository,
      parentId: parentId,
    );
    if (created == null) return;
    if (parentId != null) {
      setState(() => _expandedIds.add(parentId));
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) {
          if (_loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final childrenByParentId = _groupByParent();
          final roots = childrenByParentId[null] ?? const <Category>[];

          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  'Pilih Kategori',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              if (widget.includeAllOption)
                ListTile(
                  key: const Key('category_picker_all'),
                  title: const Text('Semua', style: TextStyle(fontSize: 16)),
                  selected: widget.current?.isAll ?? false,
                  onTap: () => _select(const CategorySelection.all()),
                ),
              ListTile(
                key: const Key('category_picker_uncategorized'),
                title: Text(
                  widget.includeAllOption ? 'Lainnya' : 'Lainnya (tanpa kategori)',
                  style: const TextStyle(fontSize: 16),
                ),
                selected: widget.current?.isUncategorized ?? false,
                onTap: () => _select(const CategorySelection.uncategorized()),
              ),
              const Divider(),
              if (roots.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Belum ada kategori.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ),
              for (final root in roots)
                _CategoryPickerNode(
                  category: root,
                  depth: 0,
                  childrenByParentId: childrenByParentId,
                  expandedIds: _expandedIds,
                  selectedCategoryId: widget.current?.categoryId,
                  onToggleExpand: (id) => setState(() {
                    if (!_expandedIds.add(id)) _expandedIds.remove(id);
                  }),
                  onSelect: (category) =>
                      _select(CategorySelection.category(category.id, _breadcrumbFor(category))),
                  onAddChild: (parent) => _addCategory(parentId: parent.id),
                ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: TextButton.icon(
                  key: const Key('category_picker_add_root'),
                  onPressed: () => _addCategory(),
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah kategori', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CategoryPickerNode extends StatelessWidget {
  const _CategoryPickerNode({
    required this.category,
    required this.depth,
    required this.childrenByParentId,
    required this.expandedIds,
    required this.selectedCategoryId,
    required this.onToggleExpand,
    required this.onSelect,
    required this.onAddChild,
  });

  final Category category;
  final int depth;
  final Map<int?, List<Category>> childrenByParentId;
  final Set<int> expandedIds;
  final int? selectedCategoryId;
  final ValueChanged<int> onToggleExpand;
  final ValueChanged<Category> onSelect;
  final ValueChanged<Category> onAddChild;

  @override
  Widget build(BuildContext context) {
    final children = childrenByParentId[category.id] ?? const <Category>[];
    final expanded = expandedIds.contains(category.id);
    final selected = category.id == selectedCategoryId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          key: Key('category_picker_node_${category.id}'),
          contentPadding: EdgeInsets.only(left: 16.0 + depth * 20, right: 4),
          selected: selected,
          leading: children.isEmpty
              ? const SizedBox(width: 32)
              : IconButton(
                  key: Key('category_picker_expand_${category.id}'),
                  icon: Icon(expanded ? Icons.expand_more : Icons.chevron_right),
                  onPressed: () => onToggleExpand(category.id),
                ),
          title: Text(category.name, style: const TextStyle(fontSize: 16)),
          onTap: () => onSelect(category),
          trailing: IconButton(
            key: Key('category_picker_add_child_${category.id}'),
            icon: const Icon(Icons.add, size: 20),
            tooltip: 'Tambah sub-kategori',
            onPressed: () => onAddChild(category),
          ),
        ),
        if (expanded)
          for (final child in children)
            _CategoryPickerNode(
              category: child,
              depth: depth + 1,
              childrenByParentId: childrenByParentId,
              expandedIds: expandedIds,
              selectedCategoryId: selectedCategoryId,
              onToggleExpand: onToggleExpand,
              onSelect: onSelect,
              onAddChild: onAddChild,
            ),
      ],
    );
  }
}
