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
        // Stock-out can never take currentStock negative. Rather than
        // clamping to 0, the whole mutation is rejected: no Product or
        // StockMutation write happens, so the ledger never contains a
        // stock-out that doesn't reflect what actually left the shelf.
        if (quantity > product.currentStock) {
          throw InsufficientStockException(
            productId: productId,
            currentStock: product.currentStock,
            requestedQuantity: quantity,
          );
        }
        newStock = product.currentStock - quantity;
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

  /// Same as [getHistoryForProduct] but capped at [limit] — for previews
  /// (e.g. Product Detail's recent-history section) that link out to the
  /// full history via [getHistoryForProduct] instead of loading everything
  /// just to show a handful of rows.
  Future<List<StockMutation>> getRecentHistoryForProduct(int productId, int limit) {
    return _isar.stockMutations
        .filter()
        .productIdEqualTo(productId)
        .sortByCreatedAtDesc()
        .limit(limit)
        .findAll();
  }

  Future<List<StockMutation>> getRecentMutations(int limit) {
    return _isar.stockMutations
        .where()
        .sortByCreatedAtDesc()
        .limit(limit)
        .findAll();
  }

  /// Full mutation history across all products, newest first — used by
  /// the Mutasi tab, which shows the complete ledger with no filters.
  Future<List<StockMutation>> getAllMutations() {
    return _isar.stockMutations.where().sortByCreatedAtDesc().findAll();
  }

  /// Sums stock-in and stock-out quantities separately for mutations
  /// created at or after [since] (e.g. `DateTime.now().subtract(const
  /// Duration(days: 7))` for a rolling 7-day window). Computed as a
  /// single indexed query rather than loading everything and summing in
  /// the UI layer.
  Future<StockMutationTotals> getTotalsSince(DateTime since) async {
    final mutations = await _isar.stockMutations
        .filter()
        .createdAtGreaterThan(since, include: true)
        .findAll();

    var stockIn = 0.0;
    var stockOut = 0.0;
    for (final mutation in mutations) {
      if (mutation.type == StockMutationType.stockIn) {
        stockIn += mutation.quantity;
      } else {
        stockOut += mutation.quantity;
      }
    }
    return StockMutationTotals(stockIn: stockIn, stockOut: stockOut);
  }
}

class StockMutationTotals {
  const StockMutationTotals({required this.stockIn, required this.stockOut});

  final double stockIn;
  final double stockOut;
}
