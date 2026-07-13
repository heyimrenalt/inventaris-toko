import 'package:isar_community/isar.dart';

import '../models/category.dart';
import '../models/product.dart';
import 'repository_exceptions.dart';

class CategoryRepository {
  CategoryRepository(this._isar);

  final Isar _isar;

  Future<Category> create(String name, {int? parentId}) async {
    final trimmed = _validateName(name);
    await _ensureNameNotTakenAmongSiblings(trimmed, parentId: parentId);

    final category = Category()
      ..name = trimmed
      ..parentId = parentId
      ..createdAt = DateTime.now();

    await _isar.writeTxn(() async {
      await _isar.categories.put(category);
    });

    return category;
  }

  Future<Category> rename(int id, String newName) async {
    final category = await getById(id);
    if (category == null) {
      throw NotFoundException('Category $id not found');
    }

    final trimmed = _validateName(newName);
    await _ensureNameNotTakenAmongSiblings(
      trimmed,
      parentId: category.parentId,
      excludingId: id,
    );
    category.name = trimmed;

    await _isar.writeTxn(() async {
      await _isar.categories.put(category);
    });

    return category;
  }

  /// Deletion is blocked in two cases, checked in this order:
  ///
  /// 1. The category itself, OR any descendant at any depth, is still
  ///    referenced by at least one [Product]. The count reported by
  ///    [CategoryInUseException] is the aggregate across the whole
  ///    subtree, not just this category — this matters once nesting is
  ///    2+ levels deep, e.g. deleting a grandparent whose only remaining
  ///    products live on a grandchild. Checked first so this is always
  ///    the reported reason when it applies, even though (2) below would
  ///    also block the same delete whenever the subtree isn't a single
  ///    leaf.
  /// 2. The category has any child categories at all, regardless of
  ///    whether those children (or their own descendants) have products.
  ///    Design decision: deleting a category with children is never
  ///    allowed to implicitly cascade-delete or orphan the subtree — the
  ///    user must explicitly delete the whole subtree from the leaves
  ///    up. This keeps deletion semantics simple (a delete only ever
  ///    removes exactly one category) at the cost of requiring more taps
  ///    for deep subtrees.
  Future<void> delete(int id) async {
    final referencingCount = await _aggregateProductCount(id);
    if (referencingCount > 0) {
      throw CategoryInUseException(id, referencingCount);
    }

    final children = await getChildren(id);
    if (children.isNotEmpty) {
      throw CategoryHasChildrenException(id, children.length);
    }

    await _isar.writeTxn(() async {
      await _isar.categories.delete(id);
    });
  }

  Future<List<Category>> getAll() => _isar.categories.where().findAll();

  Future<Category?> getById(int id) => _isar.categories.get(id);

  Future<List<Category>> getRootCategories() =>
      _isar.categories.filter().parentIdIsNull().findAll();

  Future<List<Category>> getChildren(int parentId) =>
      _isar.categories.filter().parentIdEqualTo(parentId).findAll();

  /// Returns every descendant category id at any depth below
  /// [categoryId] (children, grandchildren, ...), not including
  /// [categoryId] itself. Used both by [delete]'s in-use check and by
  /// callers that need "this category and everything under it" (e.g.
  /// [ProductRepository.getByCategoryIncludingDescendants]).
  ///
  /// Walks the whole category table once (`getAll()`) and groups it by
  /// `parentId` in memory rather than issuing one query per level — for
  /// this app's expected category counts, a single flat read is both
  /// simpler and cheaper than N recursive queries.
  Future<List<int>> getDescendantIds(int categoryId) async {
    final all = await getAll();
    final childrenByParentId = <int, List<Category>>{};
    for (final category in all) {
      final parentId = category.parentId;
      if (parentId != null) {
        childrenByParentId.putIfAbsent(parentId, () => []).add(category);
      }
    }

    final descendantIds = <int>[];
    void collect(int id) {
      for (final child in childrenByParentId[id] ?? const <Category>[]) {
        descendantIds.add(child.id);
        collect(child.id);
      }
    }

    collect(categoryId);
    return descendantIds;
  }

  /// Aggregate product count referencing [categoryId] or any of its
  /// descendants — the count surfaced by [CategoryInUseException] and by
  /// the Kelola Kategori tree's "N produk (termasuk sub-kategori)" badge.
  Future<int> getProductCountIncludingDescendants(int categoryId) =>
      _aggregateProductCount(categoryId);

  Future<int> _aggregateProductCount(int categoryId) async {
    final descendantIds = await getDescendantIds(categoryId);
    final ids = [categoryId, ...descendantIds];
    return _isar.products.filter().anyOf(ids, (q, id) => q.categoryIdEqualTo(id)).count();
  }

  String _validateName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ValidationException('Category name must not be empty');
    }
    return trimmed;
  }

  /// Uniqueness is scoped to siblings (same [parentId]) rather than
  /// global: "Pulpen" under "Alat Tulis" and "Pulpen" under a different
  /// top-level category are both allowed, so this can't be enforced via
  /// a single-field unique index and is checked manually instead.
  Future<void> _ensureNameNotTakenAmongSiblings(
    String name, {
    required int? parentId,
    int? excludingId,
  }) async {
    final siblings = parentId == null
        ? await _isar.categories.filter().parentIdIsNull().findAll()
        : await _isar.categories.filter().parentIdEqualTo(parentId).findAll();

    final taken = siblings.any(
      (category) => category.id != excludingId && category.name.toLowerCase() == name.toLowerCase(),
    );
    if (taken) {
      throw DuplicateCategoryNameException(name);
    }
  }
}
