import 'package:isar_community/isar.dart';

import '../../domain/hpp_calculator.dart';
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

  /// [costPricePerUnit] is only meaningful when [type] is
  /// [StockMutationType.stockIn]: if provided, [Product.averageCostPrice] is
  /// recalculated via [HppCalculator.calculateNewAverage] and written in the
  /// same write transaction as the stock update, so the two never diverge.
  /// Ignored for stockOut, and a no-op when left null (HPP stays unchanged).
  Future<StockMutation> recordMutation({
    required int productId,
    required StockMutationType type,
    required double quantity,
    String? note,
    double? costPricePerUnit,
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
        if (costPricePerUnit != null) {
          product.averageCostPrice = HppCalculator.calculateNewAverage(
            currentStock: product.currentStock,
            currentAvgCost: product.averageCostPrice ?? 0,
            incomingQty: quantity,
            incomingCostPrice: costPricePerUnit,
          );
        }
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

  /// The single newest mutation for [productId], or `null` if it has no
  /// history. Used by callers to decide whether a given mutation row is
  /// eligible for cancellation (only the most recent mutation for a
  /// product may be undone from the history screens).
  Future<StockMutation?> getMostRecentMutationForProduct(int productId) {
    return _isar.stockMutations
        .filter()
        .productIdEqualTo(productId)
        .sortByCreatedAtDesc()
        .findFirst();
  }

  /// Reverses [mutationId] by recording a compensating mutation of the
  /// opposite type for the same quantity — a stockOut is undone by a
  /// stockIn and vice versa. The original record is never deleted or
  /// modified: the ledger stays append-only, and the undo shows up as a
  /// new opposing entry.
  ///
  /// Whether [mutationId] is actually eligible to be undone (e.g. "only
  /// the most recent mutation for a product") is entirely the caller's
  /// concern — this method just executes the compensating write.
  Future<void> undoMutation(int mutationId) async {
    final original = await _isar.stockMutations.get(mutationId);
    if (original == null) {
      throw NotFoundException('Mutation $mutationId not found');
    }

    final product = await _isar.products.get(original.productId);
    final compensatingType = original.type == StockMutationType.stockIn
        ? StockMutationType.stockOut
        : StockMutationType.stockIn;

    // Strips any existing "Dibatalkan: " prefix first, so undoing an
    // already-undone mutation produces a single clean "Dibatalkan: X"
    // note instead of nesting ("Dibatalkan: Dibatalkan: X") every time
    // the same chain is undone back and forth.
    final baseNote =
        original.note?.replaceFirst(RegExp(r'^Dibatalkan:\s*'), '') ?? product?.name ?? 'mutasi';

    await recordMutation(
      productId: original.productId,
      type: compensatingType,
      quantity: original.quantity,
      note: 'Dibatalkan: $baseNote',
    );
  }

  /// All stockOut mutations for [productId], oldest first. Feeds
  /// [PrioritasKulakanCalculator], which needs the earliest stockOut date
  /// (and every quantity in between) to compute daily velocity.
  Future<List<StockMutation>> getStockOutHistoryForProduct(int productId) {
    return _isar.stockMutations
        .filter()
        .productIdEqualTo(productId)
        .typeEqualTo(StockMutationType.stockOut)
        .sortByCreatedAt()
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
