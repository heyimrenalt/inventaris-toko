import 'package:isar_community/isar.dart';

import '../models/cost_price_adjustment.dart';
import '../models/product.dart';
import 'repository_exceptions.dart';

/// The only repository allowed to manually override [Product.averageCostPrice]
/// outside of [StockMutationRepository.recordMutation]'s automatic weighted-
/// average recalculation. Used by the Edit Product form's "Harga modal
/// (koreksi)" field, for correcting HPP when it's known to be wrong (e.g. a
/// data-entry mistake on an earlier stockIn) without fabricating a fake
/// stock movement to get there.
class CostPriceAdjustmentRepository {
  CostPriceAdjustmentRepository(this._isar);

  final Isar _isar;

  /// Sets [Product.averageCostPrice] to [newCost] and records a
  /// [CostPriceAdjustment] audit row, atomically in one write transaction.
  /// [newCost] may be null to clear HPP back to "no data".
  Future<void> recordAdjustment({
    required int productId,
    required double? newCost,
    String? note,
  }) async {
    await _isar.writeTxn(() async {
      final product = await _isar.products.get(productId);
      if (product == null) {
        throw NotFoundException('Product $productId not found');
      }

      final oldCost = product.averageCostPrice;
      product.averageCostPrice = newCost;
      product.updatedAt = DateTime.now();

      final adjustment = CostPriceAdjustment()
        ..productId = productId
        ..oldCost = oldCost
        ..newCost = newCost
        ..note = note
        ..adjustedAt = DateTime.now();

      await _isar.products.put(product);
      await _isar.costPriceAdjustments.put(adjustment);
    });
  }

  Future<List<CostPriceAdjustment>> getHistoryForProduct(int productId) {
    return _isar.costPriceAdjustments
        .filter()
        .productIdEqualTo(productId)
        .sortByAdjustedAtDesc()
        .findAll();
  }
}
