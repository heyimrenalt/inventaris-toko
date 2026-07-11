import 'package:isar_community/isar.dart';

import '../models/category.dart';
import '../models/product.dart';
import 'repository_exceptions.dart';

class CategoryRepository {
  CategoryRepository(this._isar);

  final Isar _isar;

  Future<Category> create(String name) async {
    final trimmed = _validateName(name);
    await _ensureNameNotTaken(trimmed);

    final category = Category()
      ..name = trimmed
      ..createdAt = DateTime.now();

    await _isar.writeTxn(() async {
      await _isar.categories.put(category);
    });

    return category;
  }

  Future<Category> rename(int id, String newName) async {
    final trimmed = _validateName(newName);
    await _ensureNameNotTaken(trimmed, excludingId: id);

    final category = await getById(id);
    if (category == null) {
      throw NotFoundException('Category $id not found');
    }
    category.name = trimmed;

    await _isar.writeTxn(() async {
      await _isar.categories.put(category);
    });

    return category;
  }

  /// Throws [CategoryInUseException] if any [Product] still references
  /// this category. Deletion is never allowed to silently orphan or
  /// cascade-delete products.
  Future<void> delete(int id) async {
    final referencingCount =
        await _isar.products.filter().categoryIdEqualTo(id).count();
    if (referencingCount > 0) {
      throw CategoryInUseException(id, referencingCount);
    }

    await _isar.writeTxn(() async {
      await _isar.categories.delete(id);
    });
  }

  Future<List<Category>> getAll() => _isar.categories.where().findAll();

  Future<Category?> getById(int id) => _isar.categories.get(id);

  String _validateName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ValidationException('Category name must not be empty');
    }
    return trimmed;
  }

  Future<void> _ensureNameNotTaken(String name, {int? excludingId}) async {
    final existing = await _isar.categories
        .filter()
        .nameEqualTo(name, caseSensitive: false)
        .findFirst();
    if (existing != null && existing.id != excludingId) {
      throw DuplicateCategoryNameException(name);
    }
  }
}
