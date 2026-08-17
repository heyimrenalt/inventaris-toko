import 'dart:async';

import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';

import '../../data/models/category.dart';
import '../../data/repositories/category_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'category_form_dialog.dart';

enum _SelectionType { all, uncategorized, category }

/// Leading gutter width for special picker rows ("Semua" / "Lainnya" —
/// see [_SpecialPickerRow]) that must align with the chevron slot inside
/// [_CategoryPickerNode]. Deliberately off the spacing scale: if you
/// change one site, change both, or the tree rows stop lining up.
const double _kLeadingGutterWidth = 28.0;

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

/// Opens [CategoryTreePicker] as a modal bottom sheet and returns the
/// user's [CategorySelection], or `null` if dismissed without picking one.
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
    backgroundColor: Colors.transparent,
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
    final childrenByParentId = _groupByParent();
    final roots = childrenByParentId[null] ?? const <Category>[];

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.cardRadius)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.gray300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Pilih Kategori', style: AppTextStyles.heading),
              ),
            ),
            Flexible(
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(AppSpacing.xxl),
                      child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    )
                  : ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      children: [
                        if (widget.includeAllOption)
                          _SpecialPickerRow(
                            key: const Key('category_picker_all'),
                            label: 'Semua',
                            selected: widget.current?.isAll ?? false,
                            onTap: () => _select(const CategorySelection.all()),
                          ),
                        _SpecialPickerRow(
                          key: const Key('category_picker_uncategorized'),
                          label: widget.includeAllOption
                              ? 'Lainnya'
                              : 'Lainnya (tanpa kategori)',
                          selected: widget.current?.isUncategorized ?? false,
                          onTap: () => _select(const CategorySelection.uncategorized()),
                        ),
                        if (roots.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.md,
                            ),
                            child: Text(
                              'Belum ada kategori.',
                              style: AppTextStyles.body,
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
                            onSelect: (category) => _select(
                              CategorySelection.category(category.id, _breadcrumbFor(category)),
                            ),
                            onAddChild: (parent) => _addCategory(parentId: parent.id),
                          ),
                      ],
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('category_picker_add_root'),
                    onPressed: () => _addCategory(),
                    icon: const Icon(Icons.add, color: AppColors.primary),
                    label: const Text(
                      'Tambah kategori',
                      style: TextStyle(
                        fontFamily: AppTextStyles.fontFamily,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A fixed row for "Semua" / "Lainnya" — styled like a depth-0
/// [_CategoryPickerNode] (same leading gutter and label padding) so the
/// whole list reads as one consistent set of rows, with the green
/// selected-state text/check shared with tree nodes.
class _SpecialPickerRow extends StatelessWidget {
  const _SpecialPickerRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.lg, right: AppSpacing.sm),
          child: Row(
            children: [
              const SizedBox(width: _kLeadingGutterWidth),
              Expanded(
                child: InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Text(
                      label,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: selected ? AppColors.primary : AppColors.darkText,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              if (selected)
                const Icon(Icons.check, color: AppColors.primary, size: 20),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.gray100),
      ],
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
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.lg, right: AppSpacing.sm),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < depth; i++) _buildIndentGuide(),
                SizedBox(
                  width: _kLeadingGutterWidth,
                  child: children.isEmpty
                      ? null
                      : IconButton(
                          key: Key('category_picker_expand_${category.id}'),
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            expanded ? Icons.expand_more : Icons.chevron_right,
                            color: AppColors.gray700,
                          ),
                          onPressed: () => onToggleExpand(category.id),
                        ),
                ),
                Expanded(
                  child: InkWell(
                    key: Key('category_picker_node_${category.id}'),
                    onTap: () => onSelect(category),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: Text(
                        category.name,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: selected ? AppColors.primary : AppColors.darkText,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                if (selected)
                  const Padding(
                    padding: EdgeInsets.only(right: AppSpacing.sm),
                    child: Icon(Icons.check, color: AppColors.primary, size: 20),
                  ),
                IconButton(
                  key: Key('category_picker_add_child_${category.id}'),
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  color: AppColors.primary,
                  tooltip: 'Tambah sub-kategori',
                  onPressed: () => onAddChild(category),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: AppColors.gray100),
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

  Widget _buildIndentGuide() {
    return SizedBox(
      width: AppSpacing.xl,
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(width: 1.5, color: AppColors.gray300),
      ),
    );
  }
}
