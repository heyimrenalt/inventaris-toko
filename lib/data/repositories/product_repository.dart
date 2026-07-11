import 'package:isar_community/isar.dart';

import '../models/category.dart';
import '../models/product.dart';
import '../models/stock_mutation.dart';
import 'app_settings_repository.dart';
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
    required int categoryId,
    required double sellPrice,
    required String unit,
    String? code,
    String? photoPath,
    double? minStockThreshold,
    double initialStock = 0,
  }) async {
    final trimmedName = _validateName(name);
    final trimmedUnit = _validateUnit(unit);
    _validateSellPrice(sellPrice);
    final normalizedCode = _normalizeCode(code);

    final category = await _isar.categories.get(categoryId);
    if (category == null) {
      throw NotFoundException('Category $categoryId not found');
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
  Future<Product> update({
    required int id,
    String? name,
    int? categoryId,
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

    if (categoryId != null) {
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

  Future<List<Product>> getAll() => _isar.products.where().findAll();

  Future<Product?> getById(int id) => _isar.products.get(id);

  Future<List<Product>> getByCategory(int categoryId) {
    return _isar.products.filter().categoryIdEqualTo(categoryId).findAll();
  }

  Future<List<Product>> searchByName(String query) {
    return _isar.products
        .filter()
        .nameContains(query, caseSensitive: false)
        .findAll();
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
