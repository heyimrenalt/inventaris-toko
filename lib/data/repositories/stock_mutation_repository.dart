import 'package:isar_community/isar.dart';

import '../models/product.dart';
import '../models/stock_mutation.dart';
import 'repository_exceptions.dart';

/// The only repository allowed to change [Product.currentStock]. Every
/// change to stock — including a product's initial stock at creation —
/// must go through [recordMutation] so the [StockMutation] ledger stays
/// complete.
class StockMutationRepository {
  StockMutationRepository(this._isar);

  final Isar _isar;

  Future<StockMutation> recordMutation({
    required int productId,
    required StockMutationType type,
    required double quantity,
    String? note,
  }) async {
    if (quantity <= 0) {
      throw ValidationException('quantity must be > 0');
    }

    return _isar.writeTxn(() async {
      final product = await _isar.products.get(productId);
      if (product == null) {
        throw NotFoundException('Product $productId not found');
      }

      final double newStock;
      if (type == StockMutationType.stockIn) {
        newStock = product.currentStock + quantity;
      } else {
        // Product decision: stock-out never goes negative. If the
        // requested quantity exceeds what's on hand, the real result is
        // clamped to 0 rather than rejecting the mutation. The mutation
        // record still stores the quantity the user actually entered,
        // for audit honesty.
        final result = product.currentStock - quantity;
        newStock = result < 0 ? 0 : result;
      }

      product.currentStock = newStock;
      product.updatedAt = DateTime.now();

      final mutation = StockMutation()
        ..productId = productId
        ..type = type
        ..quantity = quantity
        ..note = note
        ..stockAfter = newStock
        ..createdAt = DateTime.now();

      await _isar.products.put(product);
      await _isar.stockMutations.put(mutation);

      return mutation;
    });
  }

  Future<List<StockMutation>> getHistoryForProduct(int productId) {
    return _isar.stockMutations
        .filter()
        .productIdEqualTo(productId)
        .sortByCreatedAtDesc()
        .findAll();
  }

  Future<List<StockMutation>> getRecentMutations(int limit) {
    return _isar.stockMutations
        .where()
        .sortByCreatedAtDesc()
        .limit(limit)
        .findAll();
  }
}
