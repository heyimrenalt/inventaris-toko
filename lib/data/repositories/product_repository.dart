import 'package:isar_community/isar.dart';

import '../models/category.dart';
import '../models/product.dart';
import '../models/stock_mutation.dart';
import 'app_settings_repository.dart';
import 'category_repository.dart';
import 'repository_exceptions.dart';
import 'stock_mutation_repository.dart';

class ProductRepository {
  ProductRepository(
    this._isar,
    this._stockMutationRepository,
    this._appSettingsRepository,
  );

  final Isar _isar;
  final StockMutationRepository _stockMutationRepository;
  final AppSettingsRepository _appSettingsRepository;

  /// Creates a product. [currentStock] is never set here directly: the
  /// field starts at 0 (its neutral default) and, if [initialStock] is
  /// greater than 0, is raised through
  /// [StockMutationRepository.recordMutation] so the initial quantity is
  /// captured as a "Stok awal" ledger entry rather than an invisible
  /// starting value.
  Future<Product> create({
    required String name,
    int? categoryId,
    required double sellPrice,
    required String unit,
    String? code,
    String? photoPath,
    double? minStockThreshold,
    double initialStock = 0,
    double? averageCostPrice,
  }) async {
    final trimmedName = _validateName(name);
    final trimmedUnit = _validateUnit(unit);
    _validateSellPrice(sellPrice);
    final normalizedCode = _normalizeCode(code);

    if (categoryId != null) {
      final category = await _isar.categories.get(categoryId);
      if (category == null) {
        throw NotFoundException('Category $categoryId not found');
      }
    }

    if (normalizedCode != null) {
      await _ensureCodeNotTaken(normalizedCode);
    }

    final threshold =
        minStockThreshold ?? (await _appSettingsRepository.get()).defaultMinStockThreshold;

    final now = DateTime.now();
    final product = Product()
      ..name = trimmedName
      ..code = normalizedCode
      ..categoryId = categoryId
      ..photoPath = photoPath
      ..sellPrice = sellPrice
      ..unit = trimmedUnit
      ..currentStock = 0
      ..minStockThreshold = threshold
      ..averageCostPrice = averageCostPrice
      ..createdAt = now
      ..updatedAt = now;

    await _isar.writeTxn(() async {
      await _isar.products.put(product);
    });

    if (initialStock > 0) {
      await _stockMutationRepository.recordMutation(
        productId: product.id,
        type: StockMutationType.stockIn,
        quantity: initialStock,
        note: 'Stok awal',
      );
      // Re-read rather than patching `product.currentStock` locally, so
      // the returned object always reflects what recordMutation actually
      // persisted rather than a value assigned by this method.
      return (await getById(product.id))!;
    }

    return product;
  }

  /// Updates product fields. There is deliberately no `currentStock`
  /// parameter on this method — stock can only change via
  /// [StockMutationRepository.recordMutation].
  ///
  /// [categoryId] follows the same "`null` means leave unchanged"
  /// convention as every other optional parameter here — which means it
  /// can't also be how a caller says "clear the category to Lainnya",
  /// since `categoryId` is itself allowed to be null now that category is
  /// optional. [clearCategory] is the explicit way to do that instead.
  Future<Product> update({
    required int id,
    String? name,
    int? categoryId,
    bool clearCategory = false,
    String? code,
    String? photoPath,
    double? sellPrice,
    String? unit,
    double? minStockThreshold,
  }) async {
    final product = await getById(id);
    if (product == null) {
      throw NotFoundException('Product $id not found');
    }

    if (name != null) {
      product.name = _validateName(name);
    }

    if (clearCategory) {
      product.categoryId = null;
    } else if (categoryId != null) {
      final category = await _isar.categories.get(categoryId);
      if (category == null) {
        throw NotFoundException('Category $categoryId not found');
      }
      product.categoryId = categoryId;
    }

    if (code != null) {
      final normalizedCode = _normalizeCode(code);
      if (normalizedCode != product.code) {
        if (normalizedCode != null) {
          await _ensureCodeNotTaken(normalizedCode, excludingId: id);
        }
        product.code = normalizedCode;
      }
    }

    if (photoPath != null) {
      product.photoPath = photoPath;
    }

    if (sellPrice != null) {
      _validateSellPrice(sellPrice);
      product.sellPrice = sellPrice;
    }

    if (unit != null) {
      product.unit = _validateUnit(unit);
    }

    if (minStockThreshold != null) {
      product.minStockThreshold = minStockThreshold;
    }

    product.updatedAt = DateTime.now();

    await _isar.writeTxn(() async {
      await _isar.products.put(product);
    });

    return product;
  }

  /// Deletion is blocked if the product has [StockMutation] history,
  /// rather than cascade-deleting it. The mutation ledger is meant to be
  /// an audit trail; silently deleting it alongside the product would
  /// destroy history that's also needed for future velocity ("prioritas
  /// kulakan") calculations. If a real need for removing a product with
  /// history shows up later, prefer adding an "archived" flag over
  /// changing this to a cascade delete.
  Future<void> delete(int id) async {
    final mutationCount =
        await _isar.stockMutations.filter().productIdEqualTo(id).count();
    if (mutationCount > 0) {
      throw ProductHasHistoryException(id, mutationCount);
    }

    await _isar.writeTxn(() async {
      await _isar.products.delete(id);
    });
  }

  /// Marks a product archived instead of deleting it. Unlike [delete],
  /// this works regardless of stock mutation history — it's the intended
  /// way out for a product that has history and so can never be
  /// hard-deleted, but is also available for products without history in
  /// case archiving is simply preferred. Never touches `currentStock` or
  /// the mutation ledger.
  Future<Product> archive(int id) async {
    final product = await getById(id);
    if (product == null) {
      throw NotFoundException('Product $id not found');
    }

    product.isArchived = true;
    product.archivedAt = DateTime.now();
    product.updatedAt = DateTime.now();

    await _isar.writeTxn(() async {
      await _isar.products.put(product);
    });

    return product;
  }

  Future<Product> unarchive(int id) async {
    final product = await getById(id);
    if (product == null) {
      throw NotFoundException('Product $id not found');
    }

    product.isArchived = false;
    product.archivedAt = null;
    product.updatedAt = DateTime.now();

    await _isar.writeTxn(() async {
      await _isar.products.put(product);
    });

    return product;
  }

  Future<List<Product>> getAll({bool includeArchived = false}) {
    if (includeArchived) {
      return _isar.products.where().findAll();
    }
    return _isar.products.filter().isArchivedEqualTo(false).findAll();
  }

  Future<Product?> getById(int id) => _isar.products.get(id);

  Future<List<Product>> getArchived() {
    return _isar.products.filter().isArchivedEqualTo(true).findAll();
  }

  Future<List<Product>> getByCategory(int categoryId, {bool includeArchived = false}) {
    final query = _isar.products.filter().categoryIdEqualTo(categoryId);
    if (includeArchived) {
      return query.findAll();
    }
    return query.isArchivedEqualTo(false).findAll();
  }

  /// Products tagged directly to [categoryId], or to any category nested
  /// under it at any depth — e.g. selecting "Alat Tulis" also returns
  /// products tagged to "Pulpen" underneath it. [CategoryRepository] is
  /// constructed locally here rather than injected: it's a thin,
  /// stateless wrapper over the same [Isar] instance, so there's nothing
  /// to gain from threading it through this repository's constructor.
  Future<List<Product>> getByCategoryIncludingDescendants(
    int categoryId, {
    bool includeArchived = false,
  }) async {
    final descendantIds = await CategoryRepository(_isar).getDescendantIds(categoryId);
    final ids = [categoryId, ...descendantIds];
    final query = _isar.products.filter().anyOf(ids, (q, id) => q.categoryIdEqualTo(id));
    if (includeArchived) {
      return query.findAll();
    }
    return query.isArchivedEqualTo(false).findAll();
  }

  /// Products with no category at all (the "Lainnya" bucket). Always
  /// excludes archived products — there is no `includeArchived` option
  /// since nothing in the app currently needs uncategorized+archived
  /// together.
  Future<List<Product>> getUncategorized() {
    return _isar.products.filter().categoryIdIsNull().isArchivedEqualTo(false).findAll();
  }

  Future<List<Product>> searchByName(String query, {bool includeArchived = false}) {
    final filter = _isar.products.filter().nameContains(query, caseSensitive: false);
    if (includeArchived) {
      return filter.findAll();
    }
    return filter.isArchivedEqualTo(false).findAll();
  }

  String _validateName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ValidationException('Product name must not be empty');
    }
    return trimmed;
  }

  String _validateUnit(String unit) {
    final trimmed = unit.trim();
    if (trimmed.isEmpty) {
      throw ValidationException('Unit must not be empty');
    }
    return trimmed;
  }

  void _validateSellPrice(double sellPrice) {
    if (sellPrice < 0) {
      throw ValidationException('sellPrice must be >= 0');
    }
  }

  /// Treats an empty/whitespace-only code the same as no code, so
  /// multiple products can be saved without a code without tripping
  /// uniqueness.
  String? _normalizeCode(String? code) {
    final trimmed = code?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  Future<void> _ensureCodeNotTaken(String code, {int? excludingId}) async {
    final existing =
        await _isar.products.filter().codeEqualTo(code).findFirst();
    if (existing != null && existing.id != excludingId) {
      throw DuplicateProductCodeException(code);
    }
  }
}
